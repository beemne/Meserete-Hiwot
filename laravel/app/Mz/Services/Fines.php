<?php

namespace App\Mz\Services;

use App\Mz\Support\Dates;
use App\Mz\Support\Num;

/** Pure fine / deadline logic for borrowings (port of fineCalculator.js). */
final class Fines
{
    public static function compute(string $dueOn, string $asOf, array $policy): int|float
    {
        if (empty($policy['enabled']) || ! (($policy['amount'] ?? 0) > 0)) return 0;
        $lateDays = Dates::calendarDaysBetween($dueOn, $asOf) - (int) ($policy['grace_days'] ?? 0);
        if ($lateDays <= 0) return 0;
        $units = ($policy['period'] ?? 'day') === 'week' ? (int) ceil($lateDays / 7) : $lateDays;
        $amount = $units * $policy['amount'];
        if (isset($policy['max_amount']) && $policy['max_amount'] !== null) $amount = min($amount, $policy['max_amount']);
        return Num::round2($amount);
    }

    public static function deadlineState(string $dueOn, string $today, int $daysBefore = 3): array
    {
        $remaining = Dates::calendarDaysBetween($today, $dueOn);
        if ($remaining < 0) return ['state' => 'overdue', 'days_remaining' => 0, 'days_overdue' => -$remaining];
        if ($remaining === 0) return ['state' => 'due_today', 'days_remaining' => 0, 'days_overdue' => 0];
        if ($remaining <= $daysBefore) return ['state' => 'due_soon', 'days_remaining' => $remaining, 'days_overdue' => 0];
        return ['state' => 'ok', 'days_remaining' => $remaining, 'days_overdue' => 0];
    }

    /** Which reminder (if any) is due today: due:3..0 before / on the day, overdue:1 then every N days. */
    public static function reminderStage(string $dueOn, string $today, array $rem = []): ?array
    {
        $daysBefore = (int) ($rem['days_before'] ?? 3);
        $repeat = (int) ($rem['overdue_repeat_days'] ?? 7);
        $remaining = Dates::calendarDaysBetween($today, $dueOn);
        if ($remaining > $daysBefore) return null;
        if ($remaining >= 0) return ['key' => "due:$remaining", 'kind' => 'due', 'days' => $remaining];
        $overdue = -$remaining;
        if ($overdue === 1 || ($overdue - 1) % $repeat === 0) return ['key' => "overdue:$overdue", 'kind' => 'overdue', 'days' => $overdue];
        return null;
    }
}
