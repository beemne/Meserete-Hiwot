<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use Illuminate\Support\Facades\DB;

/**
 * Course outcomes and pass marks (F10).
 * Turns published marks into a finalized course outcome (passed or failed, with a percentage)
 * using the course's pass mark (default 50.00).
 *
 * Rules:
 * - Unpublished marks never affect an outcome.
 * - Incomplete if any assessment lacks a published mark.
 * - Changing a finalized outcome requires amending marks through EduMarks::amend,
 *   then a recompute that marks the old row superseded and creates a new provisional row.
 * - Exactly one outcome per course and student counts for progression.
 */
final class EduOutcomes
{
    private static function assertManage(AuthContext $auth): void
    {
        if (! $auth->can('education.manage') && ! $auth->can('education.admin')) {
            throw ApiError::forbidden('NOT_AUTHORIZED', 'Only education administrators can manage course outcomes');
        }
    }

    /** Compute provisional course outcomes from published marks. */
    public static function compute(int $courseId, ?string $amendmentReason = null): array
    {
        $course = DB::table('edu_courses')->where('id', $courseId)->first();
        if (! $course) {
            throw ApiError::notFound('COURSE_NOT_FOUND', 'Course not found');
        }
        $passMark = Num::n($course->pass_mark ?? 50.00);

        $assessments = DB::table('edu_assessments')->where('course_id', $courseId)->orderBy('held_on')->orderBy('id')->get();
        $totalWeight = (float) $assessments->sum('weight');

        $now = Dates::sql(Dates::now());
        $results = [];

        // 1. Original attempts for roster students
        $students = Edu::rosterQuery($course)->select('u.id', 'u.full_name', 'u.member_no')->distinct()->get();

        foreach ($students as $student) {
            $computed = self::calculateStudentOutcome($courseId, (int) $student->id, 1, $assessments, $totalWeight, $passMark);
            $outcome = self::upsertOutcome($courseId, (int) $student->id, 'original', null, $computed, $passMark, $now, $amendmentReason);
            $results[] = $outcome;
        }

        // 2. Retake attempts from edu_retakes
        $retakes = DB::table('edu_retakes')
            ->where('course_id', $courseId)
            ->whereIn('status', ['approved', 'active', 'completed'])
            ->get();

        foreach ($retakes as $retake) {
            $computed = self::calculateStudentOutcome($courseId, (int) $retake->user_id, 2, $assessments, $totalWeight, $passMark);
            $outcome = self::upsertOutcome($courseId, (int) $retake->user_id, 'retake', (int) $retake->id, $computed, $passMark, $now, $amendmentReason);
            $results[] = $outcome;

            // Mark retake active or completed
            if ($computed['result'] === 'passed') {
                DB::table('edu_retakes')->where('id', $retake->id)->update(['status' => 'completed', 'updated_at' => $now]);
            } elseif ($retake->status === 'approved') {
                DB::table('edu_retakes')->where('id', $retake->id)->update(['status' => 'active', 'updated_at' => $now]);
            }
        }

        return $results;
    }

    /** Calculate weighted outcome for a student on a specific attempt. */
    private static function calculateStudentOutcome(int $courseId, int $userId, int $attempt, $assessments, float $totalWeight, float $passMark): array
    {
        if ($assessments->isEmpty()) {
            return ['percent' => 0.00, 'result' => 'incomplete'];
        }

        $allPublished = true;
        $weightedSum = 0.0;
        $weightSum = 0.0;

        foreach ($assessments as $a) {
            $score = DB::table('edu_scores')
                ->where('assessment_id', $a->id)
                ->where('user_id', $userId)
                ->where('status', 'published')
                ->where(function ($q) use ($attempt) {
                    if ($attempt === 1) {
                        $q->whereNull('attempt')->orWhere('attempt', 1);
                    } else {
                        $q->where('attempt', $attempt);
                    }
                })
                ->first();

            if (! $score || $score->score === null) {
                $allPublished = false;
                continue;
            }

            $w = Num::n($a->weight);
            $max = Num::n($a->max_score);
            $s = Num::n($score->score);

            if ($max > 0) {
                $weightedSum += ($s / $max) * $w;
            }
            $weightSum += $w;
        }

        if (! $allPublished) {
            return ['percent' => 0.00, 'result' => 'incomplete'];
        }

        $finalPercent = $totalWeight > 0
            ? round(($weightedSum / $totalWeight) * 100, 2)
            : ($assessments->count() > 0 ? round(($weightedSum / $assessments->count()) * 100, 2) : 0.00);

        $result = $finalPercent >= $passMark ? 'passed' : 'failed';
        return ['percent' => $finalPercent, 'result' => $result];
    }

