<?php

namespace App\Mz\Db;

use App\Mz\Crypto\EncryptedColumns;
use Illuminate\Database\Query\Builder;
use Illuminate\Database\Query\Expression;

/**
 * Query builder that encrypts the columns listed in EncryptedColumns before they are written
 * (insert / insertGetId / insertOrIgnore / update / upsert, and everything built on them such as
 * updateOrInsert and increment-with-extra). Reads are decrypted in MzConnection::select.
 */
class MzBuilder extends Builder
{
    /** [table, alias] of the FROM clause. */
    private function target(): array
    {
        if (! is_string($this->from)) return [null, null];
        $parts = preg_split('/\s+as\s+/i', trim($this->from));
        $table = trim($parts[0], '` ');
        if (str_contains($table, '.')) $table = substr($table, strrpos($table, '.') + 1);
        return [$table, isset($parts[1]) ? trim($parts[1], '` ') : null];
    }

    private function sealValues(array $values): array
    {
        [$table, $alias] = $this->target();
        if ($table === null || ! EncryptedColumns::for($table)) return $values;
        // "alias.column" / "table.column" keys (updates with joins) → plain column names.
        $plain = [];
        $qualified = [];
        foreach ($values as $k => $v) {
            if (is_string($k) && str_contains($k, '.')) {
                [$q, $c] = explode('.', $k, 2);
                if ($q === $table || $q === $alias) {
                    $qualified[$c] = $k;
                    $plain[$c] = $v;
                    continue;
                }
            }
            $plain[$k] = $v;
        }
        $sealed = EncryptedColumns::sealRow($table, $plain);
        $out = [];
        foreach ($sealed as $k => $v) $out[$qualified[$k] ?? $k] = $v;
        return $out;
    }

    private function sealRows(array $values): array
    {
        if ($values === []) return $values;
        if (! is_array(reset($values))) return $this->sealValues($values);
        return array_map(fn ($row) => $this->sealValues($row), $values);
    }

    public function insert(array $values)
    {
        return parent::insert($this->sealRows($values));
    }

    public function insertOrIgnore(array $values)
    {
        return parent::insertOrIgnore($this->sealRows($values));
    }

    public function insertGetId(array $values, $sequence = null)
    {
        return parent::insertGetId($this->sealValues($values), $sequence);
    }

    public function update(array $values)
    {
        return parent::update($this->sealValues($values));
    }

    public function upsert(array $values, array|string $uniqueBy, ?array $update = null)
    {
        if ($update !== null) {
            // Only the "column => value" entries carry values; plain names reuse the inserted value.
            $assoc = array_filter($update, fn ($v, $k) => is_string($k) && ! $v instanceof Expression, ARRAY_FILTER_USE_BOTH);
            if ($assoc) $update = array_replace($update, $this->sealValues($assoc));
        }
        return parent::upsert($this->sealRows($values), $uniqueBy, $update);
    }
}
