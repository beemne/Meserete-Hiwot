<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Services\EduLearning;
use App\Mz\Support\ApiError;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EducationCleanupAndNotificationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Ensure sqlite in-memory tables exist for the test
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name')->nullable();
                $table->string('email')->nullable();
                $table->string('phone')->nullable();
                $table->string('status')->default('active');
                $table->unsignedInteger('role_id')->default(3);
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->id();
                $table->unsignedBigInteger('category_id')->nullable();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->text('objectives')->nullable();
                $table->string('status')->default('published');
                $table->string('visibility')->default('public');
                $table->boolean('sequential')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_levels')) {
            Schema::create('edu_levels', function ($table) {
                $table->id();
                $table->string('code', 30)->unique();
                $table->string('name', 100);
                $table->string('name_en', 100)->nullable();
                $table->string('kind')->default('grade');
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('built_in')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->unsignedInteger('level_id')->nullable();
                $table->unsignedInteger('academic_year_id')->nullable();
                $table->unsignedInteger('term_id')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('name')->nullable();
                $table->unsignedBigInteger('teacher_user_id')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_teachers')) {
            Schema::create('edu_course_teachers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('enrolled');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_units')) {
            Schema::create('edu_units', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lessons')) {
            Schema::create('edu_lessons', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id');
                $table->unsignedBigInteger('unit_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('summary')->nullable();
                $table->integer('sort_order')->default(0);
                $table->integer('est_minutes')->nullable();
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id')->nullable();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->string('kind')->default('practice');
                $table->integer('time_limit_minutes')->nullable();
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->id();
                $table->unsignedBigInteger('lesson_id');
                $table->string('kind')->default('pdf');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->string('mime')->default('application/pdf');
                $table->integer('size')->nullable();
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }
    }

    private function makeAuth(int $userId, array $permissions = [], bool $isSuperAdmin = false): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $userId;
        $auth->fullName = 'Test User';
        $auth->status = 'active';
        $auth->accountType = $isSuperAdmin ? 'admin' : 'member';
        $auth->isAdmin = $isSuperAdmin;
        $auth->level = $isSuperAdmin ? 100 : 10;
        $auth->permissions = array_fill_keys($permissions, true);
        return $auth;
    }

    public function test_subject_grades_returns_12_grades_and_correct_amharic_labels(): void
    {
        $subId = DB::table('edu_subjects')->insertGetId([
            'name' => 'ትምህርተ ሃይማኖት',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auth = $this->makeAuth(1);
        $res = EduLearning::subjectGrades($auth, $subId);

        $this->assertArrayHasKey('grades', $res);
        $this->assertCount(12, $res['grades']);
        $this->assertSame('1ኛ ክፍል', $res['grades'][0]['name']);
        $this->assertSame('12ኛ ክፍል', $res['grades'][11]['name']);
    }

    public function test_student_grade_access_control_restricts_unassigned_grades(): void
    {
        $subId = DB::table('edu_subjects')->insertGetId([
            'name' => 'የመጽሐፍ ቅዱስ ጥናት',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $classId = DB::table('edu_classes')->insertGetId([
            'name' => '3ኛ ክፍል A',
            'level_id' => 3,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $studentId = 50;
        DB::table('edu_enrollments')->insert([
            'class_id' => $classId,
            'user_id' => $studentId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $auth = $this->makeAuth($studentId);

        // Accessing assigned grade 3 should succeed
        $content = EduLearning::subjectGradeContent($auth, $subId, 3);
        $this->assertSame(3, $content['grade']['number']);

        // Accessing unassigned grade 5 must throw forbidden ApiError
        try {
            EduLearning::subjectGradeContent($auth, $subId, 5);
            $this->fail('Expected GRADE_ACCESS_DENIED exception for unassigned grade');
        } catch (ApiError $e) {
            $this->assertSame('GRADE_ACCESS_DENIED', $e->errorCode);
            $this->assertSame(403, $e->status);
        }
    }

    public function test_editor_restricted_in_normal_view_but_can_manage_in_admin_panel(): void
    {
        $subId = DB::table('edu_subjects')->insertGetId([
            'name' => 'ክርስቲያናዊ ሥነምግባር',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $editorAuth = $this->makeAuth(99, ['education.content']);

        // Feature C: Normal education view restricts unassigned grade
        try {
            EduLearning::subjectGradeContent($editorAuth, $subId, 8);
            $this->fail('Expected GRADE_ACCESS_DENIED for editor in normal view without assigned grade');
        } catch (ApiError $e) {
            $this->assertSame('GRADE_ACCESS_DENIED', $e->errorCode);
            $this->assertSame(403, $e->status);
        }

        // Feature C: Admin panel allows editor to access all canonical grades
        $adminGrades = \App\Mz\Services\EduAcademicYears::adminGrades($editorAuth);
        $this->assertCount(12, $adminGrades);
    }
}
