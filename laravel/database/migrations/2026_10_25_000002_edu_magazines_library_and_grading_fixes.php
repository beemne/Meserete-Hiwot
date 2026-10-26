<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $t = 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci';

        // 1. edu_magazines: Recurring PDF issues for ሰሌዳ መጽሔት
        if (! Schema::hasTable('edu_magazines')) {
            if (DB::getDriverName() === 'sqlite') {
                Schema::create('edu_magazines', function (Blueprint $table) {
                    $table->increments('id');
                    $table->string('title', 200);
                    $table->string('title_en', 200)->nullable();
                    $table->string('issue_number', 50)->nullable();
                    $table->string('period_info', 100)->nullable();
                    $table->text('description')->nullable();
                    $table->string('cover_image', 255)->nullable();
                    $table->string('pdf_path', 255);
                    $table->string('pdf_mime', 100)->default('application/pdf');
                    $table->unsignedInteger('pdf_size')->default(0);
                    $table->string('status', 20)->default('draft');
                    $table->date('issue_date');
                    $table->dateTime('published_at')->nullable();
                    $table->unsignedInteger('created_by');
                    $table->unsignedInteger('updated_by')->nullable();
                    $table->boolean('notification_sent')->default(false);
                    $table->timestamps();
                    $table->softDeletes();

                    $table->index(['status', 'published_at']);
                    $table->index('issue_date');
                });
            } else {
                DB::statement("CREATE TABLE edu_magazines (
                    id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                    title varchar(200) NOT NULL,
                    title_en varchar(200) DEFAULT NULL,
                    issue_number varchar(50) DEFAULT NULL,
                    period_info varchar(100) DEFAULT NULL,
                    description text DEFAULT NULL,
                    cover_image varchar(255) DEFAULT NULL,
                    pdf_path varchar(255) NOT NULL,
                    pdf_mime varchar(100) NOT NULL DEFAULT 'application/pdf',
                    pdf_size int unsigned NOT NULL DEFAULT 0,
                    status enum('draft','published','scheduled','archived') NOT NULL DEFAULT 'draft',
                    issue_date date NOT NULL,
                    published_at datetime DEFAULT NULL,
                    created_by int unsigned NOT NULL,
                    updated_by int unsigned DEFAULT NULL,
                    notification_sent tinyint(1) NOT NULL DEFAULT 0,
                    created_at datetime NOT NULL DEFAULT current_timestamp(),
                    updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                    deleted_at datetime DEFAULT NULL,
                    KEY idx_edu_magazines_status_pub (status, published_at),
                    KEY idx_edu_magazines_issue_date (issue_date)
                ) $t");
            }
        }

        // 2. Link quizzes to magazines (edu_quizzes.magazine_id) and make course_id nullable
        if (Schema::hasTable('edu_quizzes')) {
            if (! Schema::hasColumn('edu_quizzes', 'magazine_id')) {
                Schema::table('edu_quizzes', function (Blueprint $table) {
                    $table->unsignedInteger('magazine_id')->nullable()->after('course_id');
                    $table->index('magazine_id');
                });
            }
            if (DB::getDriverName() !== 'sqlite') {
                try {
                    DB::statement('ALTER TABLE edu_quizzes MODIFY course_id int unsigned NULL');
                } catch (\Throwable) {}
            }
        }

        // 3. Optional book associations to course, subject, unit, lesson, magazine (items table)
        if (Schema::hasTable('items')) {
            Schema::table('items', function (Blueprint $table) {
                if (! Schema::hasColumn('items', 'course_id')) {
                    $table->unsignedInteger('course_id')->nullable()->after('library_category_id');
                    $table->index('course_id');
                }
                if (! Schema::hasColumn('items', 'subject_id')) {
                    $table->unsignedInteger('subject_id')->nullable()->after('course_id');
                    $table->index('subject_id');
                }
                if (! Schema::hasColumn('items', 'unit_id')) {
                    $table->unsignedInteger('unit_id')->nullable()->after('subject_id');
                }
                if (! Schema::hasColumn('items', 'lesson_id')) {
                    $table->unsignedInteger('lesson_id')->nullable()->after('unit_id');
                }
                if (! Schema::hasColumn('items', 'magazine_id')) {
                    $table->unsignedInteger('magazine_id')->nullable()->after('lesson_id');
                    $table->index('magazine_id');
                }
            });
        }

        // 4. Add feedback and graded_at to edu_quiz_answers
        if (Schema::hasTable('edu_quiz_answers')) {
            Schema::table('edu_quiz_answers', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_quiz_answers', 'feedback')) {
                    $table->text('feedback')->nullable()->after('points_awarded');
                }
                if (! Schema::hasColumn('edu_quiz_answers', 'graded_at')) {
                    $table->dateTime('graded_at')->nullable()->after('graded_by');
                }
            });
        }
    }

    public function down(): void
    {
        // Safe rollback
        if (Schema::hasTable('edu_quiz_answers')) {
            Schema::table('edu_quiz_answers', function (Blueprint $table) {
                if (Schema::hasColumn('edu_quiz_answers', 'feedback')) {
                    $table->dropColumn('feedback');
                }
                if (Schema::hasColumn('edu_quiz_answers', 'graded_at')) {
                    $table->dropColumn('graded_at');
                }
            });
        }

        if (Schema::hasTable('items')) {
            Schema::table('items', function (Blueprint $table) {
                $cols = array_filter(['course_id', 'subject_id', 'unit_id', 'lesson_id', 'magazine_id'], fn ($c) => Schema::hasColumn('items', $c));
                if (! empty($cols)) {
                    $table->dropColumn($cols);
                }
            });
        }

        if (Schema::hasTable('edu_quizzes') && Schema::hasColumn('edu_quizzes', 'magazine_id')) {
            Schema::table('edu_quizzes', function (Blueprint $table) {
                $table->dropColumn('magazine_id');
            });
        }

        Schema::dropIfExists('edu_magazines');
    }
};
