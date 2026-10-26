<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Profile edit requests and history; promotion; synced lyrics; holiday-selection attendance points.
 *  - profile_change_requests: a member asks for any membership-form change (not only name / phone);
 *    `changes` holds {field: {old, new}} (encrypted), `note` the member's message.
 *  - profile_change_history: every applied change of a member's details, field by field, with the
 *    old and the new value (encrypted), who made it and how (approved request / administrator edit).
 *    Rows are only ever added: earlier values are never lost.
 *  - mezmurs.lrc: time-synced lyrics (.lrc text) shown with the audio.
 *  - revoked_access_tokens: an access token signed out of stops working at once (not at expiry).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('profile_change_requests', 'changes')) {
            DB::statement('ALTER TABLE profile_change_requests
                MODIFY old_phone varchar(20) DEFAULT NULL,
                ADD COLUMN changes MEDIUMTEXT DEFAULT NULL AFTER phone,
                ADD COLUMN note TEXT DEFAULT NULL AFTER changes,
                MODIFY reason TEXT DEFAULT NULL');
        }
        if (! Schema::hasTable('profile_change_history')) {
            DB::statement("CREATE TABLE profile_change_history (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                field varchar(60) NOT NULL,
                old_value MEDIUMTEXT DEFAULT NULL,
                new_value MEDIUMTEXT DEFAULT NULL,
                source enum('request','admin','self') NOT NULL,
                request_id int unsigned DEFAULT NULL,
                changed_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY pch_user (user_id, created_at),
                CONSTRAINT pch_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pch_request_fk FOREIGN KEY (request_id) REFERENCES profile_change_requests (id) ON DELETE SET NULL,
                CONSTRAINT pch_actor_fk FOREIGN KEY (changed_by) REFERENCES users (id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }
        if (! Schema::hasColumn('mezmurs', 'lrc')) {
            DB::statement('ALTER TABLE mezmurs ADD COLUMN lrc MEDIUMTEXT DEFAULT NULL AFTER lyrics');
        }
        if (! Schema::hasTable('revoked_access_tokens')) {
            DB::statement("CREATE TABLE revoked_access_tokens (
                jti char(36) NOT NULL PRIMARY KEY,
                user_id int unsigned DEFAULT NULL,
                expires_at datetime NOT NULL,
                KEY rat_expires (expires_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('revoked_access_tokens');
        Schema::dropIfExists('profile_change_history');
        if (Schema::hasColumn('profile_change_requests', 'changes')) {
            DB::statement('ALTER TABLE profile_change_requests DROP COLUMN changes, DROP COLUMN note');
        }
        if (Schema::hasColumn('mezmurs', 'lrc')) DB::statement('ALTER TABLE mezmurs DROP COLUMN lrc');
    }
};
