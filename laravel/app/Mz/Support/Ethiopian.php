<?php

namespace App\Mz\Support;

/**
 * Ethiopian calendar (Amete Mihret). A payable period is "YYYY-MM" (Ethiopian, months 1–12;
 * ጳጉሜ belongs to ነሐሴ). Port of utils/ethiopian.js.
 */
final class Ethiopian
{
    private const EPOCH = 1723856;

    private static function fdiv(int $a, int $b): int
    {
        return intdiv($a, $b) - (($a % $b !== 0 && (($a < 0) !== ($b < 0))) ? 1 : 0);
    }

    private static function jdnFromGregorian(int $y, int $m, int $d): int
    {
        $a = self::fdiv(14 - $m, 12);
        $yy = $y + 4800 - $a;
        $mm = $m + 12 * $a - 3;
        return $d + self::fdiv(153 * $mm + 2, 5) + 365 * $yy + self::fdiv($yy, 4) - self::fdiv($yy, 100) + self::fdiv($yy, 400) - 32045;
    }

    private static function gregorianFromJdn(int $jdn): array
    {
        $l = $jdn + 68569;
        $n = self::fdiv(4 * $l, 146097);
        $l -= self::fdiv(146097 * $n + 3, 4);
        $i = self::fdiv(4000 * ($l + 1), 1461001);
        $l = $l - self::fdiv(1461 * $i, 4) + 31;
        $j = self::fdiv(80 * $l, 2447);
        $d = $l - self::fdiv(2447 * $j, 80);
        $l = self::fdiv($j, 11);
        $m = $j + 2 - 12 * $l;
        $y = 100 * ($n - 49) + $i + $l;
        return ['year' => $y, 'month' => $m, 'day' => $d];
    }

    /** @return array{year:int,month:int,day:int} */
    public static function toEthiopian(int $y, int $m, int $d): array
    {
        $jdn = self::jdnFromGregorian($y, $m, $d);
        $r = ($jdn - self::EPOCH) % 1461;
        $n = ($r % 365) + 365 * self::fdiv($r, 1460);
        $year = 4 * self::fdiv($jdn - self::EPOCH, 1461) + self::fdiv($r, 365) - self::fdiv($r, 1460);
        return ['year' => $year, 'month' => self::fdiv($n, 30) + 1, 'day' => ($n % 30) + 1];
    }

    public static function fromEthiopian(int $year, int $month, int $day): string
    {
        $jdn = self::EPOCH + 1461 * self::fdiv($year, 4) + 365 * ($year % 4) + 30 * ($month - 1) + $day - 1;
        $g = self::gregorianFromJdn($jdn);
        return sprintf('%04d-%02d-%02d', $g['year'], $g['month'], $g['day']);
    }

    public static function isLeapYear(int $year): bool
    {
        return $year % 4 === 3;
    }

    public static function daysInMonth(int $year, int $month): int
    {
        return $month < 13 ? 30 : (self::isLeapYear($year) ? 6 : 5);
    }

    public static function period(int $year, int $month): string
    {
        return sprintf('%d-%02d', $year, $month);
    }

    public static function parsePeriod(string $p): array
    {
        [$y, $m] = array_map('intval', explode('-', $p));
        return ['year' => $y, 'month' => $m];
    }

    public static function ethiopianOfDate(string $date): array
    {
        [$y, $m, $d] = array_map('intval', explode('-', substr($date, 0, 10)));
        return self::toEthiopian($y, $m, $d);
    }

    public static function periodOfDate(string $date): string
    {
        $e = self::ethiopianOfDate($date);
        return $e['month'] === 13 ? self::period($e['year'], 12) : self::period($e['year'], $e['month']);
    }

    public static function currentPeriod(?\DateTimeInterface $now = null): string
    {
        return self::periodOfDate(Dates::todayLocal($now));
    }

    public static function addMonths(string $p, int $n): string
    {
        ['year' => $y, 'month' => $m] = self::parsePeriod($p);
        $idx = $y * 12 + ($m - 1) + $n;
        return self::period(self::fdiv($idx, 12), (($idx % 12) + 12) % 12 + 1);
    }

    public static function monthCount(string $a, string $b): int
    {
        $x = self::parsePeriod($a);
        $y = self::parsePeriod($b);
        return max(0, ($y['year'] - $x['year']) * 12 + ($y['month'] - $x['month']) + 1);
    }

    public static function monthsBetween(string $from, string $to, int $max = 240): array
    {
        $out = [];
        for ($p = $from; strcmp($p, $to) <= 0 && count($out) < $max; $p = self::addMonths($p, 1)) {
            $out[] = $p;
        }
        return $out;
    }

    /** @return array{start:string,end:string} */
    public static function periodRange(string $p): array
    {
        ['year' => $y, 'month' => $m] = self::parsePeriod($p);
        $start = self::fromEthiopian($y, $m, 1);
        $end = $m === 12 ? self::fromEthiopian($y, 13, self::daysInMonth($y, 13)) : self::fromEthiopian($y, $m, 30);
        return ['start' => $start, 'end' => $end];
    }

    public static function periodOfGregorianMonth(string $gp): string
    {
        return self::periodOfDate("$gp-15");
    }
}
