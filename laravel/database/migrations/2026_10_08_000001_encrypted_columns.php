<?php

use App\Mz\Crypto\EncryptedColumns;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * At-rest encryption (MZ-Seal): an encrypted value is longer than its text (base64 + 32 bytes of
 * key id / nonce / tag), so the encrypted columns are widened — VARCHAR → TEXT, TEXT → MEDIUMTEXT.
 * NULL / NOT NULL is kept. Existing rows stay readable as they are; encrypt them with
 * `php artisan mz:encrypt-data` (new and changed rows are encrypted automatically).
 */
return new class extends Migration
{
    public function up(): void
    {
        $db = DB::getDatabaseName();
        foreach (EncryptedColumns::MAP as $table => $cols) {
            if (! Schema::hasTable($table)) continue;
            $info = DB::table('information_schema.columns')->where('table_schema', $db)->where('table_name', $table)->whereIn('column_name', $cols)
                ->get(['column_name as name', 'data_type as type', 'is_nullable as nullable']);
            $changes = [];
            foreach ($info as $c) {
                $type = match (strtolower($c->type)) {
                    'varchar', 'char', 'tinytext' => 'TEXT',
                    'text' => 'MEDIUMTEXT',
                    default => null, // mediumtext / longtext are wide enough
                };
                if ($type) $changes[] = "MODIFY `{$c->name}` $type " . ($c->nullable === 'YES' ? 'NULL' : 'NOT NULL');
            }
            if ($changes) DB::statement("ALTER TABLE `$table` " . implode(', ', $changes));
        }
    }

    public function down(): void
    {
        // Not narrowed back: encrypted values (or long texts) would no longer fit. Decrypt first with
        // `php artisan mz:encrypt-data --decrypt` if the encryption is to be removed.
    }
};
