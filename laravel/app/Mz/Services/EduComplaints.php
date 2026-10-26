<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Confidential academic complaints (teacher, marks, course administration, enrollment, placement,
 * study mode, other). A student sees only their own complaints and the replies meant for them;
 * reviewers (education.manage) also see internal notes, assign, ask for more information, answer,
 * resolve, reject or escalate. A complaint about a mark starts a review — it never changes a mark
 * by itself (an administrator amends it through EduMarks if it is upheld). Attachments are stored
 * privately and served only to the student and reviewers.
 */
final class EduComplaints
{
    public const CATEGORIES = ['teacher', 'marks', 'course_admin', 'enrollment', 'placement', 'study_mode', 'other'];
    public const STATUSES = ['submitted', 'under_review', 'awaiting_information', 'resolved', 'rejected', 'escalated'];
    private const CLOSED = ['resolved', 'rejected'];

    /** A complaint may only point at classes, subjects, assessments and teachers of the student's own studies. */
    private static function assertRelated(int $userId, array $in): array
    {
        $out = ['class_id' => null, 'course_id' => null, 'assessment_id' => null, 'teacher_user_id' => null];
        if (! empty($in['assessment_id'])) {
            $a = DB::table('edu_assessments')->where('id', $in['assessment_id'])->first();
            if (! $a) throw ApiError::field('assessment_id', 'NOT_FOUND');
            $in['course_id'] = $a->course_id;
            $out['assessment_id'] = (int) $a->id;
        }
        if (! empty($in['course_id'])) {
            $c = DB::table('edu_courses')->where('id', $in['course_id'])->first();
            if (! $c || ! Edu::onRoster($c, $userId)) throw ApiError::field('course_id', 'NOT_ENROLLED');
            $out['course_id'] = (int) $c->id;
            $out['class_id'] = (int) $c->class_id;
            $in['class_id'] = $c->class_id;
        }
        if (! empty($in['class_id'])) {
            $was = DB::table('edu_enrollments')->where(['class_id' => $in['class_id'], 'user_id' => $userId])->exists() || $out['course_id'];
            if (! $was) throw ApiError::field('class_id', 'NOT_ENROLLED');
            $out['class_id'] = (int) $in['class_id'];
        }
        if (! empty($in['teacher_user_id'])) {
            $ok = DB::table('edu_course_teachers as t')->join('edu_courses as co', 'co.id', '=', 't.course_id')->where('t.user_id', $in['teacher_user_id'])
                ->where(fn ($w) => $out['course_id'] ? $w->where('co.id', $out['course_id']) : $w->whereIn('co.class_id', DB::table('edu_enrollments')->where('user_id', $userId)->select('class_id')))->exists();
            if (! $ok) throw ApiError::field('teacher_user_id', 'NOT_YOUR_TEACHER');
            $out['teacher_user_id'] = (int) $in['teacher_user_id'];
        }
        return $out;
    }

    public static function create(AuthContext $auth, array $in, ?UploadedFile $file): array
    {
        $links = self::assertRelated($auth->id, $in);
        $saved = $file ? Storage::save('project', Storage::FOLDERS['COMPLAINTS'], $file) : null;
        try {
            $id = DB::transaction(function () use ($auth, $in, $links, $saved, $file) {
                $id = DB::table('edu_complaints')->insertGetId($links + [
                    'user_id' => $auth->id, 'category' => $in['category'], 'subject' => $in['subject'], 'description' => $in['description'], 'status' => 'submitted',
                    'attachment_path' => $saved['path'] ?? null, 'attachment_name' => $file ? mb_substr((string) $file->getClientOriginalName(), 0, 255) : null,
                ]);
                DB::table('edu_complaints')->where('id', $id)->update(['ref' => 'EC-' . date('Y') . '-' . str_pad((string) $id, 6, '0', STR_PAD_LEFT)]);
                return $id;
            });
        } catch (\Throwable $e) {
            if ($saved) Storage::remove($saved['path']);
            throw $e;
        }
        $c = self::row($id);
        Notifications::createForUsers(array_values(array_diff(Holders::of('education.manage'), [$auth->id])), [
            'type' => 'education',
            'title' => T::t('edu.complaint.new.title'),
            'body' => T::t('edu.complaint.new.body', ['ref' => $c->ref, 'category' => T::t('edu.complaint.category.' . $c->category)]),
            'entityType' => 'edu_complaint',
            'entityId' => $id,
            'dedupeKey' => fn ($uid) => "edu:complaint:$id:new:$uid",
        ]);
        return self::serialize($c, false);
    }

