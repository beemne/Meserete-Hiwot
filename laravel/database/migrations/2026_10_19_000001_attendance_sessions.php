<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Attendance sessions (one per program occurrence), signatures, exact capture times and offline
 * reconciliation. Additive only — existing attendance rows, closures and corrections are kept as
 * they are (rows recorded before sessions existed have no session_id and stay "legacy"):
 *  - attendance_sessions: exactly one row per (program, occurrence date) — UNIQUE — with ONE taker,
 *    the official start (server time; or the phone's time, adjusted, for a session started offline),
 *    the end (taker / scheduled end / HR) and status;
 *  - attendance: session_id, the real capture time (attended_at stays the capture time), the
 *    phone's raw time, seconds since the official start, where the time came from, the signature,
 *    online/offline origin and the client event id (UNIQUE: a replayed event is never a 2nd row);
 *  - attendance_signatures: the member's signature for a present mark (private file);
 *  - attendance_sync_conflicts: offline work the server could not apply as sent — kept (with its
 *    signature) for an auditable HR decision, never dropped;
 *  - program_attendance_takers: at most one (default) taker per program from now on;
 *  - permissions: attendance.assign; HR roles (dept_hr, hr_manager) receive the attendance
 *    permissions; dept_info's attendance control permissions and mezmur_lead's attendance.configure
 *    are removed only after the HR grants are verified (snapshot kept for down()).
 * The late window (programs.on_time_minutes / late_minutes, setting attendance.rules) is no longer
 * used; the columns and the setting are kept for history.
 */
return new class extends Migration
{
    private const HR_ROLES = ['dept_hr', 'hr_manager'];
    private const HR_PERMS = ['attendance.manage', 'attendance.view', 'attendance.close', 'attendance.configure', 'attendance.assign', 'attendance.correction.approve', 'attendance.override', 'attendance.reports'];
    /** Control permissions that move to HR (left with the general admin / high_admin roles). */
    private const REVOKE = [
        'dept_info' => ['attendance.manage', 'attendance.close', 'attendance.configure', 'attendance.assign', 'attendance.correction.approve', 'attendance.override'],
        'mezmur_lead' => ['attendance.configure'],
    ];
    private const SNAPSHOT_KEY = 'migration.attendance_sessions.revoked';

    public function up(): void
    {
        $t = 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci';

        if (! Schema::hasTable('attendance_sessions')) {
            DB::statement("CREATE TABLE attendance_sessions (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                program_id int unsigned NOT NULL,
                occurrence_date date NOT NULL,
                taker_id int unsigned DEFAULT NULL,
                assigned_by int unsigned DEFAULT NULL,
                assigned_at datetime DEFAULT NULL,
                status enum('scheduled','active','ended','cancelled') NOT NULL DEFAULT 'scheduled',
                started_at datetime DEFAULT NULL,
                started_by int unsigned DEFAULT NULL,
                start_source enum('server','offline') DEFAULT NULL,
                client_started_at datetime DEFAULT NULL,
                client_uuid char(36) DEFAULT NULL,
                ended_at datetime DEFAULT NULL,
                ended_by int unsigned DEFAULT NULL,
                end_reason enum('taker','scheduled_end','hr') DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY attendance_sessions_occurrence (program_id, occurrence_date),
                UNIQUE KEY attendance_sessions_client (client_uuid),
                KEY attendance_sessions_taker (taker_id, status),
                CONSTRAINT attendance_sessions_program_fk FOREIGN KEY (program_id) REFERENCES programs (id) ON DELETE CASCADE,
                CONSTRAINT attendance_sessions_taker_fk FOREIGN KEY (taker_id) REFERENCES users (id) ON DELETE SET NULL
            ) $t");
        }

        if (! Schema::hasColumn('attendance', 'session_id')) {
            DB::statement("ALTER TABLE attendance
                ADD COLUMN session_id int unsigned DEFAULT NULL AFTER occurrence_date,
                ADD COLUMN client_captured_at datetime DEFAULT NULL AFTER attended_at,
                ADD COLUMN received_at datetime DEFAULT NULL AFTER client_captured_at,
                ADD COLUMN elapsed_seconds int DEFAULT NULL AFTER received_at,
                ADD COLUMN time_source enum('server','device','correction') DEFAULT NULL AFTER elapsed_seconds,
                ADD COLUMN signature_id int unsigned DEFAULT NULL AFTER via,
                ADD COLUMN signature_exempt tinyint(1) NOT NULL DEFAULT 0 AFTER signature_id,
                ADD COLUMN source enum('online','offline') DEFAULT NULL AFTER signature_exempt,
                ADD COLUMN client_event_id char(36) DEFAULT NULL AFTER source,
                ADD UNIQUE KEY attendance_client_event (client_event_id),
                ADD KEY attendance_session (session_id)");
        }

        if (! Schema::hasTable('attendance_signatures')) {
            DB::statement("CREATE TABLE attendance_signatures (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                attendance_id bigint unsigned DEFAULT NULL,
                user_id int unsigned NOT NULL,
                path varchar(255) NOT NULL,
                sha256 char(64) NOT NULL,
                signed_at datetime NOT NULL,
                captured_by int unsigned DEFAULT NULL,
                client_event_id char(36) DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY attendance_signatures_attendance (attendance_id),
                KEY attendance_signatures_event (client_event_id)
            ) $t");
        }

        if (! Schema::hasTable('attendance_sync_conflicts')) {
            DB::statement("CREATE TABLE attendance_sync_conflicts (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                kind enum('record','session_start','session_end') NOT NULL,
                code varchar(60) NOT NULL,
                program_id int unsigned NOT NULL,
                occurrence_date date NOT NULL,
                user_id int unsigned DEFAULT NULL,
                submitted_by int unsigned NOT NULL,
                client_event_id char(36) DEFAULT NULL,
                client_captured_at datetime DEFAULT NULL,
                captured_at datetime DEFAULT NULL,
                payload longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(payload)),
                signature_path varchar(255) DEFAULT NULL,
                signature_sha256 char(64) DEFAULT NULL,
                status enum('open','accepted','rejected') NOT NULL DEFAULT 'open',
                resolved_by int unsigned DEFAULT NULL,
                resolved_at datetime DEFAULT NULL,
                resolution_note varchar(1000) DEFAULT NULL,
                attendance_id bigint unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY attendance_sync_conflicts_event (client_event_id),
                KEY attendance_sync_conflicts_status (status, created_at),
                KEY attendance_sync_conflicts_occurrence (program_id, occurrence_date)
            ) $t");
        }

        // A correction to "present" may state when the member actually arrived (for elapsed-time scoring).
        if (! Schema::hasColumn('attendance_corrections', 'requested_attended_at')) {
            DB::statement('ALTER TABLE attendance_corrections ADD COLUMN requested_attended_at datetime DEFAULT NULL AFTER requested_status');
        }

        // One default taker per program (live data has at most one; never delete extra rows here).
        $dupes = DB::table('program_attendance_takers')->select('program_id')->groupBy('program_id')->havingRaw('COUNT(*) > 1')->count();
        $hasUnique = collect(DB::select("SHOW INDEX FROM program_attendance_takers WHERE Key_name = 'pat_one_taker'"))->isNotEmpty();
        if (! $dupes && ! $hasUnique) DB::statement('ALTER TABLE program_attendance_takers ADD UNIQUE KEY pat_one_taker (program_id)');

        // ---- permissions: HR controls attendance ----
        DB::table('permissions')->insertOrIgnore(['key' => 'attendance.assign', 'group_key' => 'programs', 'description' => 'Assign the one attendance taker of each program occurrence (HR)']);
        DB::table('permissions')->where('key', 'attendance.configure')->update(['description' => 'Configure attendance (signature rules, sessions) — HR']);
        $permIds = DB::table('permissions')->whereIn('key', self::HR_PERMS)->pluck('id', 'key')->all();
        $hrRoles = DB::table('roles')->whereIn('slug', self::HR_ROLES)->pluck('id', 'slug')->all();
        foreach ($hrRoles as $roleId) {
            foreach ($permIds as $pid) DB::table('role_permissions')->insertOrIgnore(['role_id' => $roleId, 'permission_id' => $pid]);
        }
        // Verify before taking anything away: at least one HR role now holds every HR permission.
        $verified = false;
        foreach ($hrRoles as $roleId) {
            $held = DB::table('role_permissions')->where('role_id', $roleId)->whereIn('permission_id', array_values($permIds))->count();
            if ($held === count($permIds)) $verified = true;
        }
        if ($verified && ! DB::table('settings')->where('key', self::SNAPSHOT_KEY)->exists()) {
            $removed = [];
            foreach (self::REVOKE as $slug => $keys) {
                $roleId = DB::table('roles')->where('slug', $slug)->value('id');
                if (! $roleId) continue;
                $ids = DB::table('permissions')->whereIn('key', $keys)->pluck('id')->all();
                $had = DB::table('role_permissions')->where('role_id', $roleId)->whereIn('permission_id', $ids)->pluck('permission_id')->all();
                if (! $had) continue;
                DB::table('role_permissions')->where('role_id', $roleId)->whereIn('permission_id', $had)->delete();
                $removed[] = ['role_id' => $roleId, 'permission_ids' => array_map('intval', $had)];
            }
            DB::table('settings')->insert(['key' => self::SNAPSHOT_KEY, 'value' => json_encode($removed)]);
        }
    }

    public function down(): void
    {
        $snap = DB::table('settings')->where('key', self::SNAPSHOT_KEY)->value('value');
        foreach (json_decode((string) $snap, true) ?: [] as $r) {
            foreach ($r['permission_ids'] as $pid) DB::table('role_permissions')->insertOrIgnore(['role_id' => $r['role_id'], 'permission_id' => $pid]);
        }
        DB::table('settings')->where('key', self::SNAPSHOT_KEY)->delete();
        $pid = DB::table('permissions')->where('key', 'attendance.assign')->value('id');
        if ($pid) {
            DB::table('role_permissions')->where('permission_id', $pid)->delete();
            DB::table('user_permissions')->where('permission_id', $pid)->delete();
            if (Schema::hasTable('user_permission_revocations')) DB::table('user_permission_revocations')->where('permission_id', $pid)->delete();
            DB::table('permissions')->where('id', $pid)->delete();
        }
        if (collect(DB::select("SHOW INDEX FROM program_attendance_takers WHERE Key_name = 'pat_one_taker'"))->isNotEmpty()) DB::statement('ALTER TABLE program_attendance_takers DROP KEY pat_one_taker');
        if (Schema::hasColumn('attendance_corrections', 'requested_attended_at')) DB::statement('ALTER TABLE attendance_corrections DROP COLUMN requested_attended_at');
        Schema::dropIfExists('attendance_sync_conflicts');
        Schema::dropIfExists('attendance_signatures');
        if (Schema::hasColumn('attendance', 'session_id')) {
            DB::statement('ALTER TABLE attendance DROP KEY attendance_client_event, DROP KEY attendance_session,
                DROP COLUMN session_id, DROP COLUMN client_captured_at, DROP COLUMN received_at, DROP COLUMN elapsed_seconds, DROP COLUMN time_source,
                DROP COLUMN signature_id, DROP COLUMN signature_exempt, DROP COLUMN source, DROP COLUMN client_event_id');
        }
        Schema::dropIfExists('attendance_sessions');
    }
};
