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
use Illuminate\Support\Facades\DB;

/**
 * Students' academic requests in ትምህርት — change of class, stream or study mode (regular ↔
 * distance), joining or leaving a class (course), adding or dropping a subject, or another change
 * written out. A request is checked when it is made (eligibility, capacity, duplicates), waits as
 * 'pending', and an education administrator approves or rejects it with a comment. Approving
 * really changes the enrollment, in one transaction, re-checking everything first; the request then
 * becomes 'implemented' ('approved' for an "other" request, which an administrator carries out).
 * The student never changes the enrollment records directly.
 */
final class EduRequests
{
    public const TYPES = ['class_change', 'stream_change', 'study_mode_change', 'add_class', 'drop_class', 'add_subject', 'drop_subject', 'other'];

    private static function enrollment(int $userId, ?int $classId, bool $lock = false): ?object
    {
        if (! $classId) return null;
        $q = DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $userId, 'status' => 'active']);
        if ($lock) $q->lockForUpdate();
        return $q->first();
    }

    private static function klass(?int $id, bool $lock = false): object
    {
        $q = DB::table('edu_classes')->where('id', (int) $id);
        if ($lock) $q->lockForUpdate();
        $c = $q->first();
        if (! $c) throw ApiError::field('class_id', 'CLASS_NOT_FOUND');
        return $c;
    }

    private static function streams(object $c): array
    {
        return ! empty($c->streams) ? array_values(array_filter(array_map('trim', explode(',', $c->streams)))) : [];
    }

    private static function assertCapacity(object $c, int $adding = 1): void
    {
        if (! $c->capacity) return;
        $n = DB::table('edu_enrollments')->where(['class_id' => $c->id, 'status' => 'active'])->count();
        if ($n + $adding > $c->capacity) throw ApiError::conflict('CLASS_FULL', 'Class is full');
    }

    private static function assertProgramOffered(object $c, string $program): void
    {
        if (($program === 'regular' && ! $c->allow_regular) || ($program === 'distance' && ! $c->allow_distance)) {
            throw ApiError::field('requested_value', 'PROGRAM_NOT_OFFERED');
        }
    }

    /**
     * Validates [$r] (a request row as array) against the current records; returns the row with
     * current_value / requested_value filled. Used when the request is made AND again on approval.
     */
    private static function check(int $userId, array $r, bool $lock = false): array
    {
        $type = $r['type'];
        // Changes to a class the student is in need that (active) enrollment.
        $e = self::enrollment($userId, $r['class_id'] ?? null, $lock);
        if (in_array($type, ['class_change', 'stream_change', 'study_mode_change', 'drop_class'], true) && ! $e) throw ApiError::field('class_id', 'NOT_ENROLLED');
        switch ($type) {
            case 'class_change':
                $to = self::klass($r['target_class_id'] ?? null, $lock);
                if ((int) $to->id === (int) $r['class_id']) throw ApiError::field('target_class_id', 'SAME_CLASS');
                if ($to->status !== 'active') throw ApiError::field('target_class_id', 'CLASS_NOT_ACTIVE');
                if (self::enrollment($userId, (int) $to->id)) throw ApiError::conflict('ALREADY_ENROLLED', 'Already enrolled');
                self::assertProgramOffered($to, $e->program);
                self::assertCapacity($to);
                $r['current_value'] = self::klass($r['class_id'])->name;
                $r['requested_value'] = $to->name;
                break;
            case 'add_class':
                $to = self::klass($r['target_class_id'] ?? null, $lock);
                if ($to->status !== 'active') throw ApiError::field('target_class_id', 'CLASS_NOT_ACTIVE');
                if (self::enrollment($userId, (int) $to->id)) throw ApiError::conflict('ALREADY_ENROLLED', 'Already enrolled');
                $program = $r['requested_value'] ?? 'regular';
                if (! in_array($program, ['regular', 'distance'], true)) throw ApiError::field('requested_value', 'INVALID');
                self::assertProgramOffered($to, $program);
                self::assertCapacity($to);
                $r['requested_value'] = $program;
                break;
            case 'drop_class':
                $r['current_value'] = 'active';
                $r['requested_value'] = 'withdrawn';
                break;
            case 'stream_change':
                $c = self::klass($r['class_id']);
                $allowed = self::streams($c);
                if (! $allowed) throw ApiError::field('requested_value', 'STREAMS_NOT_CONFIGURED');
                if (! in_array($r['requested_value'] ?? null, $allowed, true)) throw ApiError::field('requested_value', 'INVALID_STREAM');
                if ($e->stream === $r['requested_value']) throw ApiError::field('requested_value', 'NO_CHANGE');
                $r['current_value'] = $e->stream;
                break;
            case 'study_mode_change':
                $mode = $r['requested_value'] ?? null;
                if (! in_array($mode, ['regular', 'distance'], true)) throw ApiError::field('requested_value', 'INVALID');
                if ($e->program === $mode) throw ApiError::field('requested_value', 'NO_CHANGE');
                self::assertProgramOffered(self::klass($r['class_id']), $mode);
                $r['current_value'] = $e->program;
                break;
            case 'add_subject':
            case 'drop_subject':
                $course = DB::table('edu_courses')->where('id', (int) ($r['course_id'] ?? 0))->first();
                if (! $course) throw ApiError::field('course_id', 'COURSE_NOT_FOUND');
                $on = Edu::onRoster($course, $userId);
                if ($type === 'add_subject') {
                    if ($on) throw ApiError::conflict('ALREADY_ENROLLED', 'Already taking this subject');
                    if (($course->status ?? 'active') !== 'active') throw ApiError::field('course_id', 'COURSE_NOT_ACTIVE');
                    if (! DB::table('edu_enrollments')->where(['user_id' => $userId, 'status' => 'active'])->exists()) throw ApiError::field('course_id', 'NOT_ENROLLED');
                } elseif (! $on) {
                    throw ApiError::field('course_id', 'NOT_ENROLLED');
                }
                $r['class_id'] = $course->class_id;
                $r['current_value'] = $type === 'add_subject' ? null : $course->name;
                $r['requested_value'] = $type === 'add_subject' ? $course->name : null;
                break;
            case 'other':
                if (! trim((string) ($r['requested_value'] ?? ''))) throw ApiError::field('requested_value', 'REQUIRED');
                break;
        }
        return $r;
    }

    public static function create(AuthContext $auth, array $in): array
    {
        $row = ['type' => $in['type'], 'class_id' => $in['class_id'] ?? null, 'target_class_id' => $in['target_class_id'] ?? null, 'course_id' => $in['course_id'] ?? null,
            'requested_value' => $in['requested_value'] ?? null, 'reason' => $in['reason']];
        $id = DB::transaction(function () use ($auth, $row) {
            DB::table('users')->where('id', $auth->id)->lockForUpdate()->first(['id']);
            $row = self::check($auth->id, $row);
            // One pending request of a kind for the same class / subject at a time.
            $dup = DB::table('edu_requests')->where(['user_id' => $auth->id, 'type' => $row['type'], 'status' => 'pending'])
                ->where(fn ($w) => $w->where('class_id', $row['class_id'])->orWhereNull('class_id'))
                ->where(fn ($w) => $row['course_id'] ? $w->where('course_id', $row['course_id']) : $w)->exists();
            if ($dup) throw ApiError::conflict('REQUEST_EXISTS', 'You already have a pending request of this kind');
            $id = DB::table('edu_requests')->insertGetId($row + ['user_id' => $auth->id, 'status' => 'pending']);
            DB::table('edu_requests')->where('id', $id)->update(['ref' => 'ER-' . date('Y') . '-' . str_pad((string) $id, 6, '0', STR_PAD_LEFT)]);
            return $id;
        });
        $admins = array_values(array_diff(Holders::of('education.manage'), [$auth->id]));
        Notifications::createForUsers($admins, [
            'type' => 'education',
            'title' => T::t('edu.request.new.title'),
            'body' => T::t('edu.request.new.body', ['name' => $auth->fullName, 'type' => T::t('edu.request.type.' . $row['type'])]),
            'entityType' => 'edu_request',
            'entityId' => $id,
            'dedupeKey' => fn ($uid) => "edu:request:$id:new:$uid",
        ]);
        return self::get($id);
    }

    public static function get(int $id): array
    {
        $r = DB::table('edu_requests as r')->join('users as u', 'u.id', '=', 'r.user_id')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'r.class_id')->leftJoin('edu_classes as tc', 'tc.id', '=', 'r.target_class_id')
            ->leftJoin('edu_courses as co', 'co.id', '=', 'r.course_id')->leftJoin('users as rv', 'rv.id', '=', 'r.reviewed_by')
            ->where('r.id', $id)
            ->first(['r.*', 'u.full_name', 'u.member_no', 'u.member_group', 'c.name as class_name', 'tc.name as target_class_name', 'co.name as course_name', 'rv.full_name as reviewed_by_name']);
        if (! $r) throw ApiError::notFound('REQUEST_NOT_FOUND', 'Request not found');
        $r->member_id = MemberIds::format($r->member_no, $r->member_group);
        unset($r->member_no);
        return (array) $r;
    }

    public static function mine(AuthContext $auth): array
    {
        return array_map(fn ($id) => self::get((int) $id), DB::table('edu_requests')->where('user_id', $auth->id)->orderByDesc('id')->limit(200)->pluck('id')->all());
    }

    public static function cancel(AuthContext $auth, int $id): array
    {
        $n = DB::table('edu_requests')->where(['id' => $id, 'user_id' => $auth->id, 'status' => 'pending'])->update(['status' => 'cancelled']);
        if (! $n) throw ApiError::notFound('REQUEST_NOT_FOUND', 'Request not found');
        return self::get($id);
    }

    public static function adminList(array $f, array $page): array
    {
        $qb = DB::table('edu_requests as r')->join('users as u', 'u.id', '=', 'r.user_id')->select('r.id')->orderByDesc('r.created_at');
        if (! empty($f['status'])) $qb->where('r.status', $f['status']);
        if (! empty($f['type'])) $qb->where('r.type', $f['type']);
        if (! empty($f['class_id'])) $qb->where(fn ($w) => $w->where('r.class_id', $f['class_id'])->orWhere('r.target_class_id', $f['class_id']));
        if (! empty($f['q'])) MemberIds::search($qb, $f['q']);
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($r) => self::get((int) $r->id), $res['items']), 'meta' => $res['meta']];
    }

    /** Approve (and carry out) or reject a pending request. */
    public static function review(array $actx, int $id, string $decision, ?string $note): array
    {
        $by = $actx['auth']->id;
        if ($decision === 'reject' && ! trim((string) $note)) throw ApiError::field('note', 'REQUIRED');
        $req = DB::transaction(function () use ($actx, $id, $decision, $note, $by) {
            $r = DB::table('edu_requests')->where('id', $id)->lockForUpdate()->first();
            if (! $r || $r->status !== 'pending') throw ApiError::conflict('REQUEST_NOT_PENDING', 'Only a pending request can be decided');
            if ((int) $r->user_id === $by && ! $actx['auth']->isSystem) throw ApiError::forbidden('SELF_APPROVAL', 'You cannot decide your own request');
            $now = Dates::sql(Dates::now());
            if ($decision === 'reject') {
                DB::table('edu_requests')->where('id', $id)->update(['status' => 'rejected', 'reviewed_by' => $by, 'reviewed_at' => $now, 'review_note' => $note]);
            } else {
                $checked = self::check((int) $r->user_id, (array) $r, true);
                self::implement((int) $r->user_id, (object) $checked, $by, $note);
                $final = $r->type === 'other' ? 'approved' : 'implemented';
                DB::table('edu_requests')->where('id', $id)->update(['status' => $final, 'reviewed_by' => $by, 'reviewed_at' => $now, 'review_note' => $note, 'implemented_at' => $final === 'implemented' ? $now : null]);
            }
            EduJourney::record((int) $r->user_id, 'request_decided', ['class_id' => $r->class_id, 'course_id' => $r->course_id, 'ref_type' => 'edu_request', 'ref_id' => $id, 'old' => $r->type, 'new' => $decision === 'reject' ? 'rejected' : 'approved', 'reason' => $note], $by);
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_request', $id, ['decision' => $decision, 'type' => $r->type, 'user_id' => $r->user_id, 'note' => $note], inTrx: true);
            return $r;
        });
        Choir::scheduleEligibility([(int) $req->user_id]);
        Notifications::createForUsers([(int) $req->user_id], [
            'type' => 'education',
            'title' => T::t($decision === 'reject' ? 'edu.request.rejected.title' : 'edu.request.approved.title'),
            'body' => T::t($decision === 'reject' ? 'edu.request.rejected.body' : 'edu.request.approved.body', ['type' => T::t('edu.request.type.' . $req->type), 'note' => $note ?? '']),
            'entityType' => 'edu_request',
            'entityId' => $id,
            'dedupeKey' => fn ($uid) => "edu:request:$id:decided:$uid",
        ]);
        return self::get($id);
    }

    /** Carry out an approved request on the enrollment records (inside the review transaction). */
    private static function implement(int $userId, object $r, int $by, ?string $note): void
    {
        $j = fn (string $event, array $ctx) => EduJourney::record($userId, $event, $ctx + ['ref_type' => 'edu_request', 'ref_id' => $r->id ?? null, 'reason' => $note], $by);
        switch ($r->type) {
            case 'class_change':
                $e = self::enrollment($userId, (int) $r->class_id, true);
                DB::table('edu_enrollments')->where('id', $e->id)->update(['status' => 'withdrawn']);
                DB::table('edu_enrollments')->upsert([['class_id' => $r->target_class_id, 'user_id' => $userId, 'program' => $e->program, 'stream' => null, 'status' => 'active']], ['class_id', 'user_id'], ['program', 'stream', 'status']);
                $j('class_changed', ['class_id' => $r->target_class_id, 'old' => $r->current_value, 'new' => $r->requested_value]);
                break;
            case 'add_class':
                DB::table('edu_enrollments')->upsert([['class_id' => $r->target_class_id, 'user_id' => $userId, 'program' => $r->requested_value, 'status' => 'active']], ['class_id', 'user_id'], ['program', 'status']);
                $j('enrolled', ['class_id' => $r->target_class_id, 'new' => $r->requested_value]);
                break;
            case 'drop_class':
                DB::table('edu_enrollments')->where(['class_id' => $r->class_id, 'user_id' => $userId, 'status' => 'active'])->update(['status' => 'withdrawn']);
                $j('withdrawn', ['class_id' => $r->class_id, 'old' => 'active', 'new' => 'withdrawn']);
                break;
            case 'stream_change':
                DB::table('edu_enrollments')->where(['class_id' => $r->class_id, 'user_id' => $userId, 'status' => 'active'])->update(['stream' => $r->requested_value]);
                $j('stream_changed', ['class_id' => $r->class_id, 'old' => $r->current_value, 'new' => $r->requested_value]);
                break;
            case 'study_mode_change':
                DB::table('edu_enrollments')->where(['class_id' => $r->class_id, 'user_id' => $userId, 'status' => 'active'])->update(['program' => $r->requested_value]);
                $j('study_mode_changed', ['class_id' => $r->class_id, 'old' => $r->current_value, 'new' => $r->requested_value]);
                break;
            case 'add_subject':
            case 'drop_subject':
                self::setSubject($userId, (int) $r->course_id, $r->type === 'add_subject', $by);
                $j($r->type === 'add_subject' ? 'subject_added' : 'subject_dropped', ['class_id' => $r->class_id, 'course_id' => $r->course_id]);
                break;
        }
    }

    /**
     * Add or drop one subject for a student. A subject of the student's own class that was dropped is
     * simply restored; one from another class is recorded as added. Marks stay on record either way.
     */
    public static function setSubject(int $userId, int $courseId, bool $add, int $by): void
    {
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        $inClass = (bool) self::enrollment($userId, (int) $course->class_id);
        $existing = DB::table('edu_course_enrollments')->where(['user_id' => $userId, 'course_id' => $courseId])->first();
        if ($add) {
            if ($inClass) {
                if ($existing) DB::table('edu_course_enrollments')->where('id', $existing->id)->delete();
            } else {
                DB::table('edu_course_enrollments')->upsert([['user_id' => $userId, 'course_id' => $courseId, 'status' => 'added', 'changed_by' => $by]], ['user_id', 'course_id'], ['status', 'changed_by']);
            }
        } elseif ($inClass) {
            DB::table('edu_course_enrollments')->upsert([['user_id' => $userId, 'course_id' => $courseId, 'status' => 'dropped', 'changed_by' => $by]], ['user_id', 'course_id'], ['status', 'changed_by']);
        } elseif ($existing) {
            DB::table('edu_course_enrollments')->where('id', $existing->id)->delete();
        }
    }
}
