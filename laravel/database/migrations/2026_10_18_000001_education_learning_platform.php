<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * ትምህርት learning platform. Additive only — nothing existing is dropped, renamed or recalculated:
 *  - edu_categories: subject groupings (Holy Bible, Church History, Liturgy & Order, Hagiography…);
 *  - edu_subjects: the catalog subject (curriculum kept across classes and years); a class's subject
 *    (edu_courses) may point to it with the new nullable edu_courses.subject_id (never set here);
 *  - edu_units / edu_lessons / edu_lesson_materials: ordered curriculum with private files or links;
 *  - edu_lesson_progress: what each member opened / completed (Continue learning, progress);
 *  - edu_featured: the home banner (administrator-chosen subject, lesson or class);
 *  - edu_quizzes (+ questions, attempts, answers): digital quizzes of a class's subject; their scores
 *    reach official marks only through the existing score sheet (draft → review → publish);
 *  - permission education.content (categories, curriculum, featured), given to every role that
 *    already has education.manage.
 */
return new class extends Migration
{
    private const TABLES = ['edu_quiz_answers', 'edu_quiz_attempts', 'edu_quiz_questions', 'edu_quizzes', 'edu_featured', 'edu_lesson_progress', 'edu_lesson_materials', 'edu_lessons', 'edu_units', 'edu_subjects', 'edu_categories'];

    public function up(): void
    {
        $t = 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci';

        if (! Schema::hasTable('edu_categories')) {
            DB::statement("CREATE TABLE edu_categories (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                name varchar(150) NOT NULL,
                name_en varchar(150) DEFAULT NULL,
                description varchar(2000) DEFAULT NULL,
                image varchar(255) DEFAULT NULL,
                icon_key varchar(40) DEFAULT NULL,
                sort_order int NOT NULL DEFAULT 0,
                status enum('active','archived') NOT NULL DEFAULT 'active',
                created_by int unsigned DEFAULT NULL,
                updated_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_categories_order (status, sort_order)
            ) $t");
            $now = now()->format('Y-m-d H:i:s');
            DB::table('edu_categories')->insert([
                ['name' => 'መጽሐፍ ቅዱስ', 'name_en' => 'Holy Bible', 'icon_key' => 'bible', 'sort_order' => 1, 'created_at' => $now, 'updated_at' => $now],
                ['name' => 'የቤተ ክርስቲያን ታሪክ', 'name_en' => 'Church History', 'icon_key' => 'church', 'sort_order' => 2, 'created_at' => $now, 'updated_at' => $now],
                ['name' => 'ሥርዓተ አምልኮ', 'name_en' => 'Liturgy & Order', 'icon_key' => 'censer', 'sort_order' => 3, 'created_at' => $now, 'updated_at' => $now],
                ['name' => 'ነገረ ቅዱሳን', 'name_en' => 'Hagiography', 'icon_key' => 'saint', 'sort_order' => 4, 'created_at' => $now, 'updated_at' => $now],
            ]);
        }

        if (! Schema::hasTable('edu_subjects')) {
            DB::statement("CREATE TABLE edu_subjects (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                category_id int unsigned DEFAULT NULL,
                name varchar(150) NOT NULL,
                name_en varchar(150) DEFAULT NULL,
                code varchar(30) DEFAULT NULL,
                description varchar(4000) DEFAULT NULL,
                objectives text DEFAULT NULL,
                cover_image varchar(255) DEFAULT NULL,
                visibility enum('enrolled','members') NOT NULL DEFAULT 'enrolled',
                sequential tinyint(1) NOT NULL DEFAULT 0,
                status enum('draft','published','archived') NOT NULL DEFAULT 'draft',
                sort_order int NOT NULL DEFAULT 0,
                created_by int unsigned DEFAULT NULL,
                updated_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_subjects_category (category_id, status, sort_order),
                CONSTRAINT edu_subjects_category_fk FOREIGN KEY (category_id) REFERENCES edu_categories (id) ON DELETE SET NULL
            ) $t");
        }

        if (! Schema::hasColumn('edu_courses', 'subject_id')) {
            DB::statement('ALTER TABLE edu_courses ADD COLUMN subject_id int unsigned DEFAULT NULL AFTER class_id, ADD KEY edu_courses_subject (subject_id)');
        }

        if (! Schema::hasTable('edu_units')) {
            DB::statement("CREATE TABLE edu_units (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                subject_id int unsigned NOT NULL,
                title varchar(200) NOT NULL,
                description varchar(2000) DEFAULT NULL,
                sort_order int NOT NULL DEFAULT 0,
                status enum('draft','published','archived') NOT NULL DEFAULT 'published',
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_units_subject (subject_id, sort_order),
                CONSTRAINT edu_units_subject_fk FOREIGN KEY (subject_id) REFERENCES edu_subjects (id) ON DELETE CASCADE
            ) $t");
        }

        if (! Schema::hasTable('edu_lessons')) {
            DB::statement("CREATE TABLE edu_lessons (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                subject_id int unsigned NOT NULL,
                unit_id int unsigned DEFAULT NULL,
                title varchar(200) NOT NULL,
                summary varchar(1000) DEFAULT NULL,
                body longtext DEFAULT NULL,
                scripture_refs varchar(1000) DEFAULT NULL,
                objectives text DEFAULT NULL,
                teacher_notes text DEFAULT NULL,
                est_minutes smallint unsigned DEFAULT NULL,
                sort_order int NOT NULL DEFAULT 0,
                status enum('draft','published','archived') NOT NULL DEFAULT 'draft',
                published_at datetime DEFAULT NULL,
                author_id int unsigned DEFAULT NULL,
                updated_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_lessons_subject (subject_id, status, sort_order),
                KEY edu_lessons_unit (unit_id),
                CONSTRAINT edu_lessons_subject_fk FOREIGN KEY (subject_id) REFERENCES edu_subjects (id) ON DELETE CASCADE,
                CONSTRAINT edu_lessons_unit_fk FOREIGN KEY (unit_id) REFERENCES edu_units (id) ON DELETE SET NULL
            ) $t");
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            DB::statement("CREATE TABLE edu_lesson_materials (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                lesson_id int unsigned NOT NULL,
                kind enum('file','link','video_link') NOT NULL,
                title varchar(200) NOT NULL,
                path varchar(255) DEFAULT NULL,
                original_name varchar(255) DEFAULT NULL,
                mime varchar(120) DEFAULT NULL,
                size int unsigned DEFAULT NULL,
                sha256 char(64) DEFAULT NULL,
                url varchar(1000) DEFAULT NULL,
                sort_order int NOT NULL DEFAULT 0,
                uploaded_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_lesson_materials_lesson (lesson_id, sort_order),
                CONSTRAINT edu_lesson_materials_lesson_fk FOREIGN KEY (lesson_id) REFERENCES edu_lessons (id) ON DELETE CASCADE
            ) $t");
        }

        if (! Schema::hasTable('edu_lesson_progress')) {
            DB::statement("CREATE TABLE edu_lesson_progress (
                user_id int unsigned NOT NULL,
                lesson_id int unsigned NOT NULL,
                started_at datetime NOT NULL DEFAULT current_timestamp(),
                last_opened_at datetime NOT NULL DEFAULT current_timestamp(),
                completed_at datetime DEFAULT NULL,
                bookmarked tinyint(1) NOT NULL DEFAULT 0,
                PRIMARY KEY (user_id, lesson_id),
                KEY edu_lesson_progress_recent (user_id, last_opened_at),
                KEY edu_lesson_progress_lesson (lesson_id),
                CONSTRAINT edu_lesson_progress_lesson_fk FOREIGN KEY (lesson_id) REFERENCES edu_lessons (id) ON DELETE CASCADE,
                CONSTRAINT edu_lesson_progress_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            ) $t");
        }

        if (! Schema::hasTable('edu_featured')) {
            DB::statement("CREATE TABLE edu_featured (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                target_type enum('subject','lesson','class') NOT NULL,
                target_id int unsigned NOT NULL,
                title varchar(200) DEFAULT NULL,
                subtitle varchar(300) DEFAULT NULL,
                image varchar(255) DEFAULT NULL,
                starts_at datetime DEFAULT NULL,
                ends_at datetime DEFAULT NULL,
                sort_order int NOT NULL DEFAULT 0,
                is_active tinyint(1) NOT NULL DEFAULT 1,
                created_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_featured_active (is_active, sort_order)
            ) $t");
        }

        if (! Schema::hasTable('edu_quizzes')) {
            DB::statement("CREATE TABLE edu_quizzes (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                course_id int unsigned NOT NULL,
                lesson_id int unsigned DEFAULT NULL,
                assessment_id int unsigned DEFAULT NULL,
                title varchar(200) NOT NULL,
                instructions text DEFAULT NULL,
                opens_at datetime DEFAULT NULL,
                closes_at datetime DEFAULT NULL,
                time_limit_minutes smallint unsigned DEFAULT NULL,
                max_attempts tinyint unsigned NOT NULL DEFAULT 1,
                scoring enum('best','last') NOT NULL DEFAULT 'best',
                shuffle tinyint(1) NOT NULL DEFAULT 0,
                review_policy enum('never','after_submit','after_close','practice') NOT NULL DEFAULT 'after_close',
                status enum('draft','published','closed') NOT NULL DEFAULT 'draft',
                created_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_quizzes_course (course_id, status),
                KEY edu_quizzes_assessment (assessment_id),
                CONSTRAINT edu_quizzes_course_fk FOREIGN KEY (course_id) REFERENCES edu_courses (id) ON DELETE CASCADE,
                CONSTRAINT edu_quizzes_lesson_fk FOREIGN KEY (lesson_id) REFERENCES edu_lessons (id) ON DELETE SET NULL,
                CONSTRAINT edu_quizzes_assessment_fk FOREIGN KEY (assessment_id) REFERENCES edu_assessments (id) ON DELETE SET NULL
            ) $t");
            DB::statement("CREATE TABLE edu_quiz_questions (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                quiz_id int unsigned NOT NULL,
                type enum('single','multiple','true_false','short_text') NOT NULL,
                prompt text NOT NULL,
                options text DEFAULT NULL,
                answer text DEFAULT NULL,
                explanation text DEFAULT NULL,
                points decimal(6,2) NOT NULL DEFAULT 1.00,
                sort_order int NOT NULL DEFAULT 0,
                KEY edu_quiz_questions_quiz (quiz_id, sort_order),
                CONSTRAINT edu_quiz_questions_quiz_fk FOREIGN KEY (quiz_id) REFERENCES edu_quizzes (id) ON DELETE CASCADE
            ) $t");
            DB::statement("CREATE TABLE edu_quiz_attempts (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                quiz_id int unsigned NOT NULL,
                user_id int unsigned NOT NULL,
                attempt_no tinyint unsigned NOT NULL,
                started_at datetime NOT NULL DEFAULT current_timestamp(),
                expires_at datetime DEFAULT NULL,
                submitted_at datetime DEFAULT NULL,
                status enum('in_progress','submitted','graded') NOT NULL DEFAULT 'in_progress',
                auto_score decimal(8,2) DEFAULT NULL,
                manual_score decimal(8,2) DEFAULT NULL,
                max_score decimal(8,2) DEFAULT NULL,
                needs_grading tinyint(1) NOT NULL DEFAULT 0,
                transferred_at datetime DEFAULT NULL,
                UNIQUE KEY edu_quiz_attempts_unique (quiz_id, user_id, attempt_no),
                KEY edu_quiz_attempts_user (user_id, status),
                CONSTRAINT edu_quiz_attempts_quiz_fk FOREIGN KEY (quiz_id) REFERENCES edu_quizzes (id) ON DELETE CASCADE,
                CONSTRAINT edu_quiz_attempts_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            ) $t");
            DB::statement("CREATE TABLE edu_quiz_answers (
                attempt_id int unsigned NOT NULL,
                question_id int unsigned NOT NULL,
                response text DEFAULT NULL,
                is_correct tinyint(1) DEFAULT NULL,
                points_awarded decimal(6,2) DEFAULT NULL,
                graded_by int unsigned DEFAULT NULL,
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                PRIMARY KEY (attempt_id, question_id),
                CONSTRAINT edu_quiz_answers_attempt_fk FOREIGN KEY (attempt_id) REFERENCES edu_quiz_attempts (id) ON DELETE CASCADE,
                CONSTRAINT edu_quiz_answers_question_fk FOREIGN KEY (question_id) REFERENCES edu_quiz_questions (id) ON DELETE CASCADE
            ) $t");
        }

        DB::table('permissions')->insertOrIgnore(['key' => 'education.content', 'group_key' => 'education', 'description' => 'Manage subject categories, curriculum (subjects, units, lessons, materials) and the featured banner']);
        $content = DB::table('permissions')->where('key', 'education.content')->value('id');
        $manage = DB::table('permissions')->where('key', 'education.manage')->value('id');
        if ($content && $manage) {
            foreach (DB::table('role_permissions')->where('permission_id', $manage)->pluck('role_id') as $roleId) {
                DB::table('role_permissions')->insertOrIgnore(['role_id' => $roleId, 'permission_id' => $content]);
            }
        }
    }

    public function down(): void
    {
        $pid = DB::table('permissions')->where('key', 'education.content')->value('id');
        if ($pid) {
            DB::table('role_permissions')->where('permission_id', $pid)->delete();
            DB::table('user_permissions')->where('permission_id', $pid)->delete();
            if (Schema::hasTable('user_permission_revocations')) DB::table('user_permission_revocations')->where('permission_id', $pid)->delete();
            DB::table('permissions')->where('id', $pid)->delete();
        }
        foreach (self::TABLES as $table) Schema::dropIfExists($table);
        if (Schema::hasColumn('edu_courses', 'subject_id')) DB::statement('ALTER TABLE edu_courses DROP KEY edu_courses_subject, DROP COLUMN subject_id');
    }
};