    private static function row(int $id): object
    {
        $c = DB::table('edu_complaints as c')->join('users as u', 'u.id', '=', 'c.user_id')
            ->leftJoin('edu_classes as cl', 'cl.id', '=', 'c.class_id')->leftJoin('edu_courses as co', 'co.id', '=', 'c.course_id')
            ->leftJoin('edu_assessments as a', 'a.id', '=', 'c.assessment_id')->leftJoin('users as t', 't.id', '=', 'c.teacher_user_id')->leftJoin('users as asg', 'asg.id', '=', 'c.assigned_to')
            ->where('c.id', $id)
            ->first(['c.*', 'u.full_name', 'cl.name as class_name', 'co.name as course_name', 'a.title as assessment_title', 't.full_name as teacher_name', 'asg.full_name as assigned_to_name']);
        if (! $c) throw ApiError::notFound('COMPLAINT_NOT_FOUND', 'Complaint not found');
        return $c;
    }

    /** $reviewer: internal notes and the assignee are included. */
    private static function serialize(object $c, bool $reviewer): array
    {
        $msgs = DB::table('edu_complaint_messages as m')->join('users as u', 'u.id', '=', 'm.author_id')->where('m.complaint_id', $c->id)
            ->when(! $reviewer, fn ($q) => $q->where('m.is_internal', false))
            ->orderBy('m.id')->get(['m.id', 'm.author_id', 'u.full_name as author_name', 'm.body', 'm.is_internal', 'm.status_change', 'm.created_at'])
            ->map(function ($m) use ($c) {
                $m->is_internal = (bool) $m->is_internal;
                $m->from_student = (int) $m->author_id === (int) $c->user_id;
                return $m;
            })->all();
        $out = [
            'id' => $c->id, 'ref' => $c->ref, 'category' => $c->category, 'status' => $c->status, 'subject' => $c->subject, 'description' => $c->description,
            'class' => $c->class_id ? ['id' => $c->class_id, 'name' => $c->class_name] : null,
            'course' => $c->course_id ? ['id' => $c->course_id, 'name' => $c->course_name] : null,
            'assessment' => $c->assessment_id ? ['id' => $c->assessment_id, 'title' => $c->assessment_title] : null,
            'teacher' => $c->teacher_user_id ? ['id' => $c->teacher_user_id, 'full_name' => $c->teacher_name] : null,
            'has_attachment' => (bool) $c->attachment_path, 'attachment_name' => $c->attachment_name,
            'messages' => $msgs,
            'created_at' => $c->created_at, 'updated_at' => $c->updated_at, 'resolved_at' => $c->resolved_at,
        ];
        if ($reviewer) {
            $out += [
                'student' => ['id' => $c->user_id, 'full_name' => $c->full_name],
                'assigned_to' => $c->assigned_to ? ['id' => $c->assigned_to, 'full_name' => $c->assigned_to_name] : null,
                'resolution_hours' => $c->resolved_at ? round((Dates::ms($c->resolved_at) - Dates::ms($c->created_at)) / 3600000, 1) : null,
            ];
        }
        return $out;
    }

    private static function own(AuthContext $auth, int $id): object
    {
        $c = self::row($id);
        // Someone else's complaint is reported as not found (no hint that it exists).
        if ((int) $c->user_id !== $auth->id) throw ApiError::notFound('COMPLAINT_NOT_FOUND', 'Complaint not found');
        return $c;
    }

    public static function mine(AuthContext $auth): array
    {
        return DB::table('edu_complaints')->where('user_id', $auth->id)->orderByDesc('id')->limit(200)->pluck('id')
            ->map(fn ($id) => self::serialize(self::row((int) $id), false))->all();
    }

    public static function getOwn(AuthContext $auth, int $id): array
    {
        return self::serialize(self::own($auth, $id), false);
    }

    public static function getForReviewer(int $id): array
    {
        return self::serialize(self::row($id), true);
    }

    /** The student adds information; a complaint waiting for information goes back to review. */
    public static function studentMessage(AuthContext $auth, int $id, string $body): array
    {
        $c = self::own($auth, $id);
        if (in_array($c->status, self::CLOSED, true)) throw ApiError::conflict('COMPLAINT_CLOSED', 'This complaint is closed');
        DB::transaction(function () use ($auth, $c, $body) {
            $next = $c->status === 'awaiting_information' ? 'under_review' : null;
            DB::table('edu_complaint_messages')->insert(['complaint_id' => $c->id, 'author_id' => $auth->id, 'body' => $body, 'is_internal' => false, 'status_change' => $next]);
            if ($next) DB::table('edu_complaints')->where('id', $c->id)->update(['status' => $next]);
        });
        $to = $c->assigned_to ? [(int) $c->assigned_to] : Holders::of('education.manage');
        Notifications::createForUsers($to, [
            'type' => 'education', 'title' => T::t('edu.complaint.reply.title'), 'body' => T::t('edu.complaint.student_reply.body', ['ref' => $c->ref]),
            'entityType' => 'edu_complaint', 'entityId' => $c->id, 'dedupeKey' => fn ($uid) => "edu:complaint:{$c->id}:sr:" . microtime(true) . ":$uid",
        ]);
        return self::getOwn($auth, $id);
    }

