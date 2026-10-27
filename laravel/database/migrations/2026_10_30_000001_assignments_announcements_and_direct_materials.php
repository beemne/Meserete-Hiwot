<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        // 1. Direct Course Materials: make lesson_id nullable & add category_id, subject_id, grade, status
        if (Schema::hasTable('edu_lesson_materials')) {
            Schema::table('edu_lesson_materials', function (Blueprint $table) {
                if (Schema::hasColumn('edu_lesson_materials', 'lesson_id')) {
                    $table->unsignedInteger('lesson_id')->nullable()->change();
                }
                if (! Schema::hasColumn('edu_lesson_materials', 'category_id')) {
                    $table->unsignedInteger('category_id')->nullable()->after('lesson_id');
                }
                if (! Schema::hasColumn('edu_lesson_materials', 'subject_id')) {
                    $table->unsignedInteger('subject_id')->nullable()->after('category_id');
                }
                if (! Schema::hasColumn('edu_lesson_materials', 'grade')) {
                    $table->unsignedTinyInteger('grade')->nullable()->after('subject_id');
                }
                if (! Schema::hasColumn('edu_lesson_materials', 'status')) {
                    $table->string('status', 20)->default('published')->after('grade');
                }
            });

            // Add index for fast lookup of direct materials if supported
            try {
                Schema::table('edu_lesson_materials', function (Blueprint $table) {
                    $table->index(['category_id', 'grade', 'status'], 'edu_materials_cat_grade');
                    $table->index(['subject_id', 'grade', 'status'], 'edu_materials_subj_grade');
                });
            } catch (\Throwable) {
                // Indices may already exist
            }
        }

        // 2. Google Classroom-inspired Assignments
        if (! Schema::hasTable('edu_assignments')) {
            Schema::create('edu_assignments', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('course_id')->nullable()->index();
                $table->unsignedInteger('class_id')->nullable()->index();
                $table->unsignedInteger('subject_id')->nullable()->index();
                $table->unsignedTinyInteger('grade')->nullable()->index();
                $table->unsignedInteger('teacher_id')->index();
                $table->string('title', 255);
                $table->string('title_en', 255)->nullable();
                $table->text('instructions')->nullable();
                $table->text('instructions_en')->nullable();
                $table->json('attachments')->nullable();
                $table->decimal('max_score', 6, 2)->default(100.00);
                $table->dateTime('due_at')->nullable();
                $table->string('status', 20)->default('published')->index();
                $table->boolean('allow_late')->default(true);
                $table->boolean('allow_resubmit')->default(true);
                $table->timestamps();

                $table->index(['course_id', 'status'], 'edu_assign_course_status');
                $table->index(['class_id', 'status'], 'edu_assign_class_status');
                $table->index(['subject_id', 'grade', 'status'], 'edu_assign_subj_grade_status');
            });
        }

        // 3. Assignment Submissions
        if (! Schema::hasTable('edu_assignment_submissions')) {
            Schema::create('edu_assignment_submissions', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('assignment_id')->index();
                $table->unsignedInteger('user_id')->index();
                $table->text('text_response')->nullable();
                $table->json('attachments')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->boolean('is_late')->default(false);
                $table->string('status', 20)->default('submitted')->index();
                $table->decimal('score', 6, 2)->nullable();
                $table->text('feedback')->nullable();
                $table->unsignedInteger('graded_by')->nullable();
                $table->dateTime('graded_at')->nullable();
                $table->dateTime('released_at')->nullable();
                $table->timestamps();

                $table->unique(['assignment_id', 'user_id'], 'edu_assign_user_unique');
                $table->index(['user_id', 'status'], 'edu_assign_sub_user_status');
            });
        }

        // 4. Teacher Announcements
        if (! Schema::hasTable('edu_announcements')) {
            Schema::create('edu_announcements', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('course_id')->nullable()->index();
                $table->unsignedInteger('class_id')->nullable()->index();
                $table->unsignedInteger('subject_id')->nullable()->index();
                $table->unsignedTinyInteger('grade')->nullable()->index();
                $table->unsignedInteger('teacher_id')->index();
                $table->string('title', 255)->nullable();
                $table->string('title_en', 255)->nullable();
                $table->text('body');
                $table->text('body_en')->nullable();
                $table->json('attachments')->nullable();
                $table->string('status', 20)->default('published')->index();
                $table->dateTime('published_at')->nullable();
                $table->timestamps();

                $table->index(['course_id', 'status'], 'edu_announce_course_status');
                $table->index(['class_id', 'status'], 'edu_announce_class_status');
                $table->index(['subject_id', 'grade', 'status'], 'edu_announce_subj_grade_status');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('edu_announcements');
        Schema::dropIfExists('edu_assignment_submissions');
        Schema::dropIfExists('edu_assignments');
    }
};