    /** Upsert outcome, respecting finalized rows and superseding on amendment. */
    private static function upsertOutcome(int $courseId, int $userId, string $attemptType, ?int $retakeId, array $computed, float $passMark, string $now, ?string $amendmentReason): array
    {
        $existing = DB::table('edu_course_outcomes')
            ->where('course_id', $courseId)
            ->where('user_id', $userId)
            ->where('attempt_type', $attemptType)
            ->where(fn ($q) => $retakeId ? $q->where('retake_id', $retakeId) : $q->whereNull('retake_id'))
            ->whereIn('status', ['provisional', 'finalized'])
            ->first();

        if ($existing) {
            if ($existing->status === 'finalized') {
                // If scores changed after finalization (due to amendment), mark existing as superseded
                $sameScore = abs((float) $existing->percent - (float) $computed['percent']) < 0.001
                    && $existing->result === $computed['result'];

                if (! $sameScore) {
                    DB::table('edu_course_outcomes')->where('id', $existing->id)->update([
                        'status' => 'superseded',
                        'note' => $amendmentReason ?: ($existing->note ? $existing->note . ' (Superseded by amendment)' : 'Superseded by amendment'),
                        'updated_at' => $now,
                    ]);

                    $id = DB::table('edu_course_outcomes')->insertGetId([
                        'course_id' => $courseId,
                        'user_id' => $userId,
                        'attempt_type' => $attemptType,
                        'retake_id' => $retakeId,
                        'percent' => $computed['percent'],
                        'pass_mark' => $passMark,
                        'result' => $computed['result'],
                        'status' => 'provisional',
                        'counts_for_progression' => $existing->counts_for_progression,
                        'note' => $amendmentReason,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                    return (array) DB::table('edu_course_outcomes')->where('id', $id)->first();
                }
                return (array) $existing;
            }

            // Update provisional row
            DB::table('edu_course_outcomes')->where('id', $existing->id)->update([
                'percent' => $computed['percent'],
                'pass_mark' => $passMark,
                'result' => $computed['result'],
                'updated_at' => $now,
            ]);
            return (array) DB::table('edu_course_outcomes')->where('id', $existing->id)->first();
        }

        // Insert new provisional outcome
        $id = DB::table('edu_course_outcomes')->insertGetId([
            'course_id' => $courseId,
            'user_id' => $userId,
            'attempt_type' => $attemptType,
            'retake_id' => $retakeId,
            'percent' => $computed['percent'],
            'pass_mark' => $passMark,
            'result' => $computed['result'],
            'status' => 'provisional',
            'counts_for_progression' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        return (array) DB::table('edu_course_outcomes')->where('id', $id)->first();
    }

    /** Finalize provisional outcomes (freezes them). */
    public static function finalize(AuthContext $auth, int $courseId, ?array $userIds = null): array
    {
        self::assertManage($auth);

        $now = Dates::sql(Dates::now());
        $q = DB::table('edu_course_outcomes')
            ->where('course_id', $courseId)
            ->where('status', 'provisional');

        if ($userIds) {
            $q->whereIn('user_id', $userIds);
        }

        $rows = $q->get();
        $ids = [];

        foreach ($rows as $r) {
            DB::table('edu_course_outcomes')->where('id', $r->id)->update([
                'status' => 'finalized',
                'finalized_by' => $auth->id,
                'finalized_at' => $now,
                'updated_at' => $now,
            ]);
            $ids[] = (int) $r->user_id;

            EduJourney::record((int) $r->user_id, 'course_outcome_finalized', [
                'course_id' => $courseId,
                'outcome_id' => $r->id,
                'result' => $r->result,
                'percent' => (float) $r->percent,
                'attempt_type' => $r->attempt_type,
            ], $auth->id);
        }

        if (! empty($ids)) {
            Audit::log(['auth' => $auth], Audit::EDU_UPDATE, 'edu_course_outcome', $courseId, [
                'action' => 'finalize',
                'finalized_count' => count($rows),
            ]);
        }

        return ['finalized' => count($rows), 'user_ids' => $ids];
    }

    /** Set which outcome counts for progression (exactly one per course and student). */
    public static function setCounting(AuthContext $auth, int $outcomeId, string $reason): array
    {
        self::assertManage($auth);

        $target = DB::table('edu_course_outcomes')->where('id', $outcomeId)->first();
        if (! $target) {
            throw ApiError::notFound('OUTCOME_NOT_FOUND', 'Outcome not found');
        }
        if ($target->status !== 'finalized') {
            throw ApiError::conflict('OUTCOME_NOT_FINALIZED', 'Only finalized outcomes can be set as counting for progression');
        }

        $now = Dates::sql(Dates::now());

        DB::transaction(function () use ($target, $outcomeId, $reason, $now) {
            // Clear counting flag from all other outcomes for this course and student
            DB::table('edu_course_outcomes')
                ->where('course_id', $target->course_id)
                ->where('user_id', $target->user_id)
                ->update(['counts_for_progression' => 0, 'updated_at' => $now]);

            // Set counting on target outcome
            DB::table('edu_course_outcomes')
                ->where('id', $outcomeId)
                ->update([
                    'counts_for_progression' => 1,
                    'note' => $reason,
                    'updated_at' => $now,
                ]);
        });

        Audit::log(['auth' => $auth], Audit::EDU_UPDATE, 'edu_course_outcome', $outcomeId, [
            'action' => 'set_counting',
            'course_id' => $target->course_id,
            'user_id' => $target->user_id,
            'reason' => $reason,
        ]);

        EduJourney::record((int) $target->user_id, 'outcome_counting_changed', [
            'course_id' => $target->course_id,
            'outcome_id' => $outcomeId,
            'reason' => $reason,
        ], $auth->id);

        return (array) DB::table('edu_course_outcomes')->where('id', $outcomeId)->first();
    }

    /** Get outcomes for a course (admins/teachers see all; students see finalized only). */
    public static function forCourse(AuthContext $auth, int $courseId): array
    {
        $isTeacherOrAdmin = Edu::isModerator($auth) || EduTeachers::isActive($courseId, $auth->id);

        $q = DB::table('edu_course_outcomes as o')
            ->join('users as u', 'u.id', '=', 'o.user_id')
            ->where('o.course_id', $courseId)
            ->select('o.*', 'u.full_name', 'u.member_no')
            ->orderBy('u.full_name')
            ->orderByDesc('o.id');

        if (! $isTeacherOrAdmin) {
            $q->where('o.user_id', $auth->id)->where('o.status', 'finalized');
        }

        return $q->get()->map(fn ($r) => [
            'id' => (int) $r->id,
            'course_id' => (int) $r->course_id,
            'user_id' => (int) $r->user_id,
            'full_name' => $r->full_name,
            'member_no' => $r->member_no,
            'attempt_type' => $r->attempt_type,
            'retake_id' => $r->retake_id ? (int) $r->retake_id : null,
            'percent' => (float) $r->percent,
            'pass_mark' => (float) $r->pass_mark,
            'result' => $r->result,
            'status' => $r->status,
            'counts_for_progression' => (bool) $r->counts_for_progression,
            'finalized_at' => $r->finalized_at,
            'note' => $r->note,
        ])->all();
    }

    /** Get finalized outcomes for a student across all courses. */
    public static function forStudent(AuthContext $auth, ?int $userId = null): array
    {
        $targetUserId = $userId ?: $auth->id;
        if ($targetUserId !== $auth->id && ! Edu::isModerator($auth)) {
            throw ApiError::forbidden('NOT_AUTHORIZED', 'You can only view your own outcomes');
        }

        return DB::table('edu_course_outcomes as o')
            ->join('edu_courses as c', 'c.id', '=', 'o.course_id')
            ->leftJoin('edu_classes as cl', 'cl.id', '=', 'c.class_id')
            ->where('o.user_id', $targetUserId)
            ->where('o.status', 'finalized')
            ->select('o.*', 'c.name as course_name', 'cl.name as class_name')
            ->orderByDesc('o.finalized_at')
            ->get()->map(fn ($r) => [
                'id' => (int) $r->id,
                'course_id' => (int) $r->course_id,
                'course_name' => $r->course_name,
                'class_name' => $r->class_name,
                'attempt_type' => $r->attempt_type,
                'retake_id' => $r->retake_id ? (int) $r->retake_id : null,
                'percent' => (float) $r->percent,
                'pass_mark' => (float) $r->pass_mark,
                'result' => $r->result,
                'counts_for_progression' => (bool) $r->counts_for_progression,
                'finalized_at' => $r->finalized_at,
                'note' => $r->note,
            ])->all();
    }
}
