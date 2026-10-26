<?php

namespace App\Mz\Db;

use App\Mz\Crypto\Seal;
use Illuminate\Database\MySqlConnection;

/**
 * MySQL connection that types DATE / DATETIME / TIMESTAMP columns (see UtcDateTime), so rows
 * serialise to JSON exactly like the Node.js backend's (mysql2 Date objects), and decrypts the
 * values stored encrypted (MZ-Seal, see App\Mz\Crypto) — whatever the column alias or query —
 * while MzBuilder encrypts them on write.
 */
class MzConnection extends MySqlConnection
{
    private static bool $decrypt = true;

    /** Run $fn reading the stored (still encrypted) values — used by mz:encrypt-data. */
    public static function withoutDecryption(callable $fn): mixed
    {
        $prev = self::$decrypt;
        self::$decrypt = false;
        try {
            return $fn();
        } finally {
            self::$decrypt = $prev;
        }
    }

    public function query()
    {
        return new MzBuilder($this, $this->getQueryGrammar(), $this->getPostProcessor());
    }

    /** Open every sealed string of the result rows (a cheap prefix test for the others). */
    private static function openRows(array $rows): array
    {
        foreach ($rows as $i => $row) {
            foreach ($row as $k => $v) {
                if (is_string($v) && str_starts_with($v, Seal::PREFIX)) {
                    if (is_object($row)) {
                        $row->{$k} = Seal::open($v);
                    } else {
                        $rows[$i][$k] = Seal::open($v);
                    }
                }
            }
        }
        return $rows;
    }

    public function select($query, $bindings = [], $useReadPdo = true)
    {
        return $this->run($query, $bindings, function ($query, $bindings) use ($useReadPdo) {
            if ($this->pretending()) {
                return [];
            }
            $statement = $this->prepared($this->getPdoForSelect($useReadPdo)->prepare($query));
            $this->bindValues($statement, $this->prepareBindings($bindings));
            $statement->execute();
            $rows = $statement->fetchAll();
            if (! $rows) {
                return $rows;
            }
            if (self::$decrypt) {
                $rows = self::openRows($rows);
            }
            $typed = [];
            $n = $statement->columnCount();
            for ($i = 0; $i < $n; $i++) {
                $meta = $statement->getColumnMeta($i);
                $t = strtoupper($meta['native_type'] ?? '');
                if (in_array($t, ['DATETIME', 'TIMESTAMP', 'DATE', 'NEWDATE'], true)) {
                    $typed[$meta['name']] = $t === 'DATE' || $t === 'NEWDATE' ? DbDate::class : UtcDateTime::class;
                }
            }
            if (! $typed) {
                return $rows;
            }
            foreach ($rows as $row) {
                foreach ($typed as $col => $cls) {
                    if (is_object($row)) {
                        if (isset($row->{$col}) && is_string($row->{$col}) && ! str_starts_with($row->{$col}, '0000')) {
                            $row->{$col} = $cls::fromDb($row->{$col});
                        }
                    } elseif (isset($row[$col]) && is_string($row[$col]) && ! str_starts_with($row[$col], '0000')) {
                        $row[$col] = $cls::fromDb($row[$col]);
                    }
                }
            }
            return $rows;
        });
    }

}
