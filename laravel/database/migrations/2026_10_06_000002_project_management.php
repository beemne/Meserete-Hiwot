<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Department Project Management: one module, scoped by department.
 *
 * Reused instead of duplicated: departments / user_departments / department_admins (who belongs and
 * who leads), roles + permissions (new keys below), audit_logs (activity history and the change feed
 * the app polls), notifications + scheduled_notifications (reminders, no cron), chat_messages (the
 * Task Bot posts into the existing department chat), programs (a task may reference one), the
 * private file storage and the offline sync queue.
 */
return new class extends Migration
{
    private const PERMISSIONS = [
        ['projects.view', 'projects', 'View department projects (members always see their own department)'],
        ['projects.manage', 'projects', 'Create and manage projects, tasks and teams in the departments one administers'],
        ['projects.expenses.approve', 'projects', 'Approve project budgets, expenses and budget adjustments (Finance)'],
        ['projects.reports', 'projects', 'View project and task reports'],
        ['projects.all_departments', 'projects', 'Access the projects of every department'],
    ];

    public function up(): void
    {
        $t = fn (string $sql) => DB::statement($sql . ' ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci');

        if (! Schema::hasTable('projects')) {
            $t("CREATE TABLE projects (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                department_id int unsigned NOT NULL,
                title varchar(200) NOT NULL,
                description text DEFAULT NULL,
                leader_id int unsigned DEFAULT NULL,
                start_date date DEFAULT NULL,
                deadline datetime DEFAULT NULL,
                status enum('planning','not_started','in_progress','on_hold','completed','cancelled') NOT NULL DEFAULT 'planning',
                priority enum('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
                progress tinyint unsigned NOT NULL DEFAULT 0,
                progress_mode enum('tasks','weighted','manual') NOT NULL DEFAULT 'tasks',
                notes text DEFAULT NULL,
                allow_late_tasks tinyint(1) NOT NULL DEFAULT 0,
                currency varchar(8) NOT NULL DEFAULT 'ETB',
                proposed_budget decimal(14,2) DEFAULT NULL,
                approved_budget decimal(14,2) DEFAULT NULL,
                budget_approved_by int unsigned DEFAULT NULL,
                budget_approved_at datetime DEFAULT NULL,
                completed_at datetime DEFAULT NULL,
                created_by int unsigned DEFAULT NULL,
                updated_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                deleted_at datetime DEFAULT NULL,
                KEY projects_department_status (department_id, status),
                KEY projects_deadline (deadline),
                CONSTRAINT projects_department_fk FOREIGN KEY (department_id) REFERENCES departments (id),
                CONSTRAINT projects_leader_fk FOREIGN KEY (leader_id) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT projects_created_by_fk FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT projects_updated_by_fk FOREIGN KEY (updated_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT projects_budget_by_fk FOREIGN KEY (budget_approved_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_members')) {
            $t("CREATE TABLE project_members (
                project_id int unsigned NOT NULL,
                user_id int unsigned NOT NULL,
                role enum('leader','member') NOT NULL DEFAULT 'member',
                added_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                PRIMARY KEY (project_id, user_id),
                KEY project_members_user (user_id),
                CONSTRAINT project_members_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT project_members_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT project_members_added_by_fk FOREIGN KEY (added_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_issues')) {
            $t("CREATE TABLE project_issues (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                task_id int unsigned DEFAULT NULL,
                department_id int unsigned NOT NULL,
                reporter_id int unsigned DEFAULT NULL,
                title varchar(200) NOT NULL,
                description text DEFAULT NULL,
                priority enum('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
                status enum('open','under_review','assigned','in_progress','resolved','closed') NOT NULL DEFAULT 'open',
                assignee_id int unsigned DEFAULT NULL,
                due_date date DEFAULT NULL,
                resolution text DEFAULT NULL,
                resolved_at datetime DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY project_issues_project (project_id, status),
                KEY project_issues_assignee (assignee_id),
                CONSTRAINT project_issues_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT project_issues_department_fk FOREIGN KEY (department_id) REFERENCES departments (id),
                CONSTRAINT project_issues_reporter_fk FOREIGN KEY (reporter_id) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT project_issues_assignee_fk FOREIGN KEY (assignee_id) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_tasks')) {
            $t("CREATE TABLE project_tasks (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                department_id int unsigned NOT NULL,
                title varchar(200) NOT NULL,
                description text DEFAULT NULL,
                start_date date DEFAULT NULL,
                deadline datetime DEFAULT NULL,
                priority enum('low','medium','high','urgent') NOT NULL DEFAULT 'medium',
                status enum('not_started','pending','in_progress','blocked','completed','cancelled') NOT NULL DEFAULT 'not_started',
                status_reason varchar(500) DEFAULT NULL,
                pending_reason enum('approval','materials','finance','another_task','another_department','paused','other') DEFAULT NULL,
                progress tinyint unsigned NOT NULL DEFAULT 0,
                weight smallint unsigned NOT NULL DEFAULT 1,
                notes text DEFAULT NULL,
                issue_id int unsigned DEFAULT NULL,
                program_id int unsigned DEFAULT NULL,
                suggestion_id int unsigned DEFAULT NULL,
                completed_at datetime DEFAULT NULL,
                completed_by int unsigned DEFAULT NULL,
                completion_note varchar(1000) DEFAULT NULL,
                version int unsigned NOT NULL DEFAULT 1,
                created_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                deleted_at datetime DEFAULT NULL,
                KEY project_tasks_project (project_id, status),
                KEY project_tasks_department (department_id, status),
                KEY project_tasks_deadline (deadline),
                CONSTRAINT project_tasks_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT project_tasks_department_fk FOREIGN KEY (department_id) REFERENCES departments (id),
                CONSTRAINT project_tasks_issue_fk FOREIGN KEY (issue_id) REFERENCES project_issues (id) ON DELETE SET NULL,
                CONSTRAINT project_tasks_program_fk FOREIGN KEY (program_id) REFERENCES programs (id) ON DELETE SET NULL,
                CONSTRAINT project_tasks_completed_by_fk FOREIGN KEY (completed_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT project_tasks_created_by_fk FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
            )");
            DB::statement('ALTER TABLE project_issues ADD CONSTRAINT project_issues_task_fk FOREIGN KEY (task_id) REFERENCES project_tasks (id) ON DELETE SET NULL');
        }
        if (! Schema::hasTable('project_task_assignees')) {
            $t("CREATE TABLE project_task_assignees (
                task_id int unsigned NOT NULL,
                user_id int unsigned NOT NULL,
                assigned_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                PRIMARY KEY (task_id, user_id),
                KEY project_task_assignees_user (user_id),
                CONSTRAINT pta_task_fk FOREIGN KEY (task_id) REFERENCES project_tasks (id) ON DELETE CASCADE,
                CONSTRAINT pta_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
                CONSTRAINT pta_assigned_by_fk FOREIGN KEY (assigned_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_suggestions')) {
            $t("CREATE TABLE project_suggestions (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                department_id int unsigned NOT NULL,
                project_id int unsigned DEFAULT NULL,
                author_id int unsigned DEFAULT NULL,
                title varchar(200) NOT NULL,
                body text DEFAULT NULL,
                status enum('submitted','under_review','accepted','rejected','converted') NOT NULL DEFAULT 'submitted',
                review_note varchar(1000) DEFAULT NULL,
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                converted_task_id int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY project_suggestions_dept (department_id, status),
                CONSTRAINT ps_department_fk FOREIGN KEY (department_id) REFERENCES departments (id),
                CONSTRAINT ps_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT ps_author_fk FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT ps_reviewer_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT ps_task_fk FOREIGN KEY (converted_task_id) REFERENCES project_tasks (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_comments')) {
            $t("CREATE TABLE project_comments (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                entity_type enum('issue','suggestion','task') NOT NULL,
                entity_id int unsigned NOT NULL,
                user_id int unsigned DEFAULT NULL,
                body text NOT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY project_comments_entity (entity_type, entity_id),
                CONSTRAINT pc_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pc_user_fk FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_files')) {
            $t("CREATE TABLE project_files (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                task_id int unsigned DEFAULT NULL,
                issue_id int unsigned DEFAULT NULL,
                path varchar(255) NOT NULL,
                mime varchar(100) NOT NULL,
                size int unsigned NOT NULL,
                name varchar(150) DEFAULT NULL,
                uploaded_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY project_files_project (project_id),
                CONSTRAINT pf_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pf_task_fk FOREIGN KEY (task_id) REFERENCES project_tasks (id) ON DELETE CASCADE,
                CONSTRAINT pf_issue_fk FOREIGN KEY (issue_id) REFERENCES project_issues (id) ON DELETE CASCADE,
                CONSTRAINT pf_user_fk FOREIGN KEY (uploaded_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_budget_categories')) {
            $t("CREATE TABLE project_budget_categories (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                name varchar(120) NOT NULL,
                name_en varchar(120) DEFAULT NULL,
                sort_order smallint unsigned NOT NULL DEFAULT 0,
                is_active tinyint(1) NOT NULL DEFAULT 1,
                created_at datetime NOT NULL DEFAULT current_timestamp()
            )");
            $i = 0;
            foreach ([['መጓጓዣ', 'Transportation'], ['ምግብ', 'Food'], ['ቁሳቁስ', 'Materials'], ['መሣሪያ', 'Equipment'], ['ቦታ', 'Venue'], ['ሕትመት', 'Printing'], ['ግንኙነት', 'Communication'], ['ሌላ', 'Other']] as [$am, $en]) {
                DB::table('project_budget_categories')->insert(['name' => $am, 'name_en' => $en, 'sort_order' => ++$i]);
            }
        }
        if (! Schema::hasTable('project_budget_lines')) {
            $t("CREATE TABLE project_budget_lines (
                project_id int unsigned NOT NULL,
                category_id int unsigned NOT NULL,
                amount decimal(14,2) NOT NULL DEFAULT 0,
                PRIMARY KEY (project_id, category_id),
                CONSTRAINT pbl_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pbl_category_fk FOREIGN KEY (category_id) REFERENCES project_budget_categories (id)
            )");
        }
        if (! Schema::hasTable('project_expenses')) {
            $t("CREATE TABLE project_expenses (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                category_id int unsigned DEFAULT NULL,
                amount decimal(14,2) NOT NULL,
                currency varchar(8) NOT NULL DEFAULT 'ETB',
                description varchar(1000) NOT NULL,
                expense_date date NOT NULL,
                requested_by int unsigned DEFAULT NULL,
                paid_by varchar(150) DEFAULT NULL,
                receipt_path varchar(255) DEFAULT NULL,
                receipt_mime varchar(100) DEFAULT NULL,
                receipt_name varchar(150) DEFAULT NULL,
                status enum('pending','approved','rejected','recorded','cancelled') NOT NULL DEFAULT 'pending',
                over_budget tinyint(1) NOT NULL DEFAULT 0,
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                review_note varchar(1000) DEFAULT NULL,
                notes varchar(1000) DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY project_expenses_project (project_id, status),
                CONSTRAINT pe_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pe_category_fk FOREIGN KEY (category_id) REFERENCES project_budget_categories (id) ON DELETE SET NULL,
                CONSTRAINT pe_requested_fk FOREIGN KEY (requested_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT pe_reviewed_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }
        if (! Schema::hasTable('project_budget_adjustments')) {
            $t("CREATE TABLE project_budget_adjustments (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                project_id int unsigned NOT NULL,
                current_budget decimal(14,2) DEFAULT NULL,
                amount decimal(14,2) NOT NULL,
                reason varchar(1000) NOT NULL,
                requested_by int unsigned DEFAULT NULL,
                status enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                review_note varchar(1000) DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                KEY pba_project (project_id, status),
                CONSTRAINT pba_project_fk FOREIGN KEY (project_id) REFERENCES projects (id) ON DELETE CASCADE,
                CONSTRAINT pba_requested_fk FOREIGN KEY (requested_by) REFERENCES users (id) ON DELETE SET NULL,
                CONSTRAINT pba_reviewed_fk FOREIGN KEY (reviewed_by) REFERENCES users (id) ON DELETE SET NULL
            )");
        }

        // Task Bot messages in the existing department chat.
        if (! Schema::hasColumn('chat_messages', 'task_id')) {
            DB::statement("ALTER TABLE chat_messages MODIFY kind enum('text','image','audio','video','file','meeting','task_bot') NOT NULL DEFAULT 'text'");
            DB::statement('ALTER TABLE chat_messages ADD COLUMN task_id int unsigned DEFAULT NULL, ADD COLUMN bot_data longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
                ADD CONSTRAINT chat_messages_task_fk FOREIGN KEY (task_id) REFERENCES project_tasks (id) ON DELETE SET NULL');
        }

        // Permissions: new keys; department admin roles manage their department's projects, the
        // Finance role approves money, the high administrator gets everything.
        foreach (self::PERMISSIONS as [$key, $group, $desc]) {
            DB::table('permissions')->insertOrIgnore(['key' => $key, 'group_key' => $group, 'description' => $desc]);
        }
        $pid = fn (string $k) => DB::table('permissions')->where('key', $k)->value('id');
        $grant = function (string $roleSlug, array $keys) use ($pid) {
            $rid = DB::table('roles')->where('slug', $roleSlug)->value('id');
            if (! $rid) return;
            foreach ($keys as $k) DB::table('role_permissions')->insertOrIgnore(['role_id' => $rid, 'permission_id' => $pid($k)]);
        };
        $grant('high_admin', array_column(self::PERMISSIONS, 0));
        foreach (['dept_education', 'dept_hymns', 'dept_hr', 'dept_programs', 'dept_finance', 'dept_planning', 'dept_info'] as $slug) {
            $grant($slug, ['projects.view', 'projects.manage', 'projects.reports']);
        }
        $grant('dept_finance', ['projects.expenses.approve']);
    }

    public function down(): void
    {
        if (Schema::hasColumn('chat_messages', 'task_id')) {
            DB::statement('ALTER TABLE chat_messages DROP FOREIGN KEY chat_messages_task_fk');
            DB::statement('ALTER TABLE chat_messages DROP COLUMN task_id, DROP COLUMN bot_data');
            DB::statement("DELETE FROM chat_messages WHERE kind = 'task_bot'");
            DB::statement("ALTER TABLE chat_messages MODIFY kind enum('text','image','audio','video','file','meeting') NOT NULL DEFAULT 'text'");
        }
        foreach (['project_budget_adjustments', 'project_expenses', 'project_budget_lines', 'project_budget_categories', 'project_files', 'project_comments', 'project_suggestions', 'project_task_assignees'] as $tbl) {
            Schema::dropIfExists($tbl);
        }
        if (Schema::hasTable('project_issues')) DB::statement('ALTER TABLE project_issues DROP FOREIGN KEY project_issues_task_fk');
        Schema::dropIfExists('project_tasks');
        Schema::dropIfExists('project_issues');
        Schema::dropIfExists('project_members');
        Schema::dropIfExists('projects');
        DB::table('permissions')->whereIn('key', array_column(self::PERMISSIONS, 0))->delete();
    }
};
