<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.3+21: The Results Pipeline (F8–F12).
 *  - F8: edu_lessons.is_mandatory (tinyint default 1);
 *  - F9: edu_assignments new fields (publish_at, late_policy, late_until, allow_resubmit, target_user_ids, status);
 *        edu_submissions (is_late, submitted_at);
 *        edu_submission_versions (version history without file overwrite);
 *  - F10: edu_course_outcomes (pass marks, provisional/finalized/superseded, progression count);
 *  - F11: edu_retakes (failed course retake requests & approvals);
 *         edu_scores.attempt (support multiple attempts for retakes);
 *         edu_course_enrollments status enum extension (retake, distance);
 *  - F12: edu_question_banks (question repositories);
 *         edu_quiz_draws (random question draws per quiz);
 *         edu_quizzes (results_release_at, kind enum 'quiz'/'exam');
 *         edu_quiz_attempts (question_ids JSON for drawn questions).
 */
return new class extends Migration
{
    public function up(): void
    {
        $driver = DB::getDriverName();
        $isSqlite = $driver === 'sqlite';

        // 1. F8: edu_lessons.is_mandatory
        if (Schema::hasTable('edu_lessons') && ! Schema::hasColumn('edu_lessons', 'is_mandatory')) {
            Schema::table('edu_lessons', function (Blueprint $table) {
                $table->boolean('is_mandatory')->default(true)->after('sort_order');
            });
        }

        // 2. F9: edu_assignments new columns
        if (Schema::hasTable('edu_assignments')) {
            Schema::table('edu_assignments', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_assignments', 'publish_at')) {
                    $table->dateTime('publish_at')->nullable()->after('due_at');
                }
                if (! Schema::hasColumn('edu_assignments', 'late_policy')) {
                    $table->string('late_policy', 30)->default('refuse')->after('publish_at');
                }
                if (! Schema::hasColumn('edu_assignments', 'late_until')) {
                    $table->dateTime('late_until')->nullable()->after('late_policy');
                }
                if (! Schema::hasColumn('edu_assignments', 'allow_resubmit')) {
                    $table->boolean('allow_resubmit')->default(true)->after('late_until');
                }
                if (! Schema::hasColumn('edu_assignments', 'target_user_ids')) {
                    $table->longText('target_user_ids')->nullable()->after('allow_resubmit');
                }
                if (! Schema::hasColumn('edu_assignments', 'status')) {
                    $table->string('status', 30)->default('published')->after('target_user_ids');
                }
            });

            if (! $isSqlite) {
                DB::statement("ALTER TABLE edu_assignments MODIFY COLUMN late_policy enum('refuse','accept_marked') NOT NULL DEFAULT 'refuse'");
                DB::statement("ALTER TABLE edu_assignments MODIFY COLUMN status enum('draft','published','archived') NOT NULL DEFAULT 'published'");
            }
        }

        // 3. F9: edu_submissions (is_late, submitted_at)
        if (Schema::hasTable('edu_submissions')) {
            Schema::table('edu_submissions', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_submissions', 'is_late')) {
                    $table->boolean('is_late')->default(false)->after('file_name');
                }
                if (! Schema::hasColumn('edu_submissions', 'submitted_at')) {
                    $table->dateTime('submitted_at')->nullable()->after('is_late');
                }
            });
        }

        // 4. F9: edu_submission_versions
        if (! Schema::hasTable('edu_submission_versions')) {
            Schema::create('edu_submission_versions', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('submission_id');
                $table->longText('text')->nullable();
                $table->string('file', 255)->nullable();
                $table->string('file_name', 255)->nullable();
                $table->dateTime('submitted_at');
                $table->boolean('is_late')->default(false);
                $table->timestamps();

                $table->index(['submission_id', 'submitted_at'], 'idx_sub_versions_sub');
            });
        }

        // 5. F10: edu_course_outcomes
        if (! Schema::hasTable('edu_course_outcomes')) {
            Schema::create('edu_course_outcomes', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('course_id');
                $table->unsignedInteger('user_id');
                $table->string('attempt_type', 30)->default('original');
                $table->unsignedInteger('retake_id')->nullable();
                $table->decimal('percent', 5, 2)->default(0.00);
                $table->decimal('pass_mark', 5, 2)->default(50.00);
                $table->string('result', 30)->default('incomplete');
                $table->string('status', 30)->default('provisional');
                $table->boolean('counts_for_progression')->default(true);
                $table->unsignedInteger('finalized_by')->nullable();
                $table->dateTime('finalized_at')->nullable();
                $table->string('note', 500)->nullable();
                $table->timestamps();

                $table->index(['course_id', 'user_id', 'attempt_type', 'retake_id'], 'idx_outcomes_course_user_attempt');
                $table->index(['user_id', 'status'], 'idx_outcomes_user_status');
            });

            if (! $isSqlite) {
                DB::statement("ALTER TABLE edu_course_outcomes MODIFY COLUMN attempt_type enum('original','retake') NOT NULL DEFAULT 'original'");
                DB::statement("ALTER TABLE edu_course_outcomes MODIFY COLUMN result enum('passed','failed','incomplete') NOT NULL DEFAULT 'incomplete'");
                DB::statement("ALTER TABLE edu_course_outcomes MODIFY COLUMN status enum('provisional','finalized','superseded') NOT NULL DEFAULT 'provisional'");
            }
        }

        // 6. F11: edu_retakes
        if (! Schema::hasTable('edu_retakes')) {
            Schema::create('edu_retakes', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('original_outcome_id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('course_id');
                $table->string('status', 30)->default('requested');
                $table->unsignedInteger('requested_by');
                $table->unsignedInteger('decided_by')->nullable();
                $table->dateTime('decided_at')->nullable();
                $table->string('decision_note', 500)->nullable();
                $table->timestamps();

                $table->index(['course_id', 'user_id', 'status'], 'idx_retakes_course_user');
            });

            if (! $isSqlite) {
                DB::statement("ALTER TABLE edu_retakes MODIFY COLUMN status enum('requested','approved','rejected','active','completed','cancelled') NOT NULL DEFAULT 'requested'");
            }
        }

        // 7. F11: edu_scores.attempt column
        if (Schema::hasTable('edu_scores') && ! Schema::hasColumn('edu_scores', 'attempt')) {
            Schema::table('edu_scores', function (Blueprint $table) {
                $table->unsignedTinyInteger('attempt')->default(1)->after('user_id');
            });
            if (! $isSqlite) {
                // Drop old primary key and add attempt to primary key
                try {
                    DB::statement("ALTER TABLE edu_scores DROP PRIMARY KEY, ADD PRIMARY KEY (assessment_id, user_id, attempt)");
                } catch (\Throwable $e) {
                    // Fallback index if primary key modification varies by DB engine
                    DB::statement("ALTER TABLE edu_scores ADD KEY idx_scores_attempt (assessment_id, user_id, attempt)");
                }
            }
        }

        // 8. F11 / F8: edu_course_enrollments status enum extension
        if (Schema::hasTable('edu_course_enrollments') && ! $isSqlite) {
            DB::statement("ALTER TABLE edu_course_enrollments MODIFY COLUMN status enum('added','dropped','retake','distance','enrolled') NOT NULL DEFAULT 'added'");
        }

        // 9. F12: edu_question_banks
        if (! Schema::hasTable('edu_question_banks')) {
            Schema::create('edu_question_banks', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('subject_id');
                $table->string('title', 200);
                $table->unsignedInteger('created_by')->nullable();
                $table->timestamps();

                $table->index('subject_id', 'idx_qbanks_subject');
            });
        }

        // 10. F12: edu_quiz_questions bank_id & nullable quiz_id
        if (Schema::hasTable('edu_quiz_questions')) {
            if (! Schema::hasColumn('edu_quiz_questions', 'bank_id')) {
                Schema::table('edu_quiz_questions', function (Blueprint $table) {
                    $table->unsignedInteger('bank_id')->nullable()->after('quiz_id');
                    $table->index('bank_id', 'idx_quiz_questions_bank');
                });
            }
            if (! $isSqlite) {
                DB::statement("ALTER TABLE edu_quiz_questions MODIFY COLUMN quiz_id int unsigned NULL");
            }
        }

        // 11. F12: edu_quiz_draws
        if (! Schema::hasTable('edu_quiz_draws')) {
            Schema::create('edu_quiz_draws', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('quiz_id');
                $table->unsignedInteger('bank_id');
                $table->unsignedSmallInteger('count')->default(1);
                $table->decimal('points_each', 6, 2)->default(1.00);
                $table->timestamps();

                $table->index('quiz_id', 'idx_quiz_draws_quiz');
                $table->index('bank_id', 'idx_quiz_draws_bank');
            });
        }

        // 12. F12: edu_quizzes (results_release_at, kind)
        if (Schema::hasTable('edu_quizzes')) {
            Schema::table('edu_quizzes', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_quizzes', 'results_release_at')) {
                    $table->dateTime('results_release_at')->nullable()->after('closes_at');
                }
                if (! Schema::hasColumn('edu_quizzes', 'kind')) {
                    $table->string('kind', 30)->default('quiz')->after('results_release_at');
                }
            });

            if (! $isSqlite) {
                DB::statement("ALTER TABLE edu_quizzes MODIFY COLUMN kind enum('quiz','exam') NOT NULL DEFAULT 'quiz'");
            }
        }

        // 13. F12: edu_quiz_attempts (question_ids)
        if (Schema::hasTable('edu_quiz_attempts') && ! Schema::hasColumn('edu_quiz_attempts', 'question_ids')) {
            Schema::table('edu_quiz_attempts', function (Blueprint $table) {
                $table->longText('question_ids')->nullable()->after('needs_grading');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('edu_quiz_draws');
        Schema::dropIfExists('edu_question_banks');
        Schema::dropIfExists('edu_retakes');
        Schema::dropIfExists('edu_course_outcomes');
        Schema::dropIfExists('edu_submission_versions');
    }
};
