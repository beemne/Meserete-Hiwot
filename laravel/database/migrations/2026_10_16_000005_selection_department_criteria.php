<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Department-owned selection criteria with controlled approval (extends the holiday selection):
 *  - selection_config_versions: each version of a selection's criteria — the overall allocation
 *    (Education / Mezmur / remaining components), the passing rules, and each department's
 *    categories with their own draft / submitted state. A high-level administrator approves or
 *    rejects the complete version; an approved version is never edited again (a revision is a new
 *    version), so every official result can be reproduced from the version it was computed with;
 *  - selection_evaluators: who may enter scores for a manually evaluated category;
 *  - selection_scores: those scores (draft → submitted → approved / rejected), with who and when;
 *  - selection_results: outcome (pending / not_eligible / eligible / selected /
 *    eligible_not_selected), rank, the exact unrounded score and the config version used.
 * Selections without a version keep the former fixed-component calculation unchanged.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('selection_config_versions')) {
            DB::statement("CREATE TABLE selection_config_versions (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                selection_id int unsigned NOT NULL,
                version int unsigned NOT NULL,
                status enum('draft','submitted','approved','rejected','superseded') NOT NULL DEFAULT 'draft',
                allocation longtext NOT NULL,
                passing longtext NOT NULL,
                departments longtext NOT NULL,
                hash varchar(64) DEFAULT NULL,
                created_by int unsigned DEFAULT NULL,
                submitted_at datetime DEFAULT NULL,
                decided_by int unsigned DEFAULT NULL,
                decided_at datetime DEFAULT NULL,
                comment text DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY selection_config_versions_unique (selection_id, version)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }
        if (! Schema::hasTable('selection_evaluators')) {
            DB::statement("CREATE TABLE selection_evaluators (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                selection_id int unsigned NOT NULL,
                criterion_key varchar(60) NOT NULL,
                user_id int unsigned NOT NULL,
                assigned_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                UNIQUE KEY selection_evaluators_unique (selection_id, criterion_key, user_id)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }
        if (! Schema::hasTable('selection_scores')) {
            DB::statement("CREATE TABLE selection_scores (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                selection_id int unsigned NOT NULL,
                criterion_key varchar(60) NOT NULL,
                user_id int unsigned NOT NULL,
                raw_score decimal(8,2) DEFAULT NULL,
                participated tinyint(1) NOT NULL DEFAULT 1,
                status enum('draft','submitted','approved','rejected') NOT NULL DEFAULT 'draft',
                entered_by int unsigned DEFAULT NULL,
                entered_at datetime DEFAULT NULL,
                reviewed_by int unsigned DEFAULT NULL,
                reviewed_at datetime DEFAULT NULL,
                note text DEFAULT NULL,
                UNIQUE KEY selection_scores_unique (selection_id, criterion_key, user_id),
                KEY selection_scores_status (selection_id, status)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci");
        }
        if (! Schema::hasColumn('selection_results', 'outcome')) {
            DB::statement("ALTER TABLE selection_results
                ADD COLUMN outcome varchar(30) DEFAULT NULL AFTER qualified,
                ADD COLUMN `rank` int unsigned DEFAULT NULL AFTER outcome,
                ADD COLUMN score_exact decimal(10,4) DEFAULT NULL AFTER `rank`,
                ADD COLUMN config_version_id int unsigned DEFAULT NULL AFTER score_exact");
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('selection_results', 'outcome')) DB::statement('ALTER TABLE selection_results DROP COLUMN outcome, DROP COLUMN `rank`, DROP COLUMN score_exact, DROP COLUMN config_version_id');
        foreach (['selection_scores', 'selection_evaluators', 'selection_config_versions'] as $t) Schema::dropIfExists($t);
    }
};
