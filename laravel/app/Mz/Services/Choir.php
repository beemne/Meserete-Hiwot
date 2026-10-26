<?php

namespace App\Mz\Services;

use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use Illuminate\Support\Facades\DB;

/** The member's holiday-selection result, eligibility recompute hooks, education calendar (port of choirService.js). */
final class Choir
{
    public static function mine(int $userId): array
    {
        return Selections::forMember($userId);
    }

    public static function refresh(): array
    {
        return Selections::recomputeOpen();
    }

    /** Anything that changes attendance, results, payments or participation calls this. */
    public static function scheduleEligibility(array $userIds): void
    {
        Selections::scheduleRecompute($userIds);
    }

    /** Class sessions as a calendar, in the shape of the program calendar. */
    public static function educationCalendar(int $userId, string $from, string $to): array
    {
        // Only the sessions this student was expected at (their scheduled days, until the course ends).
        $rows = [];
        foreach (DB::table('edu_enrollments as e')->join('edu_classes as c', 'c.id', '=', 'e.class_id')->where('e.user_id', $userId)->get(['e.class_id', 'c.name as class_name', 'e.program']) as $en) {
            foreach (Edu::expectedDates((int) $en->class_id, $en->program, $from, $to) as $d) {
                $rows[] = (object) ['class_id' => $en->class_id, 'class_name' => $en->class_name, 'session_date' => $d];
            }
        }
        $mine = DB::table('edu_attendance')->where('user_id', $userId)->whereBetween('session_date', [$from, $to])->select('class_id', 'session_date', 'status')->get();
        $byKey = [];
        foreach ($mine as $m) {
            // No late status any more: an old "late" mark counts as present.
            $byKey[$m->class_id . ':' . Dates::toDateOnly($m->session_date)] = $m->status === 'late' ? 'present' : $m->status;
        }
        $progMine = DB::table('attendance as a')
            ->join('attendance_edu_classes as ac', 'ac.attendance_id', '=', 'a.id')
            ->where('a.user_id', $userId)
            ->whereBetween('a.occurrence_date', [$from, $to])
            ->select('ac.class_id', 'a.occurrence_date as session_date', 'a.status')
            ->get();
        foreach ($progMine as $pm) {
            $key = $pm->class_id . ':' . Dates::toDateOnly($pm->session_date);
            $byKey[$key] = $pm->status === 'late' ? 'present' : $pm->status;
        }
        $days = [];
        $counts = ['present' => 0, 'late' => 0, 'excused' => 0, 'absent' => 0];
        foreach ($rows as $r) {
            $date = Dates::toDateOnly($r->session_date);
            $status = $byKey["{$r->class_id}:$date"] ?? 'absent';
            $counts[$status] = ($counts[$status] ?? 0) + 1;
            $days[$date][] = ['program_id' => $r->class_id, 'title' => $r->class_name, 'date' => $date, 'starts_at' => "{$date}T00:00:00.000Z", 'ends_at' => "{$date}T00:00:00.000Z", 'status' => $status, 'category' => null];
        }
        $order = ['absent', 'late', 'excused', 'present'];
        $total = $counts['present'] + $counts['late'] + $counts['excused'] + $counts['absent'];
        $outDays = [];
        foreach ($days as $date => $items) {
            $state = null;
            foreach ($order as $s) {
                foreach ($items as $i) {
                    if ($i['status'] === $s) { $state = $s; break 2; }
                }
            }
            $outDays[] = ['date' => $date, 'state' => $state, 'occurrences' => $items];
        }
        return [
            'from' => $from,
            'to' => $to,
            'days' => $outDays,
            'stats' => [
                'total_programs' => $total,
                'attended' => $counts['present'],
                'late' => $counts['late'],
                'excused' => $counts['excused'],
                'absent' => $counts['absent'],
                'percentage' => $total ? Num::round1((($counts['present'] + $counts['late']) / max(1, $total - $counts['excused'])) * 100) : null,
                'upcoming' => 0,
            ],
        ];
    }
}
