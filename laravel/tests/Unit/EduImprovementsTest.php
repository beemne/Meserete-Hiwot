<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduRegistration;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduImprovementsTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $studentAuth;
    private array $adminActx;
    private array $studentActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin', ['education.manage' => true, 'education.content' => true, 'education.register' => true]);
        $this->studentAuth = $this->makeAuth(2, 'Student', []);

        $this->adminActx = ['auth' => $this->adminAuth];
        $this->studentActx = ['auth' => $this->studentAuth];
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
        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->unsignedBigInteger('role_id')->nullable();
                $table->string('member_group')->nullable();
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
                $table->string('term')->nullable();
                $table->unsignedBigInteger('academic_year_id')->nullable();
                $table->unsignedBigInteger('term_id')->nullable();
                $table->unsignedBigInteger('level_id')->nullable();
                $table->string('status')->default('active');
                $table->integer('capacity')->nullable();
                $table->boolean('allow_regular')->default(true);
                $table->boolean('allow_distance')->default(true);
                $table->boolean('allow_multiple')->default(false);
                $table->boolean('allow_self_registration')->default(false);
                $table->datetime('registration_opens_at')->nullable();
                $table->datetime('registration_closes_at')->nullable();
                $table->string('semester')->nullable();
                $table->unsignedBigInteger('department_id')->nullable();
                $table->string('streams')->nullable();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
                $table->string('image')->nullable();
                $table->string('icon_key')->nullable();
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
                $table->string('code')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
                $table->text('objectives')->nullable();
                $table->text('objectives_en')->nullable();
                $table->string('cover_image')->nullable();
                $table->string('visibility')->default('members');
                $table->boolean('sequential')->default(true);
                $table->string('status')->default('published');
                $table->integer('sort_order')->default(0);
                $table->unsignedBigInteger('created_by')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_units')) {
            Schema::create('edu_units', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
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
                $table->text('summary_en')->nullable();
                $table->longText('body')->nullable();
                $table->longText('body_en')->nullable();
                $table->text('scripture_refs')->nullable();
                $table->text('objectives')->nullable();
                $table->text('objectives_en')->nullable();
                $table->text('teacher_notes')->nullable();
                $table->integer('est_minutes')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->datetime('published_at')->nullable();
                $table->unsignedBigInteger('author_id')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->boolean('is_mandatory')->default(true);
                $table->boolean('requires_quiz')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->id();
                $table->unsignedBigInteger('lesson_id');
                $table->string('kind')->default('link');
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('description')->nullable();
                $table->text('description_en')->nullable();
                $table->string('path')->nullable();
                $table->string('original_name')->nullable();
                $table->string('mime')->nullable();
                $table->integer('size')->nullable();
                $table->string('url')->nullable();
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_progress')) {
            Schema::create('edu_lesson_progress', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('lesson_id');
                $table->datetime('last_opened_at')->nullable();
                $table->datetime('completed_at')->nullable();
                $table->boolean('bookmarked')->default(false);
                $table->timestamps();
                $table->unique(['user_id', 'lesson_id']);
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('academic_year_id')->nullable();
                $table->boolean('exclusive')->default(true);
                $table->string('program')->default('regular');
                $table->string('stream')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
                $table->unique(['class_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('name');
                $table->string('status')->default('active');
                $table->unsignedBigInteger('teacher_user_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id')->nullable();
                $table->unsignedBigInteger('lesson_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('instructions')->nullable();
                $table->text('instructions_en')->nullable();
                $table->string('status')->default('published');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('added');
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

        if (! Schema::hasTable('roles')) {
            Schema::create('roles', function ($table) {
                $table->id();
                $table->string('name');
                $table->boolean('is_hidden')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_audit_log')) {
            Schema::create('edu_audit_log', function ($table) {
                $table->id();
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->text('details')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_journey')) {
            Schema::create('edu_journey', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('event');
                $table->unsignedBigInteger('class_id')->nullable();
                $table->unsignedBigInteger('course_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->unsignedBigInteger('ref_id')->nullable();
                $table->string('ref_type')->nullable();
                $table->string('old_value')->nullable();
                $table->string('new_value')->nullable();
                $table->string('reason')->nullable();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->boolean('is_hidden')->default(false);
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->text('metadata')->nullable();
                $table->string('ip')->nullable();
                $table->string('user_agent')->nullable();
                $table->timestamps();
            });
        }
    }

    public function test_admin_can_create_unit_with_bilingual_fields(): void
    {
        $subjectId = DB::table('edu_subjects')->insertGetId([
            'name' => 'ክርስቲያናዊ ሕይወት',
            'name_en' => 'Christian Life',
            'visibility' => 'members',
            'status' => 'published',
            'sequential' => 1,
        ]);

        $res = EduLearning::createUnit($this->adminActx, $subjectId, [
            'title' => 'ምዕራፍ አንድ',
            'title_en' => 'Unit One: Fundamentals',
            'description' => 'የመጀመሪያው ምዕራፍ ማብራሪያ',
            'description_en' => 'Overview of fundamentals',
            'status' => 'published',
        ]);

        $this->assertArrayHasKey('id', $res);
        $this->assertArrayHasKey('unit', $res);
        $this->assertEquals('ምዕራፍ አንድ', $res['unit']['title']);
        $this->assertEquals('Unit One: Fundamentals', $res['unit']['title_en']);

        // Verify database persistence
        $row = DB::table('edu_units')->where('id', $res['id'])->first();
        $this->assertNotNull($row);
        $this->assertEquals('ምዕራፍ አንድ', $row->title);
        $this->assertEquals('Unit One: Fundamentals', $row->title_en);
    }

    public function test_unauthorized_user_cannot_create_unit(): void
    {
        $subjectId = DB::table('edu_subjects')->insertGetId([
            'name' => 'ነገረ መለኮት',
            'visibility' => 'members',
            'status' => 'published',
        ]);

        $this->expectException(ApiError::class);
        EduLearning::createUnit($this->studentActx, $subjectId, [
            'title' => 'አዲስ ምዕራፍ',
        ]);
    }

    public function test_sequential_lesson_unlocking_behavior(): void
    {
        $subjectId = DB::table('edu_subjects')->insertGetId([
            'name' => 'ስርዓተ ቤተክርስቲያን',
            'visibility' => 'members',
            'status' => 'published',
            'sequential' => 1,
        ]);

        $lesson1 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjectId,
            'title' => 'ትምህርት 1',
            'sort_order' => 1,
            'status' => 'published',
            'is_mandatory' => 1,
        ]);

        $lesson2 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subjectId,
            'title' => 'ትምህርት 2',
            'sort_order' => 2,
            'status' => 'published',
            'is_mandatory' => 1,
        ]);

        // Student can open Lesson 1
        $d1 = EduLearning::lessonDetail($this->studentAuth, $lesson1);
        $this->assertEquals('ትምህርት 1', $d1['title']);

        // Student is blocked from directly opening Lesson 2 before completing Lesson 1
        $blocked = false;
        try {
            EduLearning::lessonDetail($this->studentAuth, $lesson2);
        } catch (ApiError $e) {
            $blocked = true;
            $this->assertEquals('LESSON_LOCKED', $e->errorCode);
        }
        $this->assertTrue($blocked, 'Lesson 2 must be locked until Lesson 1 is complete');

        // Admin can inspect / preview Lesson 2 without progression blocks
        $adminDetail = EduLearning::lessonDetail($this->adminAuth, $lesson2);
        $this->assertEquals('ትምህርት 2', $adminDetail['title']);

        // Student completes Lesson 1
        EduLearning::setProgress($this->studentAuth, $lesson1, 'complete');

        // Now Lesson 2 unlocks for the student
        $d2 = EduLearning::lessonDetail($this->studentAuth, $lesson2);
        $this->assertEquals('ትምህርት 2', $d2['title']);
    }

    public function test_class_self_enrollment_disabled_by_default(): void
    {
        DB::table('users')->insertOrIgnore([
            'id' => $this->studentAuth->id,
            'full_name' => 'Student User',
            'status' => 'active',
            'account_type' => 'user',
        ]);

        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'የመጀመሪያ ደረጃ ክፍል',
            'status' => 'active',
            'allow_regular' => 1,
            'allow_self_registration' => 0, // default disabled
        ]);

        // Student attempting self-enrollment must be rejected
        $rejected = false;
        try {
            Edu::enroll($this->studentAuth, $classId, 'regular');
        } catch (ApiError $e) {
            $rejected = true;
            $this->assertEquals('SELF_REGISTRATION_DISABLED', $e->errorCode);
        }
        $this->assertTrue($rejected, 'Self enrollment must be disabled by default');

        // Registrar / Admin assigns student to class
        $res = EduRegistration::register($this->adminActx, [
            'class_id' => $classId,
            'user_ids' => [$this->studentAuth->id],
            'program' => 'regular',
        ]);
        $this->assertEquals(1, $res['registered']);
        $this->assertNotEmpty($res['students']);
        $this->assertEquals($this->studentAuth->id, $res['students'][0]['id']);

        // Verify enrollment is active
        $this->assertTrue(DB::table('edu_enrollments')->where(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active'])->exists());
    }
}
