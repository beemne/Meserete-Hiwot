<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * The life of a mark (edu_scores): the teacher enters it (draft), submits it for review; an
 * education administrator (education.manage) approves or rejects it with a reason — never their
 * own submission — and publishes approved marks, which only then become visible to the student.
 * A rejected mark goes back to the teacher for correction and resubmission. Approved or published
 * marks are changed only through an amendment with a reason by an education administrator. Every
 * step is kept in edu_score_history and in the student's academic journey.
 */
final class EduMarks
{
    /** Marks the teacher may still edit. */
    public const EDITABLE = ['draft', 'rejected'];
    /** Marks that count (selection, reports of results). */
    public const FINAL = ['approved', 'published'];

    public static function history(int $assessmentId, int $userId, string $action, array $from, array $to, ?int $actorId, ?string $reason = null): void
    {
        DB::table('edu_score_history')->insert([
            'assessment_id' => $assessmentId, 'user_id' => $userId, 'action' => $action,
            'old_score' => $from['score'] ?? null, 'new_score' => $to['score'] ?? null,
            'old_status' => $from['status'] ?? null, 'new_status' => $to['status'] ?? null,
            'actor_id' => $actorId, 'reason' => $reason,
        ]);
    }

    private static function assessment(int $id): object
    {
        $a = DB::table('edu_assessments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')->where('a.id', $id)
            ->first(['a.*', 'co.class_id', 'co.name as course_name', 'co.teacher_user_id']);
        if (! $a) throw ApiError::notFound('ASSESSMENT_NOT_FOUND', 'Assessment not found');
        return $a;
    }

    /** Rows of the assessment in [status], optionally limited to some students; locked. */
    private static function rows(int $assessmentId, array $statuses, ?array $userIds): array
    {
        $q = DB::table('edu_scores')->where('assessment_id', $assessmentId)->whereIn('status', $statuses)->lockForUpdate();
        if ($userIds) $q->whereIn('user_id', $userIds);
        return $q->get()->all();
    }

    /** Teacher: send the draft / corrected marks of an assessment for review. Empty marks stay drafts. */
    public static function submit(AuthContext $auth, int $assessmentId, ?array $userIds = null): array
    {
        $a = self::assessment($assessmentId);
        Edu::assertTeachesCourse($auth, (int) $a->course_id);
        $now = Dates::sql(Dates::now());
        $sent = DB::transaction(function () use ($auth, $assessmentId, $userIds, $a, $now) {
            $rows = array_values(array_filter(self::rows($assessmentId, self::EDITABLE, $userIds), fn ($r) => $r->score !== null));
            foreach ($rows as $r) {
                DB::table('edu_scores')->where(['assessment_id' => $assessmentId, 'user_id' => $r->user_id])
                    ->update(['status' => 'submitted', 'submitted_by' => $auth->id, 'submitted_at' => $now, 'reviewed_by' => null, 'reviewed_at' => null]);
                self::history($assessmentId, (int) $r->user_id, 'submitted', ['score' => $r->score, 'status' => $r->status], ['score' => $r->score, 'status' => 'submitted'], $auth->id);
            }
            $ids = array_map(fn ($r) => (int) $r->user_id, $rows);
            if ($ids) EduJourney::recordMany($ids, 'mark_submitted', ['class_id' => $a->class_id, 'course_id' => $a->course_id, 'assessment_id' => $assessmentId], $auth->id);
            return $ids;
        });
        if ($sent) {
            $admins = array_values(array_diff(Holders::of('education.manage'), [$auth->id]));
            Notifications::createForUsers($admins, [
                'type' => 'education',
                'title' => T::t('edu.marks.submitted.title'),
                'body' => T::t('edu.marks.submitted.body', ['assessment' => $a->title, 'course' => $a->course_name, 'n' => count($sent)]),
                'entityType' => 'edu_assessment',
                'entityId' => $assessmentId,
                'dedupeKey' => fn ($uid) => "edu:marks:submitted:$assessmentId:" . md5($now) . ":$uid",
            ]);
        }
        $pending = DB::table('edu_scores')->where('assessment_id', $assessmentId)->whereIn('status', self::EDITABLE)->whereNull('score')->count();
        return ['submitted' => count($sent), 'left_empty' => $pending];
    }

