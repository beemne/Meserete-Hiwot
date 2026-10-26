<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Education library and student registration:
 *  - items become books too: kind physical | digital, author, the PDF of a digital book (private
 *    file, downloaded by signed-in members), a download counter. The cover (image) and the code
 *    already existed and stay managed by the administrator;
 *  - library_requests: a member asks for a physical book; the librarian approves (or rejects) and
 *    hands it over with the member's signature, which creates the normal borrowing record;
 *  - permission education.register + role edu_registrar: an administrator who registers members
 *    (new or existing) into classes and their courses.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('items', 'kind')) {
            DB::statement("ALTER TABLE items
                ADD COLUMN kind enum('physical','digital') NOT NULL DEFAULT 'physical' AFTER domain,
                ADD COLUMN author varchar(200) DEFAULT NULL AFTER name,
                ADD COLUMN file_path varchar(255) DEFAULT NULL,
                ADD COLUMN file_mime varchar(100) DEFAULT NULL,
                ADD COLUMN file_size int unsigned DEFAULT NULL,
                ADD COLUMN downloads int unsigned NOT NULL DEFAULT 0,
                ADD KEY items_kind_index (kind)");
        }
        if (! Schema::hasTable('library_requests')) {
            DB::statement("CREATE TABLE library_requests (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                item_id int unsigned NOT NULL,
                quantity int unsigned NOT NULL DEFAULT 1,
                note varchar(500) DEFAULT NULL,
                needed_on date DEFAULT NULL,
                status enum('requested','approved','rejected','issued','cancelled') NOT NULL DEFAULT 'requested',
                review_note varchar(500) DEFAULT NULL,
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                borrowing_id int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY library_requests_status (status, created_at),
                KEY library_requests_user (user_id, status),
                CONSTRAINT lr_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT lr_item_fk FOREIGN KEY (item_id) REFERENCES items (id),
                CONSTRAINT lr_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT lr_borrowing_fk FOREIGN KEY (borrowing_id) REFERENCES borrowings (id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        DB::table('permissions')->insertOrIgnore(['key' => 'education.register', 'group_key' => 'education', 'description' => 'Register members (new or existing) into classes and their courses']);
        $pid = DB::table('permissions')->where('key', 'education.register')->value('id');
        if (! DB::table('roles')->where('slug', 'edu_registrar')->exists()) {
            DB::table('roles')->insert(['slug' => 'edu_registrar', 'name' => 'የትምህርት ተመዝጋቢ አስተዳዳሪ', 'description' => 'Registers members with their classes and courses', 'level' => 15, 'is_hidden' => false, 'is_system' => false, 'is_active' => true]);
        }
        $users = DB::table('permissions')->where('key', 'users.view')->value('id');
        foreach (['edu_registrar' => [$pid, $users], 'high_admin' => [$pid], 'moderator' => [$pid], 'dept_education' => [$pid]] as $slug => $pids) {
            $rid = DB::table('roles')->where('slug', $slug)->value('id');
            if (! $rid) continue;
            foreach (array_filter($pids) as $p) DB::table('role_permissions')->insertOrIgnore(['role_id' => $rid, 'permission_id' => $p]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('library_requests');
        if (Schema::hasColumn('items', 'kind')) {
            DB::statement('ALTER TABLE items DROP KEY items_kind_index, DROP COLUMN kind, DROP COLUMN author, DROP COLUMN file_path, DROP COLUMN file_mime, DROP COLUMN file_size, DROP COLUMN downloads');
        }
        $rid = DB::table('roles')->where('slug', 'edu_registrar')->value('id');
        if ($rid && ! DB::table('users')->where('role_id', $rid)->exists() && ! DB::table('department_admins')->where('role_id', $rid)->exists()) DB::table('roles')->where('id', $rid)->delete();
        DB::table('permissions')->where('key', 'education.register')->delete();
    }
};