    public static function adminList(array $f, array $page): array
    {
        $qb = DB::table('edu_complaints as c')->join('users as u', 'u.id', '=', 'c.user_id')->select('c.id')->orderByRaw("FIELD(c.status, 'submitted', 'escalated', 'under_review', 'awaiting_information', 'resolved', 'rejected')")->orderByDesc('c.created_at');
        if (! empty($f['status'])) $qb->where('c.status', $f['status']);
        if (! empty($f['category'])) $qb->where('c.category', $f['category']);
        if (! empty($f['assigned_to'])) $qb->where('c.assigned_to', $f['assigned_to']);
        if (! empty($f['q'])) $qb->where(fn ($w) => $w->where('c.ref', 'like', "%{$f['q']}%")->orWhere('c.subject', 'like', "%{$f['q']}%")->orWhere('u.full_name', 'like', "%{$f['q']}%"));
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($r) => self::getForReviewer((int) $r->id), $res['items']), 'meta' => $res['meta']];
    }

    /**
     * A reviewer's action: a reply to the student or an internal note, optionally with a new status
     * and / or assignee. Reaching resolved / rejected closes the complaint and records when.
     */
    public static function act(array $actx, int $id, array $in): array
    {
        $by = $actx['auth']->id;
        $c = self::row($id);
        $status = $in['status'] ?? null;
        $body = isset($in['body']) ? trim((string) $in['body']) : '';
        $internal = (bool) ($in['internal'] ?? false);
        if (in_array($status, self::CLOSED, true) && $body === '') throw ApiError::field('body', 'REQUIRED'); // a closing answer is explained
        if ($status === 'awaiting_information' && ($body === '' || $internal)) throw ApiError::field('body', 'REQUIRED'); // say what is needed
        DB::transaction(function () use ($actx, $c, $by, $status, $body, $internal, $in) {
            $patch = [];
            if ($status && $status !== $c->status) {
                $patch['status'] = $status;
                $patch['resolved_at'] = in_array($status, self::CLOSED, true) ? Dates::sql(Dates::now()) : null;
            }
            if (array_key_exists('assigned_to', $in)) {
                if ($in['assigned_to'] && ! in_array((int) $in['assigned_to'], Holders::of('education.manage', true), true)) throw ApiError::field('assigned_to', 'NOT_A_REVIEWER');
                $patch['assigned_to'] = $in['assigned_to'] ?: null;
            }
            if ($patch) DB::table('edu_complaints')->where('id', $c->id)->update($patch);
            if ($body !== '' || isset($patch['status'])) {
                DB::table('edu_complaint_messages')->insert(['complaint_id' => $c->id, 'author_id' => $by, 'body' => $body !== '' ? $body : '—', 'is_internal' => $internal, 'status_change' => $patch['status'] ?? null]);
            }
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_complaint', $c->id, ['status' => $patch['status'] ?? null, 'assigned_to' => $patch['assigned_to'] ?? null, 'internal_note' => $internal && $body !== ''], inTrx: true);
        });
        // The student hears about replies and status changes meant for them — never about internal notes.
        if (($body !== '' && ! $internal) || ($status && $status !== $c->status)) {
            Notifications::createForUsers([(int) $c->user_id], [
                'type' => 'education', 'title' => T::t('edu.complaint.reply.title'),
                'body' => T::t('edu.complaint.reply.body', ['ref' => $c->ref, 'status' => T::t('edu.complaint.status.' . ($status ?: $c->status))]),
                'entityType' => 'edu_complaint', 'entityId' => $c->id, 'dedupeKey' => fn ($uid) => "edu:complaint:{$c->id}:r:" . microtime(true) . ":$uid",
            ]);
        }
        if (! empty($in['assigned_to']) && (int) $in['assigned_to'] !== (int) $c->assigned_to && (int) $in['assigned_to'] !== $by) {
            Notifications::createForUsers([(int) $in['assigned_to']], [
                'type' => 'education', 'title' => T::t('edu.complaint.assigned.title'), 'body' => T::t('edu.complaint.assigned.body', ['ref' => $c->ref]),
                'entityType' => 'edu_complaint', 'entityId' => $c->id, 'dedupeKey' => fn ($uid) => "edu:complaint:{$c->id}:a:" . microtime(true) . ":$uid",
            ]);
        }
        return self::getForReviewer($id);
    }

    /** The attachment, for its student or a reviewer. */
    public static function attachment(AuthContext $auth, int $id): array
    {
        $c = self::row($id);
        if ((int) $c->user_id !== $auth->id && ! $auth->can('education.manage')) throw ApiError::notFound('COMPLAINT_NOT_FOUND', 'Complaint not found');
        $abs = $c->attachment_path ? Storage::privatePath($c->attachment_path) : null;
        if (! $abs || ! is_file($abs)) throw ApiError::notFound();
        return ['abs' => $abs, 'mime' => Storage::detect($abs)[1] ?? 'application/octet-stream', 'name' => $c->attachment_name];
    }
}
