<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Administrator-created member types and wider internal-page links.
 *  - member_groups: the member types (ሕጻናት / ወጣቶች እና አዋቂዎች / ባለትዳሮች are built in; administrators
 *    add others such as "distance members"). users.member_group and the program / holiday-selection
 *    target lists now hold any of these keys (no longer a fixed enum).
 *  - permission member_groups.manage (granted to the roles that configure member IDs).
 *  - pages: the button can open a program, Mezmur, category, class, course, assignment, another
 *    internal page, the education library or a web link (cta_url).
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('member_groups')) {
            DB::statement("CREATE TABLE member_groups (
                `key` varchar(40) NOT NULL PRIMARY KEY,
                name varchar(100) NOT NULL,
                name_en varchar(100) DEFAULT NULL,
                description varchar(500) DEFAULT NULL,
                sort_order int NOT NULL DEFAULT 0,
                is_active tinyint(1) NOT NULL DEFAULT 1,
                built_in tinyint(1) NOT NULL DEFAULT 0,
                created_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                CONSTRAINT mg_creator_fk FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
            DB::table('member_groups')->insert([
                ['key' => 'children', 'name' => 'ሕጻናት', 'name_en' => 'Children', 'sort_order' => 1, 'built_in' => 1],
                ['key' => 'youth_adult', 'name' => 'ወጣቶች እና አዋቂዎች', 'name_en' => 'Youth & Adult', 'sort_order' => 2, 'built_in' => 1],
                ['key' => 'married', 'name' => 'ባለትዳሮች', 'name_en' => 'Married', 'sort_order' => 3, 'built_in' => 1],
            ]);
        }
        DB::statement("ALTER TABLE users MODIFY member_group varchar(40) NOT NULL DEFAULT 'youth_adult'");
        DB::statement('ALTER TABLE programs MODIFY member_groups varchar(1000) DEFAULT NULL');
        if (Schema::hasTable('holiday_selections')) DB::statement('ALTER TABLE holiday_selections MODIFY member_groups varchar(1000) DEFAULT NULL');

        // Optional attendance takers per program: when a program lists takers, only they (and
        // attendance.override holders) record its attendance; with none, every attendance taker may.
        if (! Schema::hasTable('program_attendance_takers')) {
            DB::statement("CREATE TABLE program_attendance_takers (
                program_id int unsigned NOT NULL,
                user_id int unsigned NOT NULL,
                added_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                PRIMARY KEY (program_id, user_id),
                KEY pat_user (user_id),
                CONSTRAINT pat_program_fk FOREIGN KEY (program_id) REFERENCES programs (id) ON DELETE CASCADE,
                CONSTRAINT pat_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pat_adder_fk FOREIGN KEY (added_by) REFERENCES users (id) ON DELETE SET NULL
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        DB::statement("ALTER TABLE pages MODIFY cta_action varchar(30) NOT NULL DEFAULT 'none'");
        if (! Schema::hasColumn('pages', 'cta_url')) DB::statement('ALTER TABLE pages ADD COLUMN cta_url varchar(500) DEFAULT NULL AFTER cta_target_id');

        DB::table('permissions')->insertOrIgnore(['key' => 'member_groups.manage', 'group_key' => 'users', 'description' => 'Create and edit member types (groups) used by programs and attendance']);
        $pid = DB::table('permissions')->where('key', 'member_groups.manage')->value('id');
        $from = DB::table('permissions')->where('key', 'member_id.configure')->value('id');
        if ($pid && $from) {
            foreach (DB::table('role_permissions')->where('permission_id', $from)->pluck('role_id') as $rid) {
                DB::table('role_permissions')->insertOrIgnore(['role_id' => $rid, 'permission_id' => $pid]);
            }
        }
    }

    public function down(): void
    {
        DB::table('permissions')->where('key', 'member_groups.manage')->delete();
        Schema::dropIfExists('program_attendance_takers');
        if (Schema::hasColumn('pages', 'cta_url')) DB::statement('ALTER TABLE pages DROP COLUMN cta_url');
        DB::table('pages')->whereNotIn('cta_action', ['none', 'open_program', 'register_program', 'open_mezmur', 'open_category'])->update(['cta_action' => 'none']);
        DB::statement("ALTER TABLE pages MODIFY cta_action enum('none','open_program','register_program','open_mezmur','open_category') NOT NULL DEFAULT 'none'");
        DB::table('users')->whereNotIn('member_group', ['children', 'youth_adult', 'married'])->update(['member_group' => 'youth_adult']);
        DB::statement("ALTER TABLE users MODIFY member_group enum('children','youth_adult','married') NOT NULL DEFAULT 'youth_adult'");
        Schema::dropIfExists('member_groups');
    }
};
