<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduAcademicYears;
use App\Mz\Services\EduAnnouncements;
use App\Mz\Services\EduAssignments;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduQuizzes;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduComprehensiveABCDE_Test extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $teacherAuth;
    private AuthContext $studentAuth1;
    private AuthContext $studentAuth2;
    private array $adminActx;
    private array $teacherActx;
    private array $studentActx1;
    private array $studentActx2;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin User', ['education.manage' => true, 'education.content' => true]);
        $this->teacherAuth = $this->makeAuth(2, 'Teacher User', ['education.content' => true]);
        $this->studentAuth1 = $this->makeAuth(3, 'Student One', []);
        $this->studentAuth2 = $this->makeAuth(4, 'Student Two', []);

        $this->adminActx = ['auth' => $this->adminAuth];
        $this->teacherActx = ['auth' => $this->teacherAuth];
        $this->studentActx1 = ['auth' => $this->studentAuth1];
        $this->studentActx2 = ['auth' => $this->studentAuth2];

        // Ensure users exist in users table
        foreach ([
            [1, 'Admin User', 'admin'],
            [2, 'Teacher User', 'user'],
            [3, 'Student One', 'user'],
            [4, 'Student Two', 'user'],
        ] as [$uid, $name, $type]) {
            DB::table('users')->updateOrInsert(['id' => $uid], [
                'full_name' => $name,
                'status' => 'active',
                'account_type' => $type,
                'created_at' => Dates::now(),
                'updated_at' => Dates::now(),
            ]);
        }
    }

    private function makeAuth(int $id, string $name, array $perms = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = ! empty($perms['education.manage']) ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = ! empty($perms['education.manage']);
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->level = ! empty($perms['education.manage']) ? 100 : 10;
        $auth->permissions = $perms;
        return $auth;
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->string('key')->primary();
                $table->text('value')->nullable();
                $table->unsignedInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->unsignedBigInteger('level_id')->nullable();
                $table->string('status')->default('active');
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_levels')) {
            Schema::create('edu_levels', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('code')->nullable();
                $table->string('kind')->default('grade');
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('built_in')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->string('icon')->nullable();
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->id();
                $table->unsignedBigInteger('category_id')->nullable();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('status')->default('published');
                $table->string('visibility')->default('members');
                $table->boolean('is_active')->default(true);
                $table->boolean('sequential')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('name');
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
                $table->string('role')->default('primary');
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
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lessons')) {
            Schema::create('edu_lessons', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->unsignedBigInteger('unit_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('summary')->nullable();
                $table->longText('body')->nullable();
                $table->string('status')->default('published');
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->id();
                $table->unsignedBigInteger('lesson_id')->nullable();
                $table->unsignedBigInteger('category_id')->nullable();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->unsignedTinyInteger('grade')->nullable();
                $table->string('status')->default('published');
                $table->string('kind')->default('link');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
                $table->string('path')->nullable();
                $table->string('original_name')->nullable();
                $table->string('mime')->nullable();
                $table->unsignedBigInteger('size')->nullable();
                $table->string('sha256')->nullable();
                $table->string('url')->nullable();
                $table->integer('sort_order')->default(0);
                $table->unsignedBigInteger('uploaded_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id')->nullable();
                $table->unsignedBigInteger('lesson_id')->nullable();
                $table->string('title');
                $table->text('description')->nullable();
                $table->string('status')->default('published');
                $table->integer('max_attempts')->default(1);
                $table->integer('time_limit_minutes')->nullable();
                $table->integer('pass_score')->default(50);
                $table->dateTime('opens_at')->nullable();
                $table->dateTime('closes_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_questions')) {
            Schema::create('edu_quiz_questions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->string('type')->default('single_choice');
                $table->text('prompt');
                $table->json('options')->nullable();
                $table->json('answer')->nullable();
                $table->decimal('points', 5, 2)->default(1);
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_attempts')) {
            Schema::create('edu_quiz_attempts', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->unsignedBigInteger('user_id');
                $table->integer('attempt_no')->default(1);
                $table->string('status')->default('in_progress');
                $table->decimal('score', 6, 2)->nullable();
                $table->decimal('max_score', 6, 2)->nullable();
                $table->decimal('auto_score', 6, 2)->default(0);
                $table->decimal('manual_score', 6, 2)->default(0);
                $table->boolean('needs_grading')->default(false);
                $table->dateTime('started_at');
                $table->dateTime('expires_at')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->dateTime('completed_at')->nullable();
                $table->json('question_ids')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_draws')) {
            Schema::create('edu_quiz_draws', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attempt_id');
                $table->unsignedBigInteger('question_id');
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_answers')) {
            Schema::create('edu_quiz_answers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attempt_id');
                $table->unsignedBigInteger('question_id');
                $table->json('response')->nullable();
                $table->boolean('is_correct')->nullable();
                $table->decimal('points_awarded', 6, 2)->default(0);
                $table->text('feedback')->nullable();
                $table->unsignedBigInteger('graded_by')->nullable();
                $table->dateTime('graded_at')->nullable();
                $table->timestamps();
                $table->unique(['attempt_id', 'question_id']);
            });
        }

        if (! Schema::hasTable('edu_assignments')) {
            Schema::create('edu_assignments', function ($table) {
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
            });
        }

        if (! Schema::hasTable('edu_assignment_submissions')) {
            Schema::create('edu_assignment_submissions', function ($table) {
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
                $table->unique(['assignment_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_announcements')) {
            Schema::create('edu_announcements', function ($table) {
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
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id')->nullable();
                $table->string('action');
                $table->string('auditable_type')->nullable();
                $table->unsignedBigInteger('auditable_id')->nullable();
                $table->json('old_values')->nullable();
                $table->json('new_values')->nullable();
                $table->string('ip_address')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('notifications')) {
            Schema::create('notifications', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('type');
                $table->string('topic')->nullable();
                $table->string('title');
                $table->text('body')->nullable();
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->json('data')->nullable();
                $table->unsignedBigInteger('broadcast_id')->nullable();
                $table->unsignedBigInteger('resent_from_id')->nullable();
                $table->unsignedBigInteger('sent_by')->nullable();
                $table->string('email_status')->default('none');
                $table->string('dedupe_key')->nullable();
                $table->boolean('is_read')->default(false);
                $table->timestamps();
            });
        }
    }

    // =========================================================================
    // FEATURE A TESTS: Quiz Attempt Enforcement
    // =========================================================================

    public function test_quiz_attempt_limit_enforced_when_attempts_reach_zero(): void
    {
        $quizId = DB::table('edu_quizzes')->insertGetId([
            'title' => 'Single Attempt Quiz',
            'status' => 'published',
            'max_attempts' => 1,
            'time_limit_minutes' => 30,
            'pass_score' => 50,
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        DB::table('edu_quiz_questions')->insert([
            'quiz_id' => $quizId,
            'type' => 'single_choice',
            'prompt' => 'Question 1',
            'points' => 10,
            'options' => json_encode(['A' => 'Opt 1', 'B' => 'Opt 2']),
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // Attempt 1: Start
        $res1 = EduQuizzes::start($this->studentAuth1, $quizId);
        $this->assertArrayHasKey('id', $res1);
        $this->assertEquals('in_progress', $res1['status']);
        $attemptId = $res1['id'];

        // Resuming active attempt returns the existing active attempt
        $resResume = EduQuizzes::start($this->studentAuth1, $quizId);
        $this->assertEquals($attemptId, $resResume['id']);

        // Submit and complete Attempt 1
        DB::table('edu_quiz_attempts')->where('id', $attemptId)->update([
            'status' => 'completed',
            'completed_at' => Dates::now(),
            'score' => 80,
        ]);

        // Attempt 2: Must be rejected with NO_ATTEMPTS_LEFT
        try {
            EduQuizzes::start($this->studentAuth1, $quizId);
            $this->fail('Expected ApiError NO_ATTEMPTS_LEFT when max_attempts reached');
        } catch (ApiError $e) {
            $this->assertEquals('NO_ATTEMPTS_LEFT', $e->errorCode);
        }

        // Even an admin attempting the quiz as a student context cannot bypass max_attempts
        $adminAttempt1 = EduQuizzes::start($this->adminAuth, $quizId);
        DB::table('edu_quiz_attempts')->where('id', $adminAttempt1['id'])->update([
            'status' => 'completed',
            'completed_at' => Dates::now(),
        ]);

        try {
            EduQuizzes::start($this->adminAuth, $quizId);
            $this->fail('Admin must also respect quiz attempt limits when taking quiz');
        } catch (ApiError $e) {
            $this->assertEquals('NO_ATTEMPTS_LEFT', $e->errorCode);
        }
    }

    public function test_expired_in_progress_attempt_is_finalized_and_counts_towards_limit(): void
    {
        $quizId = DB::table('edu_quizzes')->insertGetId([
            'title' => 'Timed Quiz',
            'status' => 'published',
            'max_attempts' => 1,
            'time_limit_minutes' => 10,
            'pass_score' => 50,
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        DB::table('edu_quiz_questions')->insert([
            'quiz_id' => $quizId,
            'type' => 'single_choice',
            'prompt' => 'Timed Question',
            'points' => 10,
            'options' => json_encode(['A' => 'Opt 1', 'B' => 'Opt 2']),
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // Insert attempt started 2 hours ago (expired)
        DB::table('edu_quiz_attempts')->insert([
            'quiz_id' => $quizId,
            'user_id' => $this->studentAuth1->id,
            'status' => 'in_progress',
            'started_at' => date('Y-m-d H:i:s', time() - 7200),
            'expires_at' => date('Y-m-d H:i:s', time() - 3600),
            'created_at' => date('Y-m-d H:i:s', time() - 7200),
            'updated_at' => date('Y-m-d H:i:s', time() - 7200),
        ]);

        // Attempting to start must detect expired attempt, finalize it, and reject new attempt since limit is 1
        try {
            EduQuizzes::start($this->studentAuth1, $quizId);
            $this->fail('Expected NO_ATTEMPTS_LEFT after finalizing expired attempt');
        } catch (ApiError $e) {
            $this->assertEquals('NO_ATTEMPTS_LEFT', $e->errorCode);
        }

        // Check that DB attempt is now finalized
        $attempt = DB::table('edu_quiz_attempts')->where(['quiz_id' => $quizId, 'user_id' => $this->studentAuth1->id])->first();
        $this->assertContains($attempt->status, ['timed_out', 'graded', 'completed']);
    }

    // =========================================================================
    // FEATURE B TESTS: Course Materials Without Lessons
    // =========================================================================

    public function test_admin_can_add_direct_material_without_lesson(): void
    {
        $catId = DB::table('edu_categories')->insertGetId([
            'name' => 'Orthodox Theology',
            'is_active' => true,
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // Add direct material (link) for Grade 7 under category
        $mat = EduLearning::addDirectMaterialLink($this->adminActx, [
            'category_id' => $catId,
            'grade' => 7,
            'title' => 'Grade 7 General Reference Book',
            'url' => 'https://example.com/books/g7.pdf',
            'kind' => 'link',
            'status' => 'published',
        ]);

        $this->assertNull($mat['lesson_id']);
        $this->assertEquals($catId, $mat['category_id']);
        $this->assertEquals(7, $mat['grade']);
        $this->assertTrue($mat['is_direct']);
        $this->assertEquals('published', $mat['status']);

        // Check DB row
        $row = DB::table('edu_lesson_materials')->where('id', $mat['id'])->first();
        $this->assertNull($row->lesson_id);
        $this->assertEquals(7, $row->grade);
        $this->assertEquals($catId, $row->category_id);

        // Update direct material
        $updated = EduLearning::updateMaterial($this->adminActx, (int) $mat['id'], [
            'title' => 'Grade 7 Reference Book (Revised)',
        ]);
        $this->assertEquals('Grade 7 Reference Book (Revised)', $updated['title']);

        // List direct materials
        $list = EduLearning::directMaterials($this->adminAuth, $catId, 7);
        $this->assertCount(1, $list);
        $this->assertEquals($mat['id'], $list[0]['id']);

        // Delete direct material
        EduLearning::deleteMaterial($this->adminActx, (int) $mat['id']);
        $this->assertNull(DB::table('edu_lesson_materials')->where('id', $mat['id'])->first());
    }

    public function test_lesson_based_material_creation_preserves_lesson_association(): void
    {
        $catId = DB::table('edu_categories')->insertGetId(['name' => 'Bible Study', 'is_active' => true]);
        $subId = DB::table('edu_subjects')->insertGetId(['category_id' => $catId, 'name' => 'Old Testament', 'status' => 'published']);
        $unitId = DB::table('edu_units')->insertGetId(['subject_id' => $subId, 'title' => 'Genesis']);
        $lessonId = DB::table('edu_lessons')->insertGetId(['subject_id' => $subId, 'unit_id' => $unitId, 'title' => 'Creation Day 1', 'status' => 'published']);

        // Add lesson-based material
        $mat = EduLearning::addMaterialLink($this->adminActx, $lessonId, [
            'title' => 'Creation Diagram',
            'url' => 'https://example.com/diagram.png',
            'kind' => 'link',
        ]);

        $this->assertEquals($lessonId, $mat['lesson_id']);
        $this->assertFalse($mat['is_direct']);
    }

    // =========================================================================
    // FEATURE C TESTS: Admin Assigned Grade Restriction vs Admin Panel All Grades
    // =========================================================================

    public function test_admin_restricted_to_assigned_grade_in_normal_education_view(): void
    {
        $catId = DB::table('edu_categories')->insertGetId(['name' => 'Church History', 'is_active' => true]);
        $subId = DB::table('edu_subjects')->insertGetId(['category_id' => $catId, 'name' => 'Ethiopian Church History', 'status' => 'published']);

        $classG5 = DB::table('edu_classes')->insertGetId([
            'name' => '5ኛ ክፍል - ሀ',
            'level_id' => 5,
            'status' => 'active',
        ]);

        $classG6 = DB::table('edu_classes')->insertGetId([
            'name' => '6ኛ ክፍል - ሀ',
            'level_id' => 6,
            'status' => 'active',
        ]);

        // Enroll Admin in Class Grade 5 only
        DB::table('edu_enrollments')->insert([
            'class_id' => $classG5,
            'user_id' => $this->adminAuth->id,
            'status' => 'active',
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // Create course for G5 and G6
        DB::table('edu_courses')->insert([
            ['class_id' => $classG5, 'subject_id' => $subId, 'name' => 'History G5', 'status' => 'active'],
            ['class_id' => $classG6, 'subject_id' => $subId, 'name' => 'History G6', 'status' => 'active'],
        ]);

        // Normal Education catalog view: subjectGrades
        $gradesOverview = EduLearning::subjectGrades($this->adminAuth, $subId);
        $this->assertTrue($gradesOverview['has_assigned_grade']);

        // Verify Grade 5 is accessible, but Grade 6 is not accessible
        $g5Item = collect($gradesOverview['grades'])->firstWhere('number', 5);
        $g6Item = collect($gradesOverview['grades'])->firstWhere('number', 6);

        $this->assertTrue($g5Item['is_assigned']);
        $this->assertTrue($g5Item['can_open']);
        $this->assertFalse($g6Item['is_assigned']);
        $this->assertFalse($g6Item['can_open']);

        // Direct content access to Grade 5 succeeds
        $contentG5 = EduLearning::subjectGradeContent($this->adminAuth, $subId, 5);
        $this->assertIsArray($contentG5);

        // Direct content access to Grade 6 in normal view is REJECTED with GRADE_ACCESS_DENIED
        try {
            EduLearning::subjectGradeContent($this->adminAuth, $subId, 6);
            $this->fail('Expected GRADE_ACCESS_DENIED for Grade 6 in normal Education view');
        } catch (ApiError $e) {
            $this->assertEquals('GRADE_ACCESS_DENIED', $e->errorCode);
        }
    }

    public function test_education_admin_panel_allows_managing_all_canonical_grades(): void
    {
        // Admin panel grades endpoint
        $adminGrades = EduAcademicYears::adminGrades($this->adminAuth);
        $this->assertCount(12, $adminGrades);
        $this->assertEquals(1, $adminGrades[0]['sort_order']);
        $this->assertEquals(12, $adminGrades[11]['sort_order']);

        // Student is forbidden from accessing admin grades
        try {
            EduAcademicYears::adminGrades($this->studentAuth1);
            $this->fail('Expected NOT_CONTENT_EDITOR for student calling admin grades endpoint');
        } catch (ApiError $e) {
            $this->assertEquals('NOT_CONTENT_EDITOR', $e->errorCode);
        }

        // Admin can read grade detail
        $detail = EduAcademicYears::getGradeDetail($this->adminAuth, 8);
        $this->assertEquals(8, $detail['sort_order']);
        $this->assertEquals('8ኛ ክፍል', $detail['name']);
    }

    // =========================================================================
    // FEATURE D TESTS: Google Classroom-Style Assignments
    // =========================================================================

    public function test_assignment_lifecycle_creation_submission_grading_and_privacy(): void
    {
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => '10ኛ ክፍል',
            'level_id' => 10,
            'status' => 'active',
        ]);

        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'name' => '10th Liturgy',
            'teacher_user_id' => $this->teacherAuth->id,
            'status' => 'active',
        ]);

        // Assign teacher
        DB::table('edu_course_teachers')->insert([
            'course_id' => $courseId,
            'user_id' => $this->teacherAuth->id,
            'status' => 'active',
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // Enroll Student 1 and Student 2
        DB::table('edu_enrollments')->insert([
            ['class_id' => $classId, 'user_id' => $this->studentAuth1->id, 'status' => 'active', 'created_at' => Dates::now(), 'updated_at' => Dates::now()],
            ['class_id' => $classId, 'user_id' => $this->studentAuth2->id, 'status' => 'active', 'created_at' => Dates::now(), 'updated_at' => Dates::now()],
        ]);
        DB::table('edu_course_enrollments')->insert([
            ['course_id' => $courseId, 'user_id' => $this->studentAuth1->id, 'status' => 'enrolled', 'created_at' => Dates::now(), 'updated_at' => Dates::now()],
            ['course_id' => $courseId, 'user_id' => $this->studentAuth2->id, 'status' => 'enrolled', 'created_at' => Dates::now(), 'updated_at' => Dates::now()],
        ]);

        // 1. Teacher creates draft assignment -> not visible to student
        $draft = EduAssignments::create($this->teacherActx, [
            'course_id' => $courseId,
            'title' => 'Liturgy Paper Draft',
            'instructions' => 'Write an essay on the Divine Liturgy',
            'max_score' => 100,
            'due_at' => date('Y-m-d H:i:s', time() + 86400 * 5),
            'status' => 'draft',
        ]);
        $this->assertEquals('draft', $draft['status']);

        $studentList = EduAssignments::studentList($this->studentAuth1, $courseId);
        $this->assertCount(0, $studentList);

        // 2. Publish assignment -> visible to student
        $pub = EduAssignments::update($this->teacherActx, (int) $draft['id'], [
            'status' => 'published',
        ]);
        $this->assertEquals('published', $pub['status']);

        $studentList = EduAssignments::studentList($this->studentAuth1, $courseId);
        $this->assertCount(1, $studentList);
        $this->assertEquals('upcoming', $studentList[0]['status_group']);

        // 3. Student 1 submits work
        $sub = EduAssignments::submit($this->studentAuth1, (int) $draft['id'], [
            'text_response' => 'Here is my complete research paper on the Divine Liturgy.',
        ]);
        $this->assertEquals('submitted', $sub['status']);

        // Student 1 view shows 'turned_in'
        $studentListAfterSub = EduAssignments::studentList($this->studentAuth1, $courseId);
        $this->assertEquals('turned_in', $studentListAfterSub[0]['status_group']);

        // Student 2 has NOT submitted, still sees 'upcoming'
        $student2List = EduAssignments::studentList($this->studentAuth2, $courseId);
        $this->assertEquals('upcoming', $student2List[0]['status_group']);

        // 4. Teacher reviews submissions
        $subs = EduAssignments::listSubmissions($this->teacherAuth, (int) $draft['id']);
        $this->assertCount(1, $subs);
        $this->assertEquals($this->studentAuth1->id, $subs[0]['user_id']);

        // 5. Grading with invalid score (> max_score) fails
        try {
            EduAssignments::gradeSubmission($this->teacherActx, (int) $subs[0]['id'], 120.0, 'Beyond maximum');
            $this->fail('Expected SCORE_OUT_OF_RANGE for score > max_score');
        } catch (ApiError $e) {
            $this->assertEquals('VALIDATION_ERROR', $e->errorCode);
        }

        // 6. Teacher grades with score 95 and releases
        $graded = EduAssignments::gradeSubmission($this->teacherActx, (int) $subs[0]['id'], 95.0, 'Excellent analysis and citations!', true);
        $this->assertEquals(95, (float) $graded['score']);
        $this->assertNotNull($graded['released_at']);

        // Student 1 now sees 'graded' and score
        $studentDetail = EduAssignments::studentDetail($this->studentAuth1, (int) $draft['id']);
        $this->assertNotNull($studentDetail['my_submission']);
        $this->assertEquals(95, (float) $studentDetail['my_submission']['score']);
        $this->assertEquals('Excellent analysis and citations!', $studentDetail['my_submission']['feedback']);

        $studentListGraded = EduAssignments::studentList($this->studentAuth1, $courseId);
        $this->assertEquals('graded', $studentListGraded[0]['status_group']);

        // Unauthorized teacher cannot grade or access assignments of other courses
        $otherTeacher = $this->makeAuth(99, 'Other Teacher', []);
        try {
            EduAssignments::gradeSubmission(['auth' => $otherTeacher], (int) $subs[0]['id'], 50.0);
            $this->fail('Expected NOT_ASSIGNMENT_TEACHER for unauthorized teacher');
        } catch (ApiError $e) {
            $this->assertEquals('NOT_ASSIGNMENT_TEACHER', $e->errorCode);
        }
    }

    // =========================================================================
    // FEATURE E TESTS: Teacher Announcements
    // =========================================================================

    public function test_teacher_announcements_creation_and_student_feed(): void
    {
        $classId = DB::table('edu_classes')->insertGetId([
            'name' => '11ኛ ክፍል',
            'level_id' => 11,
            'status' => 'active',
        ]);

        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'name' => '11th Church History',
            'teacher_user_id' => $this->teacherAuth->id,
            'status' => 'active',
        ]);

        DB::table('edu_course_teachers')->insert([
            'course_id' => $courseId,
            'user_id' => $this->teacherAuth->id,
            'status' => 'active',
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // Enroll Student 1 in Class 11
        DB::table('edu_enrollments')->insert([
            'class_id' => $classId,
            'user_id' => $this->studentAuth1->id,
            'status' => 'active',
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);
        DB::table('edu_course_enrollments')->insert([
            'course_id' => $courseId,
            'user_id' => $this->studentAuth1->id,
            'status' => 'enrolled',
            'created_at' => Dates::now(),
            'updated_at' => Dates::now(),
        ]);

        // 1. Teacher creates draft announcement -> hidden from student feed
        $draft = EduAnnouncements::create($this->teacherActx, [
            'course_id' => $courseId,
            'title' => 'Midterm Review Notice',
            'body' => 'We will hold a review session tomorrow.',
            'status' => 'draft',
        ]);

        $feed = EduAnnouncements::feed($this->studentAuth1, $courseId);
        $this->assertCount(0, $feed);

        // 2. Publish announcement -> student sees it
        EduAnnouncements::update($this->teacherActx, (int) $draft['id'], [
            'status' => 'published',
        ]);

        $feedPublished = EduAnnouncements::feed($this->studentAuth1, $courseId);
        $this->assertCount(1, $feedPublished);
        $this->assertEquals('Midterm Review Notice', $feedPublished[0]['title']);

        // 3. Student 2 (not enrolled in class 11) cannot see the announcement
        $feedStudent2 = EduAnnouncements::feed($this->studentAuth2, $courseId);
        $this->assertCount(0, $feedStudent2);

        // 4. Notification was created for Student 1
        $notif = DB::table('notifications')->where(['user_id' => $this->studentAuth1->id, 'entity_type' => 'edu_announcement'])->first();
        $this->assertNotNull($notif);
        $this->assertStringContainsString('Midterm Review Notice', $notif->title);
    }
}
