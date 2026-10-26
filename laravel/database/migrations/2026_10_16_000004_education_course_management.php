<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Course management on top of the existing ትምህርት tables (classes = courses offered in a term,
 * edu_courses = their subjects). Additive only — nothing existing is dropped or rewritten:
 *  - classes: academic year, semester, department and the streams students may choose;
 *    subjects (edu_courses): a code and active / inactive / archived; enrollments: the stream;
 *  - edu_course_teachers: who teaches a subject, assigned / suspended / removed by whom and when
 *    (backfilled from edu_courses.teacher_user_id, which stays the subject's main teacher);
 *  - edu_scores: draft → submitted → approved / rejected → published, with who and when.
 *    Existing marks were already visible to students, so they become 'published';
 *  - edu_score_history: every change of a mark (entry, submission, review, publication, amendment);
 *  - edu_course_enrollments: per-subject exceptions (a subject dropped from the class, or added
 *    from another class); edu_requests: student requests (class / stream / study-mode change,
 *    add / drop); edu_complaints (+ messages, internal notes kept apart); edu_journey: the student's
 *    academic history, never overwritten.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('edu_classes', 'academic_year')) {
            DB::statement('ALTER TABLE edu_classes
                ADD COLUMN academic_year varchar(20) DEFAULT NULL AFTER term,
                ADD COLUMN semester varchar(40) DEFAULT NULL AFTER academic_year,
                ADD COLUMN department_id int unsigned DEFAULT NULL AFTER semester,
                ADD COLUMN streams varchar(500) DEFAULT NULL AFTER department_id');
        }
        if (! Schema::hasColumn('edu_courses', 'status')) {
            DB::statement("ALTER TABLE edu_courses
                ADD COLUMN code varchar(30) DEFAULT NULL AFTER name,
                ADD COLUMN status enum('active','inactive','archived') NOT NULL DEFAULT 'active' AFTER completed_at");
        }
        if (! Schema::hasColumn('edu_enrollments', 'stream')) {
            DB::statement('ALTER TABLE edu_enrollments ADD COLUMN stream varchar(80) DEFAULT NULL AFTER program');
        }

        if (! Schema::hasTable('edu_course_teachers')) {
            DB::statement("CREATE TABLE edu_course_teachers (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                course_id int unsigned NOT NULL,
                user_id int unsigned NOT NULL,
                status enum('active','suspended','removed') NOT NULL DEFAULT 'active',
                assigned_by int unsigned DEFAULT NULL,
                assigned_at datetime NOT NULL DEFAULT current_timestamp(),
                changed_by int unsigned DEFAULT NULL,
                changed_at datetime DEFAULT NULL,
                note varchar(500) DEFAULT NULL,
                KEY edu_course_teachers_course (course_id, status),
                KEY edu_course_teachers_user (user_id, status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
            DB::statement("INSERT INTO edu_course_teachers (course_id, user_id, status, assigned_at, note)
                SELECT id, teacher_user_id, 'active', created_at, 'existing assignment' FROM edu_courses WHERE teacher_user_id IS NOT NULL");
        }

        if (! Schema::hasColumn('edu_scores', 'status')) {
            DB::statement("ALTER TABLE edu_scores
                ADD COLUMN status enum('draft','submitted','approved','rejected','published') NOT NULL DEFAULT 'draft' AFTER remark,
                ADD COLUMN submitted_by int unsigned DEFAULT NULL AFTER status,
                ADD COLUMN submitted_at datetime DEFAULT NULL AFTER submitted_by,
                ADD COLUMN reviewed_by int unsigned DEFAULT NULL AFTER submitted_at,
                ADD COLUMN reviewed_at datetime DEFAULT NULL AFTER reviewed_by,
                ADD COLUMN review_note text DEFAULT NULL AFTER reviewed_at,
                ADD COLUMN published_by int unsigned DEFAULT NULL AFTER review_note,
                ADD COLUMN published_at datetime DEFAULT NULL AFTER published_by,
                ADD KEY edu_scores_status (status)");
            DB::statement("UPDATE edu_scores SET status = 'published', published_at = COALESCE(updated_at, created_at)");
        }

        if (! Schema::hasTable('edu_score_history')) {
            DB::statement("CREATE TABLE edu_score_history (
                id bigint unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                assessment_id int unsigned NOT NULL,
                user_id int unsigned NOT NULL,
                action varchar(20) NOT NULL,
                old_score decimal(8,2) DEFAULT NULL,
                new_score decimal(8,2) DEFAULT NULL,
                old_status varchar(20) DEFAULT NULL,
                new_status varchar(20) DEFAULT NULL,
                actor_id int unsigned DEFAULT NULL,
                reason text DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY edu_score_history_mark (assessment_id, user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            DB::statement("CREATE TABLE edu_course_enrollments (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                course_id int unsigned NOT NULL,
                status enum('added','dropped') NOT NULL,
                changed_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY edu_course_enrollments_unique (user_id, course_id),
                KEY edu_course_enrollments_course (course_id, status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        if (! Schema::hasTable('edu_requests')) {
            DB::statement("CREATE TABLE edu_requests (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                ref varchar(24) DEFAULT NULL,
                user_id int unsigned NOT NULL,
                type enum('class_change','stream_change','study_mode_change','add_class','drop_class','add_subject','drop_subject','other') NOT NULL,
                class_id int unsigned DEFAULT NULL,
                target_class_id int unsigned DEFAULT NULL,
                course_id int unsigned DEFAULT NULL,
                current_value varchar(120) DEFAULT NULL,
                requested_value varchar(120) DEFAULT NULL,
                reason text DEFAULT NULL,
                status enum('pending','approved','rejected','cancelled','implemented') NOT NULL DEFAULT 'pending',
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                review_note text DEFAULT NULL,
                implemented_at datetime DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY edu_requests_ref (ref),
                KEY edu_requests_user (user_id, status),
                KEY edu_requests_status (status, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        if (! Schema::hasTable('edu_complaints')) {
            DB::statement("CREATE TABLE edu_complaints (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                ref varchar(24) DEFAULT NULL,
                user_id int unsigned NOT NULL,
                category enum('teacher','marks','course_admin','enrollment','placement','study_mode','other') NOT NULL,
                class_id int unsigned DEFAULT NULL,
                course_id int unsigned DEFAULT NULL,
                assessment_id int unsigned DEFAULT NULL,
                teacher_user_id int unsigned DEFAULT NULL,
                subject varchar(200) NOT NULL,
                description text NOT NULL,
                attachment_path varchar(255) DEFAULT NULL,
                attachment_name varchar(255) DEFAULT NULL,
                status enum('submitted','under_review','awaiting_information','resolved','rejected','escalated') NOT NULL DEFAULT 'submitted',
                assigned_to int unsigned DEFAULT NULL,
                resolved_at datetime DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY edu_complaints_ref (ref),
                KEY edu_complaints_user (user_id),
                KEY edu_complaints_status (status, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
            DB::statement("CREATE TABLE edu_complaint_messages (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                complaint_id int unsigned NOT NULL,
                author_id int unsigned NOT NULL,
                body text NOT NULL,
                is_internal tinyint(1) NOT NULL DEFAULT 0,
                status_change varchar(30) DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY edu_complaint_messages_complaint (complaint_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }

        if (! Schema::hasTable('edu_journey')) {
            DB::statement("CREATE TABLE edu_journey (
                id bigint unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                event varchar(40) NOT NULL,
                class_id int unsigned DEFAULT NULL,
                course_id int unsigned DEFAULT NULL,
                assessment_id int unsigned DEFAULT NULL,
                ref_type varchar(30) DEFAULT NULL,
                ref_id int unsigned DEFAULT NULL,
                old_value varchar(255) DEFAULT NULL,
                new_value varchar(255) DEFAULT NULL,
                actor_id int unsigned DEFAULT NULL,
                reason text DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY edu_journey_user (user_id, created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
            // The enrollments that already exist start each student's history.
            DB::statement("INSERT INTO edu_journey (user_id, event, class_id, new_value, created_at)
                SELECT user_id, 'enrolled', class_id, program, created_at FROM edu_enrollments");
            DB::statement("INSERT INTO edu_journey (user_id, event, class_id, old_value, created_at)
                SELECT user_id, 'withdrawn', class_id, 'active', updated_at FROM edu_enrollments WHERE status = 'withdrawn'");
        }
    }

    public function down(): void
    {
        foreach (['edu_journey', 'edu_complaint_messages', 'edu_complaints', 'edu_requests', 'edu_course_enrollments', 'edu_score_history', 'edu_course_teachers'] as $t) Schema::dropIfExists($t);
        if (Schema::hasColumn('edu_scores', 'status')) {
            DB::statement('ALTER TABLE edu_scores DROP KEY edu_scores_status, DROP COLUMN status, DROP COLUMN submitted_by, DROP COLUMN submitted_at, DROP COLUMN reviewed_by, DROP COLUMN reviewed_at, DROP COLUMN review_note, DROP COLUMN published_by, DROP COLUMN published_at');
        }
        if (Schema::hasColumn('edu_enrollments', 'stream')) DB::statement('ALTER TABLE edu_enrollments DROP COLUMN stream');
        if (Schema::hasColumn('edu_courses', 'status')) DB::statement('ALTER TABLE edu_courses DROP COLUMN code, DROP COLUMN status');
        if (Schema::hasColumn('edu_classes', 'academic_year')) DB::statement('ALTER TABLE edu_classes DROP COLUMN academic_year, DROP COLUMN semester, DROP COLUMN department_id, DROP COLUMN streams');
    }
};
