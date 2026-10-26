<?php

namespace App\Mz\Support;

/** JavaScript-compatible number helpers (Math.round rounds .5 towards +∞). */
final class Num
{
    public static function jsRound(float|int $x): int|float
    {
        $r = floor($x + 0.5);
        return abs($r) < 9007199254740992 ? (int) $r : $r;
    }

    /** Math.round(x * 10) / 10 */
    public static function round1(float|int $x): int|float
    {
        return self::clean(floor($x * 10 + 0.5) / 10);
    }

    /** Math.round(x * 100) / 100 */
    public static function round2(float|int $x): int|float
    {
        return self::clean(floor($x * 100 + 0.5) / 100);
    }

    /** 5.0 → 5 (as JSON.stringify would print it). */
    public static function clean(float|int|null $x): int|float|null
    {
        if ($x === null) {
            return null;
        }
        return is_float($x) && floor($x) == $x && abs($x) < 9007199254740992 ? (int) $x : $x;
    }

    /** Number(v) for DECIMAL / SUM strings. */
    public static function n(mixed $v): int|float
    {
        if ($v === null) {
            return 0;
        }
        return self::clean(is_numeric($v) ? $v + 0 : 0);
    }
}
