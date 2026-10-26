<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

/**
 * Failed courses and online retakes (F11).
 *
 * Rules:
 * - Only finalized failed outcomes can have a retake.
 * - A duplicate active retake gives RETAKE_EXISTS.
 * - Approving creates an edu_course_enrollments row (status 'retake') that gives online course access.
 * - The original marks and outcome are never changed by a retake.
 * - Exactly one outcome per course and student counts for progression (via EduOutcomes::setCounting).
 */
final class EduRetakes
{
    private static function assertManage(AuthContext $auth): void
    {
        if (! $auth->can('education.manage') && ! $auth->can('education.admin')) {
            throw ApiError::forbidden('NOT_AUTHORIZED', 'Only education administrators can manage retakes');
        }
    }

    /** Request an online retake for a failed course. */
    public static function request(AuthContext $auth, int $outcomeId, ?int $targetUserId = null): array
    {
        $outcome = DB::table('edu_course_outcomes')->where('id', $outcomeId)->first();
        if (! $outcome) {
            throw ApiError::notFound('OUTCOME_NOT_FOUND', 'Course outcome not found');
        }

        $userId = $targetUserId ?: (int) $outcome->user_id;
        if ($userId !== $auth->id) {
            self::assertManage($auth);
        }

        if ($outcome->status !== 'finalized') {
            throw ApiError::conflict('OUTCOME_NOT_FINALIZED', 'Only finalized failed outcomes can have a retake');
        }
        if ($outcome->result !== 'failed') {
            throw ApiError::conflict('OUTCOME_NOT_FAILED', 'Only failed outcomes can have a retake');
        }

        $activeExists = DB::table('edu_retakes')
            ->where('course_id', $outcome->course_id)
            ->where('user_id', $outcome->user_id)
            ->whereIn('status', ['requested', 'approved', 'active'])
            ->exists();

        if ($activeExists) {
            throw ApiError::conflict('RETAKE_EXISTS', 'A retake is already requested or active for this course');
        }

        $now = Dates::sql(Dates::now());
        $id = DB::table('edu_retakes')->insertGetId([
            'original_outcome_id' => $outcome->id,
            'user_id' => $outcome->user_id,
            'course_id' => $outcome->course_id,
            'status' => 'requested',
            'requested_by' => $auth->id,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        EduJourney::record((int) $outcome->user_id, 'retake_requested', [
            'course_id' => $outcome->course_id,
            'outcome_id' => $outcome->id,
            'retake_id' => $id,
        ], $auth->id);

        Audit::log(['auth' => $auth], Audit::EDU_UPDATE, 'edu_retake', $id, [
            'action' => 'request',
            'course_id' => $outcome->course_id,
            'user_id' => $outcome->user_id,
        ]);

        return (array) DB::table('edu_retakes')->where('id', $id)->first();
    }

    /** Approve or reject a retake request. */
    public static function decide(AuthContext $auth, int $retakeId, string $decision, ?string $note = null): array
    {
        self::assertManage($auth);

        $retake = DB::table('edu_retakes')->where('id', $retakeId)->first();
        if (! $retake) {
            throw ApiError::notFound('RETAKE_NOT_FOUND', 'Retake request not found');
        }
        if ($retake->status !== 'requested') {
            throw ApiError::conflict('ALREADY_DECIDED', 'This retake request has already been decided');
        }

        $now = Dates::sql(Dates::now());
        $isApprove = in_array(strtolower($decision), ['approve', 'approved'], true);

        if ($isApprove) {
            DB::transaction(function () use ($retake, $retakeId, $auth, $note, $now) {
                DB::table('edu_retakes')->where('id', $retakeId)->update([
                    'status' => 'approved',
                    'decided_by' => $auth->id,
                    'decided_at' => $now,
                    'decision_note' => $note,
                    'updated_at' => $now,
                ]);

                // Create or update edu_course_enrollments with status 'retake'
                DB::table('edu_course_enrollments')->upsert([
                    [
                        'user_id' => $retake->user_id,
                        'course_id' => $retake->course_id,
                        'status' => 'retake',
                        'changed_by' => $auth->id,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]
                ], ['user_id', 'course_id'], ['status', 'changed_by', 'updated_at']);
            });

            EduJourney::record((int) $retake->user_id, 'retake_approved', [
                'course_id' => $retake->course_id,
                'retake_id' => $retakeId,
                'note' => $note,
            ], $auth->id);
        } else {
            DB::table('edu_retakes')->where('id', $retakeId)->update([
                'status' => 'rejected',
                'decided_by' => $auth->id,
                'decided_at' => $now,
                'decision_note' => $note,
                'updated_at' => $now,
            ]);

            EduJourney::record((int) $retake->user_id, 'retake_rejected', [
                'course_id' => $retake->course_id,
                'retake_id' => $retakeId,
                'note' => $note,
            ], $auth->id);
        }

        Audit::log(['auth' => $auth], Audit::EDU_UPDATE, 'edu_retake', $retakeId, [
            'action' => $decision,
            'course_id' => $retake->course_id,
            'user_id' => $retake->user_id,
            'note' => $note,
        ]);

        return (array) DB::table('edu_retakes')->where('id', $retakeId)->first();
    }

    /** List retakes (admin sees all; students see their own). */
    public static function list(AuthContext $auth, array $filters = []): array
    {
        $isManage = $auth->can('education.manage') || $auth->can('education.admin');

        $q = DB::table('edu_retakes as r')
            ->join('users as u', 'u.id', '=', 'r.user_id')
            ->join('edu_courses as c', 'c.id', '=', 'r.course_id')
            ->select('r.*', 'u.full_name', 'u.member_no', 'c.name as course_name')
            ->orderByDesc('r.id');

        if (! $isManage) {
            $q->where('r.user_id', $auth->id);
        } else {
            if (! empty($filters['course_id'])) $q->where('r.course_id', (int) $filters['course_id']);
            if (! empty($filters['status'])) $q->where('r.status', $filters['status']);
        }

        return $q->get()->map(fn ($r) => [
            'id' => (int) $r->id,
            'original_outcome_id' => (int) $r->original_outcome_id,
            'user_id' => (int) $r->user_id,
            'full_name' => $r->full_name,
            'member_no' => $r->member_no,
            'course_id' => (int) $r->course_id,
            'course_name' => $r->course_name,
            'status' => $r->status,
            'requested_by' => (int) $r->requested_by,
            'decided_by' => $r->decided_by ? (int) $r->decided_by : null,
            'decided_at' => $r->decided_at,
            'decision_note' => $r->decision_note,
            'created_at' => $r->created_at,
        ])->all();
    }
}
