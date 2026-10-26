<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Course schedules beyond "every week" and course completion (no false absences):
 *  - edu_schedule.frequency weekly | monthly (+ week_of_month 1–4, 5 = last, counted in the
 *    Ethiopian month): 2 or 4 days a week = 2 or 4 weekly rows; 1 day a month = one monthly row;
 *    distance learning 1–2 days a month = monthly rows for the distance program.
 *  - edu_schedule.program all | regular | distance: whose day it is; edu_schedule.mode in_person | online.
 *  - edu_courses.progress (0–100) and completed_at: after completion no more sessions are expected.
 * Existing rows keep their meaning (weekly, for everyone, in person; courses not completed).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('edu_schedule', 'frequency')) {
            DB::statement("ALTER TABLE edu_schedule
                ADD COLUMN frequency enum('weekly','monthly') NOT NULL DEFAULT 'weekly' AFTER weekday,
                ADD COLUMN week_of_month tinyint unsigned DEFAULT NULL AFTER frequency,
                ADD COLUMN program enum('all','regular','distance') NOT NULL DEFAULT 'all' AFTER week_of_month,
                ADD COLUMN mode enum('in_person','online') NOT NULL DEFAULT 'in_person' AFTER program");
        }
        if (! Schema::hasColumn('edu_courses', 'progress')) {
            DB::statement('ALTER TABLE edu_courses
                ADD COLUMN progress tinyint unsigned NOT NULL DEFAULT 0 AFTER teacher_user_id,
                ADD COLUMN completed_at date DEFAULT NULL AFTER progress');
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('edu_schedule', 'frequency')) DB::statement('ALTER TABLE edu_schedule DROP COLUMN frequency, DROP COLUMN week_of_month, DROP COLUMN program, DROP COLUMN mode');
        if (Schema::hasColumn('edu_courses', 'progress')) DB::statement('ALTER TABLE edu_courses DROP COLUMN progress, DROP COLUMN completed_at');
    }
};
