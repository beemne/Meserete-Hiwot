<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Monthly contribution receipts support (Requirement 1)
        if (! Schema::hasTable('contribution_receipts')) {
            Schema::create('contribution_receipts', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('user_id');
                $table->string('period', 7); // e.g. '2026-10'
                $table->unsignedInteger('months')->default(1);
                $table->string('coverage_end', 7); // e.g. '2026-12'
                $table->decimal('expected_amount', 12, 2)->default(0);
                $table->decimal('submitted_amount', 12, 2)->nullable();
                $table->string('currency', 8)->default('ETB');
                $table->string('method', 20)->default('bank');
                $table->string('reference', 120)->nullable();
                $table->date('paid_on')->nullable();
                $table->string('receipt_path', 255);
                $table->text('member_note')->nullable();
                $table->enum('status', ['submitted', 'pending', 'under_review', 'approved', 'rejected', 'correction_needed'])->default('submitted');
                $table->text('review_note')->nullable();
                $table->unsignedBigInteger('reviewed_by')->nullable();
                $table->dateTime('reviewed_at')->nullable();
                $table->unsignedBigInteger('payment_id')->nullable();
                $table->timestamps();

                $table->index(['user_id', 'status'], 'idx_receipts_user_status');
                $table->index(['status', 'created_at'], 'idx_receipts_status_created');
            });
        } else {
            // Ensure status column allows 'pending' as well as 'submitted'
            try {
                DB::statement("ALTER TABLE contribution_receipts MODIFY status enum('submitted','pending','under_review','approved','rejected','correction_needed') NOT NULL DEFAULT 'submitted'");
            } catch (\Throwable $e) {
                // Ignore if already allowed or unsupported by engine
            }
        }

        // 2. Question bank tags/category/difficulty support (Requirement 14)
        if (Schema::hasTable('edu_question_banks')) {
            if (! Schema::hasColumn('edu_question_banks', 'category')) {
                Schema::table('edu_question_banks', function (Blueprint $table) {
                    $table->string('category', 100)->nullable()->after('title');
                    $table->string('difficulty', 20)->default('mixed')->after('category');
                    $table->text('description')->nullable()->after('difficulty');
                });
            }
        }

        // 3. Featured promotional banner image support (Requirement 13)
        if (Schema::hasTable('edu_featured')) {
            if (! Schema::hasColumn('edu_featured', 'image_path')) {
                Schema::table('edu_featured', function (Blueprint $table) {
                    $table->string('image_path', 500)->nullable()->after('subtitle');
                    $table->string('image_mime', 100)->nullable()->after('image_path');
                });
            }
        }

        // 4. Ensure canonical subject links for courses (Requirement 9)
        if (Schema::hasTable('edu_courses') && Schema::hasTable('edu_subjects')) {
            $selectCols = ['id'];
            if (Schema::hasColumn('edu_courses', 'name')) $selectCols[] = 'name';
            if (Schema::hasColumn('edu_courses', 'title')) $selectCols[] = 'title';

            $coursesWithoutSubject = DB::table('edu_courses')
                ->whereNull('subject_id')
                ->get($selectCols);

            foreach ($coursesWithoutSubject as $course) {
                $cleanTitle = trim($course->name ?? $course->title ?? '');
                if (empty($cleanTitle)) continue;

                $subject = DB::table('edu_subjects')
                    ->where('name', $cleanTitle)
                    ->first(['id']);

                if (! $subject) {
                    $firstCategory = DB::table('edu_categories')->value('id') ?? 1;
                    $subjectCols = Schema::getColumnListing('edu_subjects');
                    $subData = [
                        'name' => $cleanTitle,
                        'category_id' => $firstCategory,
                        'description' => "Canonical subject for {$cleanTitle}",
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                    if (in_array('status', $subjectCols)) $subData['status'] = 'published';
                    if (in_array('is_active', $subjectCols)) $subData['is_active'] = 1;

                    $subjectId = DB::table('edu_subjects')->insertGetId($subData);
                } else {
                    $subjectId = $subject->id;
                }

                DB::table('edu_courses')
                    ->where('id', $course->id)
                    ->update(['subject_id' => $subjectId]);
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('edu_question_banks') && Schema::hasColumn('edu_question_banks', 'category')) {
            Schema::table('edu_question_banks', function (Blueprint $table) {
                $table->dropColumn(['category', 'difficulty', 'description']);
            });
        }
        if (Schema::hasTable('edu_featured') && Schema::hasColumn('edu_featured', 'image_path')) {
            Schema::table('edu_featured', function (Blueprint $table) {
                $table->dropColumn(['image_path', 'image_mime']);
            });
        }
    }
};
