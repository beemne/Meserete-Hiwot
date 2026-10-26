<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. edu_units: bilingual fields
        if (Schema::hasTable('edu_units')) {
            Schema::table('edu_units', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_units', 'title_en')) {
                    $table->string('title_en', 200)->nullable()->after('title');
                }
                if (! Schema::hasColumn('edu_units', 'description_en')) {
                    $table->string('description_en', 2000)->nullable()->after('description');
                }
            });
        }

        // 2. edu_lessons: bilingual fields and requires_quiz progression config
        if (Schema::hasTable('edu_lessons')) {
            Schema::table('edu_lessons', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_lessons', 'title_en')) {
                    $table->string('title_en', 200)->nullable()->after('title');
                }
                if (! Schema::hasColumn('edu_lessons', 'summary_en')) {
                    $table->string('summary_en', 1000)->nullable()->after('summary');
                }
                if (! Schema::hasColumn('edu_lessons', 'body_en')) {
                    $table->longText('body_en')->nullable()->after('body');
                }
                if (! Schema::hasColumn('edu_lessons', 'objectives_en')) {
                    $table->text('objectives_en')->nullable()->after('objectives');
                }
                if (! Schema::hasColumn('edu_lessons', 'requires_quiz')) {
                    $table->boolean('requires_quiz')->default(false)->after('is_mandatory');
                }
            });
        }

        // 3. edu_lesson_materials: bilingual fields
        if (Schema::hasTable('edu_lesson_materials')) {
            Schema::table('edu_lesson_materials', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_lesson_materials', 'title_en')) {
                    $table->string('title_en', 200)->nullable()->after('title');
                }
                if (! Schema::hasColumn('edu_lesson_materials', 'description')) {
                    $table->string('description', 2000)->nullable()->after('title_en');
                }
                if (! Schema::hasColumn('edu_lesson_materials', 'description_en')) {
                    $table->string('description_en', 2000)->nullable()->after('description');
                }
            });
        }

        // 4. edu_categories: bilingual description
        if (Schema::hasTable('edu_categories')) {
            Schema::table('edu_categories', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_categories', 'description_en')) {
                    $table->string('description_en', 2000)->nullable()->after('description');
                }
            });
        }

        // 5. edu_subjects: bilingual description & objectives
        if (Schema::hasTable('edu_subjects')) {
            Schema::table('edu_subjects', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_subjects', 'description_en')) {
                    $table->string('description_en', 4000)->nullable()->after('description');
                }
                if (! Schema::hasColumn('edu_subjects', 'objectives_en')) {
                    $table->text('objectives_en')->nullable()->after('objectives');
                }
            });
        }

        // 6. edu_classes: bilingual fields and allow_self_registration (default false)
        if (Schema::hasTable('edu_classes')) {
            Schema::table('edu_classes', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_classes', 'name_en')) {
                    $table->string('name_en', 100)->nullable()->after('name');
                }
                if (! Schema::hasColumn('edu_classes', 'description_en')) {
                    $table->string('description_en', 2000)->nullable()->after('description');
                }
                if (! Schema::hasColumn('edu_classes', 'allow_self_registration')) {
                    $table->boolean('allow_self_registration')->default(false)->after('status');
                }
            });
        }

        // 7. edu_quizzes: bilingual fields
        if (Schema::hasTable('edu_quizzes')) {
            Schema::table('edu_quizzes', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_quizzes', 'title_en')) {
                    $table->string('title_en', 200)->nullable()->after('title');
                }
                if (! Schema::hasColumn('edu_quizzes', 'instructions_en')) {
                    $table->text('instructions_en')->nullable()->after('instructions');
                }
            });
        }

        // 8. edu_quiz_questions: bilingual fields
        if (Schema::hasTable('edu_quiz_questions')) {
            Schema::table('edu_quiz_questions', function (Blueprint $table) {
                if (! Schema::hasColumn('edu_quiz_questions', 'prompt_en')) {
                    $table->text('prompt_en')->nullable()->after('prompt');
                }
                if (! Schema::hasColumn('edu_quiz_questions', 'explanation_en')) {
                    $table->text('explanation_en')->nullable()->after('explanation');
                }
            });
        }
    }

    public function down(): void
    {
        // Non-destructive rollback if needed
    }
};
