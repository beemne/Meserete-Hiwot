<?php

use Illuminate\Database\Migrations\Migration;

/**
 * Formerly re-seeded untouched department-criteria drafts. The department criteria were withdrawn
 * (2026-10-15), so this migration does nothing; the file stays so the migration history is intact.
 */
return new class extends Migration
{
    public function up(): void
    {
    }

    public function down(): void
    {
    }
};
