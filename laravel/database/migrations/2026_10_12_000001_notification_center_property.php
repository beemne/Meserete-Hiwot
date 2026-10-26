<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * One notification center for every automatic event, and property beyond books.
 *  - notifications.type becomes varchar(40): a type missing from the old enum made the INSERT fail
 *    (strict SQL mode) or store '' (non-strict), so that event's notification was lost.
 *  - notifications.topic (program, attendance, project, department, education, property, mezmur,
 *    system), email_status / emailed_at (the email channel of the same notification),
 *    resent_from_id / sent_by (a resend is a NEW row; the original is never changed).
 *  - user_preferences.notification_topics: per topic, push and email on / off (JSON; null = all on).
 *  - notification_broadcasts.resent_from_id and channels (push, email).
 *  - item_categories: configurable property categories (books, equipment, electronics…).
 *  - departments.code_prefix: item codes are generated per department (e.g. FIN-EQ-0004).
 * Every change is additive; existing rows keep their meaning.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE notifications MODIFY type varchar(40) NOT NULL");
        if (! Schema::hasColumn('notifications', 'topic')) {
            DB::statement("ALTER TABLE notifications
                ADD COLUMN topic varchar(20) DEFAULT NULL AFTER type,
                ADD COLUMN email_status enum('none','pending','sent','failed','skipped') NOT NULL DEFAULT 'none' AFTER sent_at,
                ADD COLUMN emailed_at datetime DEFAULT NULL AFTER email_status,
                ADD COLUMN resent_from_id bigint unsigned DEFAULT NULL AFTER broadcast_id,
                ADD COLUMN sent_by int unsigned DEFAULT NULL AFTER resent_from_id,
                ADD INDEX notifications_email_status_index (email_status, id)");
            DB::statement("UPDATE notifications SET topic = CASE
                WHEN type IN ('program','program_reminder') THEN 'program'
                WHEN type = 'attendance' THEN 'attendance'
                WHEN type = 'project' THEN 'project'
                WHEN type = 'chat' THEN 'department'
                WHEN type = 'education' THEN 'education'
                WHEN type IN ('borrowing','borrowing_due','borrowing_overdue') THEN 'property'
                WHEN type IN ('mezmur','choir') THEN 'mezmur'
                ELSE 'system' END");
        }
        if (! Schema::hasColumn('user_preferences', 'notification_topics')) {
            DB::statement('ALTER TABLE user_preferences ADD COLUMN notification_topics text DEFAULT NULL AFTER notifications_enabled');
        }
        if (! Schema::hasColumn('notification_broadcasts', 'resent_from_id')) {
            DB::statement("ALTER TABLE notification_broadcasts
                ADD COLUMN resent_from_id int unsigned DEFAULT NULL,
                ADD COLUMN channels varchar(40) NOT NULL DEFAULT 'push'");
        }

        if (! Schema::hasTable('item_categories')) {
            DB::statement("CREATE TABLE item_categories (
                `key` varchar(40) NOT NULL PRIMARY KEY,
                name varchar(100) NOT NULL,
                name_en varchar(100) DEFAULT NULL,
                code varchar(6) NOT NULL,
                sort_order int NOT NULL DEFAULT 0,
                is_active tinyint(1) NOT NULL DEFAULT 1,
                built_in tinyint(1) NOT NULL DEFAULT 0,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
            $rows = [
                ['books', 'መጻሕፍት', 'Books', 'BK'],
                ['equipment', 'መሣሪያዎች', 'Equipment', 'EQ'],
                ['electronics', 'ኤሌክትሮኒክስ', 'Electronics', 'EL'],
                ['furniture', 'የቤት ዕቃዎች', 'Furniture', 'FR'],
                ['instruments', 'የዜማ መሣሪያዎች', 'Instruments', 'IN'],
                ['office', 'የቢሮ ዕቃዎች', 'Office materials', 'OF'],
                ['department_resources', 'የክፍል ንብረቶች', 'Department resources', 'DR'],
                ['other', 'ሌሎች', 'Other', 'OT'],
            ];
            foreach ($rows as $i => [$key, $name, $en, $code]) {
                DB::table('item_categories')->insert(['key' => $key, 'name' => $name, 'name_en' => $en, 'code' => $code, 'sort_order' => $i + 1, 'built_in' => 1]);
            }
        }
        if (! Schema::hasColumn('departments', 'code_prefix')) {
            DB::statement('ALTER TABLE departments ADD COLUMN code_prefix varchar(8) DEFAULT NULL AFTER name_en');
            $prefixes = [
                'Education and Training Department' => 'EDU',
                'Hymns and Arts Department' => 'HYM',
                'Human Resources Management Department' => 'HR',
                'Program and Conference Preparation Department' => 'PRG',
                'Finance and Property Department' => 'FIN',
                'Planning and Development Department' => 'PLN',
                'Information and Internal Communications Department' => 'INF',
            ];
            foreach ($prefixes as $en => $prefix) DB::table('departments')->where('name_en', $en)->update(['code_prefix' => $prefix]);
            DB::statement("UPDATE departments SET code_prefix = CONCAT('D', id) WHERE code_prefix IS NULL");
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('departments', 'code_prefix')) DB::statement('ALTER TABLE departments DROP COLUMN code_prefix');
        Schema::dropIfExists('item_categories');
        if (Schema::hasColumn('notification_broadcasts', 'resent_from_id')) DB::statement('ALTER TABLE notification_broadcasts DROP COLUMN resent_from_id, DROP COLUMN channels');
        if (Schema::hasColumn('user_preferences', 'notification_topics')) DB::statement('ALTER TABLE user_preferences DROP COLUMN notification_topics');
        if (Schema::hasColumn('notifications', 'topic')) DB::statement('ALTER TABLE notifications DROP INDEX notifications_email_status_index, DROP COLUMN topic, DROP COLUMN email_status, DROP COLUMN emailed_at, DROP COLUMN resent_from_id, DROP COLUMN sent_by');
    }
};
