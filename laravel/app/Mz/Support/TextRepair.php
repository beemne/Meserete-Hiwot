<?php

namespace App\Mz\Support;

use App\Mz\Crypto\EncryptedColumns;
use Illuminate\Support\Facades\DB;

/**
 * Restores text that a latin1 table turned into "?" (Amharic saved into `items` / `borrowings`
 * before they were utf8mb4) from the original rows of a mysqldump / phpMyAdmin dump. A value is
 * only replaced when, for the same row id, the database holds nothing but "?" and spaces where the
 * dump holds real (non-ASCII) text. Encrypted columns are never touched.
 */
final class TextRepair
{
    /** @return array<int, array<string, mixed>> id => row, from every INSERT INTO `$table` of the dump */
    public static function dumpRows(string $sql, string $table): array
    {
        $rows = [];
        if (! preg_match_all('/INSERT INTO `' . preg_quote($table, '/') . '` \(([^)]*)\) VALUES\s*/', $sql, $m, PREG_OFFSET_CAPTURE)) return $rows;
        foreach ($m[0] as $i => [$head, $pos]) {
            $cols = array_map(fn ($c) => trim($c, " `"), explode(',', $m[1][$i][0]));
            $offset = $pos + strlen($head);
            foreach (self::tuples($sql, $offset) as $values) {
                if (count($values) !== count($cols)) continue;
                $row = array_combine($cols, $values);
                if (isset($row['id'])) $rows[(int) $row['id']] = $row;
            }
        }
        return $rows;
    }

    /** The value tuples of one INSERT, starting at $i, up to its terminating ";". */
    private static function tuples(string $s, int $i): \Generator
    {
        $n = strlen($s);
        while ($i < $n) {
            while ($i < $n && ctype_space($s[$i])) $i++;
            if ($i >= $n || $s[$i] === ';') return;
            if ($s[$i] === ',') {
                $i++;
                continue;
            }
            if ($s[$i] !== '(') return;
            $i++;
            $values = [];
            while ($i < $n) {
                while ($i < $n && ctype_space($s[$i])) $i++;
                if ($s[$i] === "'") {
                    $i++;
                    $v = '';
                    while ($i < $n) {
                        $c = $s[$i];
                        if ($c === '\\') {
                            $next = $s[$i + 1] ?? '';
                            $v .= match ($next) { 'n' => "\n", 'r' => "\r", 't' => "\t", '0' => "\0", default => $next };
                            $i += 2;
                        } elseif ($c === "'" && ($s[$i + 1] ?? '') === "'") {
                            $v .= "'";
                            $i += 2;
                        } elseif ($c === "'") {
                            $i++;
                            break;
                        } else {
                            $v .= $c;
                            $i++;
                        }
                    }
                    $values[] = $v;
                } else {
                    $start = $i;
                    while ($i < $n && $s[$i] !== ',' && $s[$i] !== ')') $i++;
                    $raw = trim(substr($s, $start, $i - $start));
                    $values[] = strtoupper($raw) === 'NULL' ? null : $raw;
                }
                while ($i < $n && ctype_space($s[$i])) $i++;
                if ($s[$i] === ',') {
                    $i++;
                    continue;
                }
                if ($s[$i] === ')') {
                    $i++;
                    break;
                }
            }
            yield $values;
        }
    }

    private static function isQuestionMarks(mixed $v): bool
    {
        return is_string($v) && $v !== '' && preg_match('/^[?\s]+$/', $v) === 1 && str_contains($v, '?');
    }

    /** @return array<int, array{id:int, column:string, now:string, restored:string}> what was (or would be) restored */
    public static function repair(string $sql, string $table, bool $dryRun): array
    {
        $encrypted = EncryptedColumns::MAP[$table] ?? [];
        $changes = [];
        foreach (self::dumpRows($sql, $table) as $id => $orig) {
            $current = DB::table($table)->where('id', $id)->first();
            if (! $current) continue;
            $patch = [];
            foreach ($orig as $col => $value) {
                if (in_array($col, $encrypted, true) || ! property_exists($current, $col)) continue;
                if (self::isQuestionMarks($current->{$col}) && is_string($value) && preg_match('/[^\x00-\x7F]/', $value)) {
                    $patch[$col] = $value;
                    $changes[] = ['id' => $id, 'column' => $col, 'now' => $current->{$col}, 'restored' => $value];
                }
            }
            if ($patch && ! $dryRun) DB::table($table)->where('id', $id)->update($patch);
        }
        return $changes;
    }
}
