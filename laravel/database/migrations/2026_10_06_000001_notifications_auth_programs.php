<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Stage after the Node.js port (Laravel only from here on):
 *  - job_runs: last run of each background job, in the database (the request-driven ticker no
 *    longer depends on the cache store, which silently broke every job when the cache table was missing);
 *  - scheduled_notifications: notifications due at a given time (task deadlines…), delivered by one
 *    central job — no cron entry and no process per reminder;
 *  - notifications.type gains 'chat' and 'project';
 *  - user_permission_revocations: a permission taken away from one administrator even though their
 *    role grants it (the system authority can now reverse a role permission for one person);
 *  - programs: optional end time, per-program on-time / late attendance window, reminder offsets
 *    (2 days / 1 day / 6 hours / 1 hour before); program_reminder_choices: a member's own choice.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('job_runs')) {
            DB::statement("CREATE TABLE job_runs (
                name varchar(64) NOT NULL PRIMARY KEY,
                last_run_at datetime DEFAULT NULL,
                last_day date DEFAULT NULL,
                last_result varchar(2000) DEFAULT NULL,
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        if (! Schema::hasTable('scheduled_notifications')) {
            DB::statement("CREATE TABLE scheduled_notifications (
                id bigint unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                due_at datetime NOT NULL,
                type varchar(40) NOT NULL,
                title varchar(255) NOT NULL,
                body varchar(2000) NOT NULL,
                entity_type varchar(40) DEFAULT NULL,
                entity_id int unsigned DEFAULT NULL,
                data longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
                source_type varchar(40) NOT NULL,
                source_id int unsigned NOT NULL,
                dedupe_key varchar(150) NOT NULL,
                status enum('pending','sent','cancelled') NOT NULL DEFAULT 'pending',
                sent_at datetime DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                UNIQUE KEY scheduled_notifications_dedupe_unique (dedupe_key),
                KEY scheduled_notifications_due_index (status, due_at),
                KEY scheduled_notifications_source_index (source_type, source_id, status),
                CONSTRAINT scheduled_notifications_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        DB::statement("ALTER TABLE notifications MODIFY type enum('admin_message','announcement','program','program_reminder','borrowing','borrowing_due','borrowing_overdue','attendance','advertisement','mezmur','system','education','payment','choir','chat','project') NOT NULL");

        if (! Schema::hasTable('user_permission_revocations')) {
            DB::statement("CREATE TABLE user_permission_revocations (
                user_id int unsigned NOT NULL,
                permission_id int unsigned NOT NULL,
                revoked_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                PRIMARY KEY (user_id, permission_id),
                CONSTRAINT upr_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT upr_permission_fk FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE CASCADE,
                CONSTRAINT upr_revoked_by_fk FOREIGN KEY (revoked_by) REFERENCES users (id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        if (! Schema::hasColumn('programs', 'has_end_time')) {
            DB::statement('ALTER TABLE programs
                ADD COLUMN has_end_time tinyint(1) NOT NULL DEFAULT 1 AFTER ends_at,
                ADD COLUMN on_time_minutes smallint unsigned DEFAULT NULL,
                ADD COLUMN late_minutes smallint unsigned DEFAULT NULL,
                ADD COLUMN reminder_offsets varchar(60) DEFAULT NULL');
            // Existing programs keep their "N days before" reminder as the equivalent offset.
            DB::statement("UPDATE programs SET reminder_offsets = CASE WHEN reminder_days_before = 0 THEN '60' WHEN reminder_days_before >= 2 THEN '2880,60' ELSE '1440,60' END");
        }

        if (! Schema::hasTable('program_reminder_choices')) {
            DB::statement("CREATE TABLE program_reminder_choices (
                user_id int unsigned NOT NULL,
                program_id int unsigned NOT NULL,
                offsets varchar(60) NOT NULL DEFAULT '',
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                PRIMARY KEY (user_id, program_id),
                CONSTRAINT prc_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT prc_program_fk FOREIGN KEY (program_id) REFERENCES programs (id) ON DELETE CASCADE
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        DB::table('settings')->where('key', 'programs.reminder_defaults')->update([
            'value' => json_encode(['enabled' => true, 'days_before' => 1, 'offsets' => [1440, 60], 'minutes_before' => 0]),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('program_reminder_choices');
        Schema::dropIfExists('user_permission_revocations');
        Schema::dropIfExists('scheduled_notifications');
        Schema::dropIfExists('job_runs');
        if (Schema::hasColumn('programs', 'has_end_time')) {
            DB::statement('ALTER TABLE programs DROP COLUMN has_end_time, DROP COLUMN on_time_minutes, DROP COLUMN late_minutes, DROP COLUMN reminder_offsets');
        }
    }
};
