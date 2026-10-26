<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Reminders by program type and recurring reminders every N days (15 by policy):
 *  - program_categories (the program type): default reminder offsets and repeat interval that new
 *    programs of that type start with (null = the general defaults);
 *  - programs.reminder_interval_days / reminder_interval_start: remind the program's audience every
 *    N calendar days from the start date while the program is published and not over;
 *    reminder_interval_last_at records the last cycle that was sent.
 *  - the `programs.reminders_enforce` permission the program code already checks for mandatory
 *    reminders (it was missing from the permission list, so it could not be granted).
 * Additive only; existing programs keep their reminders unchanged (no interval).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('program_categories', 'reminder_offsets')) {
            DB::statement('ALTER TABLE program_categories
                ADD COLUMN reminder_offsets varchar(60) DEFAULT NULL AFTER color,
                ADD COLUMN reminder_interval_days smallint unsigned DEFAULT NULL AFTER reminder_offsets');
        }
        if (! Schema::hasColumn('programs', 'reminder_interval_days')) {
            DB::statement('ALTER TABLE programs
                ADD COLUMN reminder_interval_days smallint unsigned DEFAULT NULL AFTER reminder_offsets,
                ADD COLUMN reminder_interval_start date DEFAULT NULL AFTER reminder_interval_days,
                ADD COLUMN reminder_interval_last_at datetime DEFAULT NULL AFTER reminder_interval_start');
        }
        DB::table('permissions')->insertOrIgnore(['key' => 'programs.reminders_enforce', 'group_key' => 'programs', 'description' => 'Make a program\'s reminders mandatory for its members']);
    }

    public function down(): void
    {
        if (Schema::hasColumn('programs', 'reminder_interval_days')) {
            DB::statement('ALTER TABLE programs DROP COLUMN reminder_interval_days, DROP COLUMN reminder_interval_start, DROP COLUMN reminder_interval_last_at');
        }
        if (Schema::hasColumn('program_categories', 'reminder_offsets')) {
            DB::statement('ALTER TABLE program_categories DROP COLUMN reminder_offsets, DROP COLUMN reminder_interval_days');
        }
        // The permission row is kept: grants made with it must not silently disappear.
    }
};
