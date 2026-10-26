<?php

namespace App\Mz\Services;

use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

/**
 * A student's (or teacher's) academic history in ትምህርት: enrollment, class / stream / study-mode
 * changes, subjects added or dropped, teacher assignments, and marks submitted, approved, published
 * or corrected. Append-only — an entry is never changed or removed to show the latest state.
 */
final class EduJourney
{
    public const EVENTS = [
        'enrolled', 'assigned', 'withdrawn', 'class_changed', 'stream_changed', 'study_mode_changed', 'subject_added', 'subject_dropped',
        'teacher_assigned', 'teacher_suspended', 'teacher_reactivated', 'teacher_removed',
        'mark_submitted', 'mark_approved', 'mark_rejected', 'mark_published', 'mark_amended', 'request_decided',
    ];

    /**
     * @param array{class_id?:?int,course_id?:?int,assessment_id?:?int,ref_type?:?string,ref_id?:?int,old?:mixed,new?:mixed,reason?:?string} $ctx
     */
    public static function record(int $userId, string $event, array $ctx = [], ?int $actorId = null): void
    {
        self::recordMany([$userId], $event, $ctx, $actorId);
    }

    public static function recordMany(array $userIds, string $event, array $ctx = [], ?int $actorId = null): void
    {
        $val = fn ($v) => $v === null ? null : mb_substr(is_scalar($v) ? (string) $v : json_encode($v, JSON_UNESCAPED_UNICODE), 0, 255);
        $rows = [];
        foreach (array_unique(array_map('intval', $userIds)) as $uid) {
            $rows[] = [
                'user_id' => $uid,
                'event' => $event,
                'class_id' => $ctx['class_id'] ?? null,
                'course_id' => $ctx['course_id'] ?? null,
                'assessment_id' => $ctx['assessment_id'] ?? null,
                'ref_type' => $ctx['ref_type'] ?? null,
                'ref_id' => $ctx['ref_id'] ?? null,
                'old_value' => $val($ctx['old'] ?? null),
                'new_value' => $val($ctx['new'] ?? null),
                'actor_id' => $actorId,
                'reason' => $ctx['reason'] ?? null,
            ];
        }
        foreach (array_chunk($rows, 500) as $chunk) DB::table('edu_journey')->insert($chunk);
    }

    /** Newest first, with the names of the class, subject, assessment and who acted. */
    public static function forUser(int $userId, array $page): array
    {
        $qb = DB::table('edu_journey as j')
            ->leftJoin('edu_classes as c', 'c.id', '=', 'j.class_id')
            ->leftJoin('edu_courses as co', 'co.id', '=', 'j.course_id')
            ->leftJoin('edu_assessments as a', 'a.id', '=', 'j.assessment_id')
            ->leftJoin('users as act', 'act.id', '=', 'j.actor_id')
            ->where('j.user_id', $userId)
            ->select('j.id', 'j.event', 'j.class_id', 'c.name as class_name', 'j.course_id', 'co.name as course_name', 'j.assessment_id', 'a.title as assessment_title',
                'j.ref_type', 'j.ref_id', 'j.old_value', 'j.new_value', 'j.reason', 'act.full_name as actor_name', 'j.created_at')
            ->orderByDesc('j.created_at')->orderByDesc('j.id');
        return Page::paginate($qb, $page);
    }
}
