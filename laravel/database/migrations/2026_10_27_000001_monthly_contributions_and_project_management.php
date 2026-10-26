<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const PERMISSIONS = [
        ['contributions.submit', 'finance', 'Submit monthly contribution payment receipts'],
        ['contributions.review', 'finance', 'Review, approve, and reject member contribution receipts'],
        ['pm.timesheets.manage', 'projects', 'Manage and approve department timesheets'],
        ['pm.recognitions.manage', 'projects', 'Review and approve volunteer recognitions'],
        ['pm.decisions.manage', 'projects', 'Record and publish leadership decisions and meeting minutes'],
    ];

    public function up(): void
    {
        $t = fn (string $sql) => DB::statement($sql . ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci');

        // 1. Member Contribution Receipts
        if (! Schema::hasTable('contribution_receipts')) {
            $t("CREATE TABLE contribution_receipts (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                period varchar(7) NOT NULL,
                months int unsigned NOT NULL DEFAULT 1,
                coverage_end varchar(7) NOT NULL,
                expected_amount decimal(12,2) NOT NULL,
                submitted_amount decimal(12,2) NOT NULL,
                currency varchar(8) NOT NULL DEFAULT 'ETB',
                method enum('cash','bank','telebirr','other') NOT NULL DEFAULT 'bank',
                reference varchar(120) DEFAULT NULL,
                paid_on date NOT NULL,
                receipt_path varchar(255) NOT NULL,
                member_note text DEFAULT NULL,
                status enum('submitted','under_review','approved','rejected','correction_needed') NOT NULL DEFAULT 'submitted',
                review_note text DEFAULT NULL,
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                payment_id int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY cr_user_status (user_id, status),
                KEY cr_period (period),
                KEY cr_status (status),
                CONSTRAINT cr_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT cr_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT cr_payment_fk FOREIGN KEY (payment_id) REFERENCES payments (id) ON DELETE SET NULL
            )");
        }

        // 2. Extend project_tasks for review workflow & deliverable tracking
        if (Schema::hasTable('project_tasks')) {
            if (! Schema::hasColumn('project_tasks', 'deliverable_achieved')) {
                DB::statement('ALTER TABLE project_tasks ADD COLUMN deliverable_achieved tinyint(1) DEFAULT NULL');
            }
            if (! Schema::hasColumn('project_tasks', 'completion_evidence')) {
                DB::statement('ALTER TABLE project_tasks ADD COLUMN completion_evidence varchar(255) DEFAULT NULL');
            }
            if (! Schema::hasColumn('project_tasks', 'review_feedback')) {
                DB::statement('ALTER TABLE project_tasks ADD COLUMN review_feedback text DEFAULT NULL');
            }
            if (! Schema::hasColumn('project_tasks', 'reviewed_by')) {
                DB::statement('ALTER TABLE project_tasks ADD COLUMN reviewed_by int unsigned DEFAULT NULL,
                    ADD CONSTRAINT pt_reviewed_by_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL');
            }
            if (! Schema::hasColumn('project_tasks', 'reviewed_at')) {
                DB::statement('ALTER TABLE project_tasks ADD COLUMN reviewed_at datetime DEFAULT NULL');
            }
            // Allow 'awaiting_review' in status enum
            DB::statement("ALTER TABLE project_tasks MODIFY status enum('not_started','pending','in_progress','awaiting_review','blocked','completed','cancelled') NOT NULL DEFAULT 'not_started'");
        }

        // 3. Project Milestones
        if (! Schema::hasTable('project_milestones')) {
            $t("CREATE TABLE project_milestones (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                title varchar(200) NOT NULL,
                description text DEFAULT NULL,
                due_date date NOT NULL,
                status enum('planned','in_progress','completed','missed') NOT NULL DEFAULT 'planned',
                completed_at datetime DEFAULT NULL,
                created_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY pm_project_date (project_id, due_date),
                CONSTRAINT pm_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pm_creator_fk FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }

        // 4. Project Timesheets
        if (! Schema::hasTable('project_timesheets')) {
            $t("CREATE TABLE project_timesheets (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                user_id int unsigned NOT NULL,
                project_id int unsigned NOT NULL,
                task_id int unsigned DEFAULT NULL,
                work_date date NOT NULL,
                duration_minutes int unsigned NOT NULL,
                description text NOT NULL,
                status enum('submitted','approved','rejected') NOT NULL DEFAULT 'submitted',
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                review_note text DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY pt_user_date (user_id, work_date),
                KEY pt_project_date (project_id, work_date),
                CONSTRAINT pt_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pt_proj_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pt_task_fk FOREIGN KEY (task_id) REFERENCES project_tasks (id) ON DELETE SET NULL,
                CONSTRAINT pt_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }

        // 5. Project Progress Reports
        if (! Schema::hasTable('project_progress_reports')) {
            $t("CREATE TABLE project_progress_reports (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                reporting_period varchar(30) NOT NULL,
                work_completed text NOT NULL,
                planned_work text NOT NULL,
                progress_percent tinyint unsigned NOT NULL DEFAULT 0,
                blockers text DEFAULT NULL,
                next_steps text DEFAULT NULL,
                status enum('draft','submitted','reviewed') NOT NULL DEFAULT 'submitted',
                submitted_by int unsigned NOT NULL,
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                review_notes text DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY ppr_project_period (project_id, reporting_period),
                CONSTRAINT ppr_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT ppr_submitter_fk FOREIGN KEY (submitted_by) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT ppr_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }

        // 6. Volunteer Recognition & Awards
        if (! Schema::hasTable('project_recognitions')) {
            $t("CREATE TABLE project_recognitions (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                nominee_id int unsigned NOT NULL,
                nominator_id int unsigned NOT NULL,
                project_id int unsigned DEFAULT NULL,
                task_id int unsigned DEFAULT NULL,
                category varchar(100) NOT NULL,
                description text NOT NULL,
                supporting_evidence text DEFAULT NULL,
                status enum('nominated','under_review','approved','rejected') NOT NULL DEFAULT 'nominated',
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                review_note text DEFAULT NULL,
                award_date date DEFAULT NULL,
                certificate_note text DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY pr_nominee (nominee_id),
                KEY pr_status (status),
                CONSTRAINT pr_nominee_fk FOREIGN KEY (nominee_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pr_nominator_fk FOREIGN KEY (nominator_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pr_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
                CONSTRAINT pr_task_fk FOREIGN KEY (task_id) REFERENCES project_tasks (id) ON DELETE SET NULL,
                CONSTRAINT pr_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }

        // 7. Leadership Decisions & Meeting Minutes
        if (! Schema::hasTable('project_decisions')) {
            $t("CREATE TABLE project_decisions (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                department_id int unsigned NOT NULL,
                project_id int unsigned DEFAULT NULL,
                title varchar(200) NOT NULL,
                description text NOT NULL,
                decision_date date NOT NULL,
                decision_maker_id int unsigned NOT NULL,
                meeting_minutes text DEFAULT NULL,
                follow_up_actions longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
                status enum('draft','submitted','approved','published','rejected') NOT NULL DEFAULT 'draft',
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                created_by int unsigned NOT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY pd_dept_date (department_id, decision_date),
                KEY pd_status (status),
                CONSTRAINT pd_dept_fk FOREIGN KEY (department_id) REFERENCES departments (id),
                CONSTRAINT pd_proj_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE SET NULL,
                CONSTRAINT pd_maker_fk FOREIGN KEY (decision_maker_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pd_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT pd_creator_fk FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE CASCADE
            )");
        }

        // 8. Register permissions
        foreach (self::PERMISSIONS as [$key, $group, $desc]) {
            DB::table('permissions')->insertOrIgnore(['key' => $key, 'group_key' => $group, 'description' => $desc]);
        }
        $pid = fn (string $k) => DB::table('permissions')->where('key', $k)->value('id');
        $grant = function (string $roleSlug, array $keys) use ($pid) {
            $rid = DB::table('roles')->where('slug', $roleSlug)->value('id');
            if (! $rid) return;
            foreach ($keys as $k) {
                $id = $pid($k);
                if ($id) DB::table('role_permissions')->insertOrIgnore(['role_id' => $rid, 'permission_id' => $id]);
            }
        };
        $grant('high_admin', array_column(self::PERMISSIONS, 0));
        $grant('dept_finance', ['contributions.review']);
        foreach (['dept_education', 'dept_hymns', 'dept_hr', 'dept_programs', 'dept_finance', 'dept_planning', 'dept_info'] as $slug) {
            $grant($slug, ['pm.timesheets.manage', 'pm.recognitions.manage', 'pm.decisions.manage']);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('project_decisions');
        Schema::dropIfExists('project_recognitions');
        Schema::dropIfExists('project_progress_reports');
        Schema::dropIfExists('project_timesheets');
        Schema::dropIfExists('project_milestones');
        Schema::dropIfExists('contribution_receipts');
        if (Schema::hasTable('project_tasks')) {
            if (Schema::hasColumn('project_tasks', 'reviewed_by')) {
                DB::statement('ALTER TABLE project_tasks DROP FOREIGN KEY pt_reviewed_by_fk');
                DB::statement('ALTER TABLE project_tasks DROP COLUMN reviewed_by');
            }
            if (Schema::hasColumn('project_tasks', 'deliverable_achieved')) {
                DB::statement('ALTER TABLE project_tasks DROP COLUMN deliverable_achieved');
            }
            if (Schema::hasColumn('project_tasks', 'completion_evidence')) {
                DB::statement('ALTER TABLE project_tasks DROP COLUMN completion_evidence');
            }
            if (Schema::hasColumn('project_tasks', 'review_feedback')) {
                DB::statement('ALTER TABLE project_tasks DROP COLUMN review_feedback');
            }
            if (Schema::hasColumn('project_tasks', 'reviewed_at')) {
                DB::statement('ALTER TABLE project_tasks DROP COLUMN reviewed_at');
            }
            DB::statement("ALTER TABLE project_tasks MODIFY status enum('not_started','pending','in_progress','blocked','completed','cancelled') NOT NULL DEFAULT 'not_started'");
        }
        DB::table('permissions')->whereIn('key', array_column(self::PERMISSIONS, 0))->delete();
    }
};