    /** Education administrator: assessments with marks waiting for review (or in another status). */
    public static function queue(array $f, array $page): array
    {
        $status = $f['status'] ?? 'submitted';
        $qb = DB::table('edu_assessments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')->join('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->leftJoin('users as t', 't.id', '=', 'co.teacher_user_id')
            ->whereExists(fn ($s) => $s->select(DB::raw(1))->from('edu_scores as s')->whereColumn('s.assessment_id', 'a.id')->where('s.status', $status))
            ->select('a.id', 'a.title', 'a.max_score', 'a.held_on', 'co.id as course_id', 'co.name as course_name', 'c.id as class_id', 'c.name as class_name', 't.full_name as teacher_name',
                DB::raw("(SELECT COUNT(*) FROM edu_scores s WHERE s.assessment_id = a.id AND s.status = " . DB::getPdo()->quote($status) . ') as marks'),
                DB::raw("(SELECT MAX(s.submitted_at) FROM edu_scores s WHERE s.assessment_id = a.id) as last_submitted_at"))
            ->orderByDesc('last_submitted_at');
        if (! empty($f['class_id'])) $qb->where('c.id', $f['class_id']);
        if (! empty($f['course_id'])) $qb->where('co.id', $f['course_id']);
        return Page::paginate($qb, $page);
    }

    /**
     * Approve or reject submitted marks (all of the assessment, or some students). A reason is
     * required to reject. Nobody approves marks they submitted themselves. With $publish, approved
     * marks are published at once.
     */
    public static function review(array $actx, int $assessmentId, string $decision, ?array $userIds, ?string $note, bool $publish = false): array
    {
        $auth = $actx['auth'];
        $a = self::assessment($assessmentId);
        if ($decision === 'reject' && ! trim((string) $note)) throw ApiError::field('note', 'REQUIRED');
        $now = Dates::sql(Dates::now());
        $done = DB::transaction(function () use ($auth, $assessmentId, $decision, $userIds, $note, $a, $now) {
            $rows = self::rows($assessmentId, ['submitted'], $userIds);
            if (! $rows) throw ApiError::conflict('NOTHING_TO_REVIEW', 'No submitted marks to review');
            if (! $auth->isSystem) {
                foreach ($rows as $r) {
                    if ((int) $r->submitted_by === $auth->id) throw ApiError::forbidden('SELF_APPROVAL', 'You cannot review marks you submitted');
                }
            }
            $status = $decision === 'approve' ? 'approved' : 'rejected';
            foreach ($rows as $r) {
                DB::table('edu_scores')->where(['assessment_id' => $assessmentId, 'user_id' => $r->user_id])
                    ->update(['status' => $status, 'reviewed_by' => $auth->id, 'reviewed_at' => $now, 'review_note' => $note]);
                self::history($assessmentId, (int) $r->user_id, $status, ['score' => $r->score, 'status' => 'submitted'], ['score' => $r->score, 'status' => $status], $auth->id, $note);
            }
            $ids = array_map(fn ($r) => (int) $r->user_id, $rows);
            EduJourney::recordMany($ids, $status === 'approved' ? 'mark_approved' : 'mark_rejected', ['class_id' => $a->class_id, 'course_id' => $a->course_id, 'assessment_id' => $assessmentId, 'reason' => $note], $auth->id);
            return ['ids' => $ids, 'teachers' => array_values(array_unique(array_filter(array_map(fn ($r) => (int) $r->submitted_by, $rows))))];
        });
        Audit::log($actx, Audit::EDU_UPDATE, 'edu_assessment', $assessmentId, ['marks' => $decision, 'students' => count($done['ids']), 'note' => $note]);
        if ($decision === 'reject') {
            Notifications::createForUsers($done['teachers'], [
                'type' => 'education',
                'title' => T::t('edu.marks.rejected.title'),
                'body' => T::t('edu.marks.rejected.body', ['assessment' => $a->title, 'course' => $a->course_name, 'reason' => $note]),
                'entityType' => 'edu_course',
                'entityId' => $a->course_id,
                'dedupeKey' => fn ($uid) => "edu:marks:rejected:$assessmentId:" . md5($now) . ":$uid",
            ]);
        }
        $out = ['decision' => $decision, 'students' => count($done['ids'])];
        if ($publish && $decision === 'approve') $out['published'] = self::publish($actx, $assessmentId, $done['ids'])['published'];
        return $out;
    }

    /** Publish approved marks: from now on the students see them, and they are told. */
    public static function publish(array $actx, int $assessmentId, ?array $userIds = null): array
    {
        $auth = $actx['auth'];
        $a = self::assessment($assessmentId);
        $now = Dates::sql(Dates::now());
        $ids = DB::transaction(function () use ($auth, $assessmentId, $userIds, $a, $now) {
            $rows = self::rows($assessmentId, ['approved'], $userIds);
            foreach ($rows as $r) {
                DB::table('edu_scores')->where(['assessment_id' => $assessmentId, 'user_id' => $r->user_id])->update(['status' => 'published', 'published_by' => $auth->id, 'published_at' => $now]);
                self::history($assessmentId, (int) $r->user_id, 'published', ['score' => $r->score, 'status' => 'approved'], ['score' => $r->score, 'status' => 'published'], $auth->id);
            }
            $ids = array_map(fn ($r) => (int) $r->user_id, $rows);
            if ($ids) EduJourney::recordMany($ids, 'mark_published', ['class_id' => $a->class_id, 'course_id' => $a->course_id, 'assessment_id' => $assessmentId], $auth->id);
            return $ids;
        });
        if ($ids) {
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_assessment', $assessmentId, ['marks' => 'publish', 'students' => count($ids)]);
            Choir::scheduleEligibility($ids);
            Notifications::createForUsers($ids, [
                'type' => 'education',
                'title' => T::t('edu.marks.published.title'),
                'body' => T::t('edu.marks.published.body', ['assessment' => $a->title, 'course' => $a->course_name]),
                'entityType' => 'edu_class',
                'entityId' => $a->class_id,
                'dedupeKey' => fn ($uid) => "edu:marks:published:$assessmentId:$uid",
            ]);
        }
        return ['published' => count($ids)];
    }

    /**
     * Correct an approved or published mark: an education administrator, with a reason; the status
     * stays, the old and new values and the reason are kept, a student whose mark was already
     * published is told.
     */
    public static function amend(array $actx, int $assessmentId, int $userId, ?float $score, string $reason): array
    {
        $auth = $actx['auth'];
        $a = self::assessment($assessmentId);
        if ($score !== null && $score > Num::n($a->max_score)) throw ApiError::validation([['field' => 'score', 'code' => 'SCORE_TOO_HIGH', 'message' => 'SCORE_TOO_HIGH']]);
        $r = DB::transaction(function () use ($auth, $assessmentId, $userId, $score, $reason, $a) {
            $r = DB::table('edu_scores')->where(['assessment_id' => $assessmentId, 'user_id' => $userId])->lockForUpdate()->first();
            if (! $r || ! in_array($r->status, self::FINAL, true)) throw ApiError::conflict('NOT_AMENDABLE', 'Only approved or published marks are amended; edit drafts directly');
            DB::table('edu_scores')->where(['assessment_id' => $assessmentId, 'user_id' => $userId])->update(['score' => $score, 'recorded_by' => $auth->id, 'updated_at' => Dates::sql(Dates::now())]);
            self::history($assessmentId, $userId, 'amended', ['score' => $r->score, 'status' => $r->status], ['score' => $score, 'status' => $r->status], $auth->id, $reason);
            EduJourney::record($userId, 'mark_amended', ['class_id' => $a->class_id, 'course_id' => $a->course_id, 'assessment_id' => $assessmentId, 'old' => $r->score, 'new' => $score, 'reason' => $reason], $auth->id);
            return $r;
        });
        Audit::log($actx, Audit::EXAM_SCORE_UPDATE, 'edu_score', $assessmentId, ['user_id' => $userId, 'old_score' => $r->score !== null ? (float) $r->score : null, 'new_score' => $score, 'reason' => $reason, 'amendment' => true]);
        Choir::scheduleEligibility([$userId]);
        if ($r->status === 'published') {
            Notifications::createForUsers([$userId], [
                'type' => 'education',
                'title' => T::t('edu.marks.amended.title'),
                'body' => T::t('edu.marks.amended.body', ['assessment' => $a->title, 'course' => $a->course_name]),
                'entityType' => 'edu_class',
                'entityId' => $a->class_id,
                'dedupeKey' => fn ($uid) => "edu:marks:amended:$assessmentId:" . microtime(true) . ":$uid",
            ]);
        }
        return ['amended' => true, 'status' => $r->status, 'score' => $score];
    }

    /** The full change log of the marks of an assessment (or of one student). */
    public static function log(int $assessmentId, ?int $userId = null): array
    {
        $q = DB::table('edu_score_history as h')->join('users as u', 'u.id', '=', 'h.user_id')->leftJoin('users as act', 'act.id', '=', 'h.actor_id')
            ->where('h.assessment_id', $assessmentId)
            ->select('h.id', 'h.user_id', 'u.full_name', 'h.action', 'h.old_score', 'h.new_score', 'h.old_status', 'h.new_status', 'h.reason', 'act.full_name as actor_name', 'h.created_at')
            ->orderByDesc('h.id');
        if ($userId) $q->where('h.user_id', $userId);
        return $q->limit(1000)->get()->map(function ($r) {
            $r->old_score = $r->old_score === null ? null : Num::n($r->old_score);
            $r->new_score = $r->new_score === null ? null : Num::n($r->new_score);
            return $r;
        })->all();
    }
}
