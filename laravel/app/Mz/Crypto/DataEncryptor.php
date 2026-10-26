<?php

namespace App\Mz\Crypto;

use App\Mz\Db\MzConnection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;

/**
 * Bulk work on the stored values of the encrypted columns (php artisan mz:encrypt-data):
 *  - encrypt: seal the values still stored as plain text (existing data, rows written while the
 *    encryption was off). Safe to run again: sealed values are skipped.
 *  - decrypt: store every value as plain text again (to remove the encryption; DATA_ENCRYPTION=false
 *    must be set first, or new writes would be encrypted again).
 *  - rotate: re-encrypt values sealed with an older key (DATA_ENCRYPTION_OLD_KEYS) with the current one.
 * Rows are walked in primary-key order, in batches, each value written on its own (no long locks).
 */
final class DataEncryptor
{
    public const MODES = ['encrypt', 'decrypt', 'rotate'];

    /**
     * @param string[] $only tables to limit the run to (empty = all)
     * @return array<int, array{table:string,column:string,count:int}>
     */
    public static function run(string $mode, array $only = [], int $chunk = 500, bool $dryRun = false, ?callable $progress = null): array
    {
        if (! in_array($mode, self::MODES, true)) throw new RuntimeException("Unknown mode $mode");
        if ($mode === 'decrypt' && Seal::enabled() && ! $dryRun) {
            throw new RuntimeException('Set DATA_ENCRYPTION=false (and clear the config cache) before decrypting, or new writes are encrypted again.');
        }
        $unknown = array_diff($only, array_keys(EncryptedColumns::MAP));
        if ($unknown) throw new RuntimeException('Not an encrypted table: ' . implode(', ', $unknown));
        $report = [];
        foreach (EncryptedColumns::MAP as $table => $cols) {
            if ($only && ! in_array($table, $only, true)) continue;
            if (! Schema::hasTable($table)) continue;
            $pk = EncryptedColumns::KEYS[$table] ?? ['id'];
            foreach ($cols as $col) {
                if (! Schema::hasColumn($table, $col)) continue;
                $n = self::column($mode, $table, $col, $pk, max(1, $chunk), $dryRun);
                $report[] = ['table' => $table, 'column' => $col, 'count' => $n];
                if ($progress) $progress($table, $col, $n);
            }
        }
        return $report;
    }

    private static function column(string $mode, string $table, string $col, array $pk, int $chunk, bool $dryRun): int
    {
        $done = 0;
        $after = null;
        while (true) {
            $rows = MzConnection::withoutDecryption(function () use ($mode, $table, $col, $pk, $chunk, $after) {
                $q = DB::table($table)->select(array_merge($pk, [$col]))->whereNotNull($col)->where($col, '<>', '');
                $mode === 'encrypt' ? $q->where($col, 'not like', Seal::PREFIX . '%') : $q->where($col, 'like', Seal::PREFIX . '%');
                if ($after !== null) {
                    $q->whereRaw('(' . implode(', ', array_map(fn ($c) => "`$c`", $pk)) . ') > (' . implode(', ', array_fill(0, count($pk), '?')) . ')', $after);
                }
                foreach ($pk as $c) $q->orderBy($c);
                return $q->limit($chunk)->get();
            });
            if ($rows->isEmpty()) break;
            foreach ($rows as $r) {
                $stored = (string) $r->{$col};
                $new = match ($mode) {
                    'encrypt' => Seal::seal($stored),
                    'decrypt' => Seal::canOpen($stored) ? Seal::open($stored) : null,
                    'rotate' => Seal::canOpen($stored) && Seal::isStale($stored) ? Seal::seal(Seal::open($stored)) : null,
                };
                if ($new === null) continue;
                $done++;
                if ($dryRun) continue;
                // Written as given (raw statement): the builder must not seal a decrypted value again.
                $where = implode(' AND ', array_map(fn ($c) => "`$c` = ?", $pk));
                DB::update("UPDATE `$table` SET `$col` = ? WHERE $where", array_merge([$new], array_map(fn ($c) => $r->{$c}, $pk)));
            }
            $last = $rows->last();
            $after = array_map(fn ($c) => $last->{$c}, $pk);
        }
        return $done;
    }
}
