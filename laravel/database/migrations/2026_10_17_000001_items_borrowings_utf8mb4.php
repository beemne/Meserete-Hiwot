<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * `items` and `borrowings` were created by the imported dump WITHOUT a character set, so on a
 * server whose default is latin1 they could not store Amharic: every Ge'ez letter was saved as "?"
 * (the Items screen showed ?????). Both tables are converted to utf8mb4 like every other table.
 * Values already saved as "?" cannot be recovered by the conversion — restore them from the dump
 * with `php artisan mz:repair-text <dump.sql>` (or re-enter them). Nothing happens when the tables
 * are already utf8mb4.
 */
return new class extends Migration
{
    private const TABLES = ['items', 'borrowings'];

    private function needsConversion(string $table): bool
    {
        $tableCharset = DB::selectOne('SELECT c.character_set_name AS cs FROM information_schema.TABLES t
            JOIN information_schema.COLLATION_CHARACTER_SET_APPLICABILITY c ON c.collation_name = t.table_collation
            WHERE t.table_schema = DATABASE() AND t.table_name = ?', [$table]);
        $columns = DB::selectOne("SELECT COUNT(*) AS n FROM information_schema.COLUMNS
            WHERE table_schema = DATABASE() AND table_name = ? AND character_set_name IS NOT NULL AND character_set_name <> 'utf8mb4'", [$table]);
        return ($tableCharset?->cs ?? 'utf8mb4') !== 'utf8mb4' || (int) $columns->n > 0;
    }

    public function up(): void
    {
        foreach (self::TABLES as $table) {
            if ($this->needsConversion($table)) DB::statement("ALTER TABLE `$table` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci");
        }
    }

    public function down(): void
    {
        // Converting back to latin1 would destroy Amharic text again: intentionally nothing.
    }
};
