<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * An administrator can cancel an absence permission that was approved by mistake: who cancelled it,
 * when and why are kept on the request (the reason is encrypted like the other free-text reasons).
 * Additive only; existing requests are unchanged.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('permission_requests', 'cancelled_by')) {
            DB::statement('ALTER TABLE permission_requests
                ADD COLUMN cancelled_by int unsigned DEFAULT NULL AFTER review_note,
                ADD COLUMN cancelled_at datetime DEFAULT NULL AFTER cancelled_by,
                ADD COLUMN cancel_reason text DEFAULT NULL AFTER cancelled_at');
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('permission_requests', 'cancelled_by')) {
            DB::statement('ALTER TABLE permission_requests DROP COLUMN cancelled_by, DROP COLUMN cancelled_at, DROP COLUMN cancel_reason');
        }
    }
};
