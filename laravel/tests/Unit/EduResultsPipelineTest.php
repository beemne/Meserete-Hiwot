<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduMarks;
use App\Mz\Services\EduOutcomes;
use App\Mz\Services\EduQuizzes;
use App\Mz\Services\EduRetakes;
use App\Mz\Services\ReportExport;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduResultsPipelineTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $teacherAuth;
    private AuthContext $studentAuth;
    private AuthContext $otherStudentAuth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin User', ['education.manage' => true, 'reports.view' => true]);
        $this->teacherAuth = $this->makeAuth(2, 'Teacher One', []);
        $this->studentAuth = $this->makeAuth(10, 'Student Abebe', []);
        $this->otherStudentAuth = $this->makeAuth(11, 'Student Kebede', []);
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
                $table->string('member_group')->default('youth_adult');
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
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
                $table->string('slug')->nullable();
                $table->string('image')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('published');
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
                $table->string('slug')->nullable();
                $table->string('code')->nullable();
                $table->text('description')->nullable();
                $table->string('cover_image')->nullable();
                $table->string('visibility')->default('enrolled');
                $table->boolean('sequential')->default(false);
                $table->string('status')->default('published');
                $table->boolean('is_active')->default(true);
                $table->integer('sort_order')->default(0);
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
                $table->string('status')->default('published');
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
                $table->text('summary_en')->nullable();
                $table->text('body')->nullable();
                $table->text('body_en')->nullable();
                $table->string('video_url')->nullable();
                $table->integer('est_minutes')->nullable();
                $table->integer('duration_minutes')->nullable();
                $table->tinyInteger('is_mandatory')->default(1);
                $table->boolean('requires_quiz')->default(false);
                $table->string('status')->default('published');
                $table->dateTime('published_at')->nullable();
                $table->text('scripture_refs')->nullable();
                $table->text('objectives')->nullable();
                $table->text('objectives_en')->nullable();
                $table->text('teacher_notes')->nullable();
                $table->unsignedBigInteger('author_id')->nullable();
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->id();
                $table->unsignedBigInteger('lesson_id');
                $table->string('title');
                $table->string('type')->default('link');
                $table->string('url')->nullable();
                $table->string('file')->nullable();
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_progress')) {
            Schema::create('edu_lesson_progress', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('lesson_id');
                $table->boolean('is_completed')->default(false);
                $table->dateTime('completed_at')->nullable();
                $table->dateTime('last_opened_at')->nullable();
                $table->boolean('bookmarked')->default(false);
                $table->timestamps();
                $table->unique(['user_id', 'lesson_id']);
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->unsignedBigInteger('academic_year_id')->nullable();
                $table->unsignedBigInteger('level_id')->nullable();
                $table->string('program')->default('regular');
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->unsignedBigInteger('teacher_user_id')->nullable();
                $table->string('name')->default('Test Course');
                $table->string('mode')->default('in_person');
                $table->decimal('pass_mark', 5, 2)->default(50.00);
                $table->string('status')->default('active');
                $table->string('member_groups')->nullable();
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
                $table->string('program')->default('regular');
                $table->timestamps();
                $table->unique(['class_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('enrolled');
                $table->unsignedBigInteger('changed_by')->nullable();
                $table->timestamps();
                $table->unique(['course_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_assignments')) {
            Schema::create('edu_assignments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('title');
                $table->text('instructions')->nullable();
                $table->dateTime('due_at')->nullable();
                $table->dateTime('publish_at')->nullable();
                $table->string('late_policy')->default('refuse');
                $table->dateTime('late_until')->nullable();
                $table->tinyInteger('allow_resubmit')->default(1);
                $table->text('target_user_ids')->nullable();
                $table->string('status')->default('published');
                $table->decimal('max_score', 6, 2)->default(100);
                $table->boolean('is_group')->default(false);
                $table->string('file')->nullable();
                $table->string('file_name')->nullable();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_submissions')) {
            Schema::create('edu_submissions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('assignment_id');
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('group_id')->nullable();
                $table->text('text')->nullable();
                $table->string('file')->nullable();
                $table->string('file_name')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->tinyInteger('is_late')->default(0);
                $table->decimal('score', 6, 2)->nullable();
                $table->text('feedback')->nullable();
                $table->unsignedBigInteger('graded_by')->nullable();
                $table->dateTime('graded_at')->nullable();
                $table->timestamps();
                $table->unique(['assignment_id', 'user_id']);
            });
        }

        if (! Schema::hasTable('edu_submission_versions')) {
            Schema::create('edu_submission_versions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('submission_id');
                $table->text('text')->nullable();
                $table->string('file')->nullable();
                $table->string('file_name')->nullable();
                $table->dateTime('submitted_at');
                $table->tinyInteger('is_late')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assessments')) {
            Schema::create('edu_assessments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('title');
                $table->decimal('max_score', 6, 2)->default(100);
                $table->decimal('weight', 5, 2)->default(100);
                $table->date('held_on')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_scores')) {
            Schema::create('edu_scores', function ($table) {
                $table->id();
                $table->unsignedBigInteger('assessment_id');
                $table->unsignedBigInteger('user_id');
                $table->decimal('score', 6, 2)->nullable();
                $table->string('remark')->nullable();
                $table->string('status')->default('draft');
                $table->unsignedInteger('attempt')->default(1);
                $table->unsignedBigInteger('recorded_by')->nullable();
                $table->unsignedBigInteger('submitted_by')->nullable();
                $table->dateTime('submitted_at')->nullable();
                $table->unsignedBigInteger('approved_by')->nullable();
                $table->dateTime('approved_at')->nullable();
                $table->unsignedBigInteger('published_by')->nullable();
                $table->dateTime('published_at')->nullable();
                $table->timestamps();
                $table->unique(['assessment_id', 'user_id', 'attempt']);
            });
        }

        if (! Schema::hasTable('edu_score_history')) {
            Schema::create('edu_score_history', function ($table) {
                $table->id();
                $table->unsignedBigInteger('score_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->unsignedBigInteger('user_id')->nullable();
                $table->string('action')->nullable();
                $table->decimal('old_score', 6, 2)->nullable();
                $table->decimal('new_score', 6, 2)->nullable();
                $table->string('old_status')->nullable();
                $table->string('new_status')->nullable();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->string('reason')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_outcomes')) {
            Schema::create('edu_course_outcomes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('attempt_type')->default('original');
                $table->unsignedBigInteger('retake_id')->nullable();
                $table->decimal('percent', 5, 2)->default(0);
                $table->decimal('pass_mark', 5, 2)->default(50);
                $table->string('result')->default('incomplete');
                $table->string('status')->default('provisional');
                $table->tinyInteger('counts_for_progression')->default(1);
                $table->unsignedBigInteger('finalized_by')->nullable();
                $table->dateTime('finalized_at')->nullable();
                $table->text('note')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_retakes')) {
            Schema::create('edu_retakes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('original_outcome_id');
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('course_id');
                $table->string('status')->default('requested');
                $table->unsignedBigInteger('requested_by');
                $table->unsignedBigInteger('decided_by')->nullable();
                $table->dateTime('decided_at')->nullable();
                $table->text('decision_note')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_question_banks')) {
            Schema::create('edu_question_banks', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id');
                $table->string('title');
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('lesson_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->string('kind')->default('quiz');
                $table->string('title');
                $table->text('description')->nullable();
                $table->dateTime('opens_at')->nullable();
                $table->dateTime('closes_at')->nullable();
                $table->dateTime('results_release_at')->nullable();
                $table->integer('time_limit_minutes')->nullable();
                $table->integer('max_attempts')->default(1);
                $table->string('scoring')->default('best');
                $table->boolean('shuffle')->default(false);
                $table->string('review_policy')->default('after_submission');
                $table->string('status')->default('published');
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_questions')) {
            Schema::create('edu_quiz_questions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id')->nullable();
                $table->unsignedBigInteger('bank_id')->nullable();
                $table->string('type')->default('single');
                $table->text('prompt');
                $table->text('options')->nullable();
                $table->text('answer')->nullable();
                $table->text('explanation')->nullable();
                $table->decimal('points', 6, 2)->default(1);
                $table->integer('sort_order')->default(0);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_draws')) {
            Schema::create('edu_quiz_draws', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->unsignedBigInteger('bank_id');
                $table->integer('count');
                $table->decimal('points_each', 6, 2)->nullable();
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
                $table->dateTime('started_at');
                $table->dateTime('submitted_at')->nullable();
                $table->dateTime('completed_at')->nullable();
                $table->dateTime('expires_at')->nullable();
                $table->decimal('auto_score', 6, 2)->nullable();
                $table->decimal('manual_score', 6, 2)->nullable();
                $table->decimal('total_score', 6, 2)->nullable();
                $table->decimal('max_score', 6, 2)->nullable();
                $table->text('answers')->nullable();
                $table->text('question_ids')->nullable();
                $table->boolean('needs_grading')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_answers')) {
            Schema::create('edu_quiz_answers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('attempt_id');
                $table->unsignedBigInteger('question_id');
                $table->text('response')->nullable();
                $table->boolean('is_correct')->nullable();
                $table->decimal('points_awarded', 6, 2)->nullable();
                $table->timestamps();
                $table->unique(['attempt_id', 'question_id']);
            });
        }

        if (! Schema::hasTable('programs')) {
            Schema::create('programs', function ($table) {
                $table->id();
                $table->string('title');
                $table->string('program_type')->default('regular');
                $table->text('schedule')->nullable();
                $table->text('recurrence')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_edu_courses')) {
            Schema::create('program_edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('program_id');
                $table->unsignedBigInteger('course_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_groups')) {
            Schema::create('edu_groups', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_group_members')) {
            Schema::create('edu_group_members', function ($table) {
                $table->id();
                $table->unsignedBigInteger('group_id');
                $table->unsignedBigInteger('user_id');
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
                $table->string('ref_type')->nullable();
                $table->unsignedBigInteger('ref_id')->nullable();
                $table->string('old_value')->nullable();
                $table->string('new_value')->nullable();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->text('reason')->nullable();
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

        // Clean tables between tests
        DB::table('users')->truncate();
        DB::table('edu_categories')->truncate();
        DB::table('edu_subjects')->truncate();
        DB::table('edu_units')->truncate();
        DB::table('edu_lessons')->truncate();
        DB::table('edu_lesson_materials')->truncate();
        DB::table('edu_lesson_progress')->truncate();
        DB::table('edu_classes')->truncate();
        DB::table('edu_courses')->truncate();
        DB::table('edu_course_teachers')->truncate();
        DB::table('edu_enrollments')->truncate();
        DB::table('edu_course_enrollments')->truncate();
        DB::table('edu_assignments')->truncate();
        DB::table('edu_submissions')->truncate();
        DB::table('edu_submission_versions')->truncate();
        DB::table('edu_assessments')->truncate();
        DB::table('edu_scores')->truncate();
        DB::table('edu_score_history')->truncate();
        DB::table('edu_course_outcomes')->truncate();
        DB::table('edu_retakes')->truncate();
        DB::table('edu_question_banks')->truncate();
        DB::table('edu_quizzes')->truncate();
        DB::table('edu_quiz_questions')->truncate();
        DB::table('edu_quiz_draws')->truncate();
        DB::table('edu_quiz_attempts')->truncate();
        DB::table('edu_quiz_answers')->truncate();
        DB::table('programs')->truncate();
        DB::table('program_edu_courses')->truncate();
        DB::table('edu_groups')->truncate();
        DB::table('edu_group_members')->truncate();
        DB::table('edu_journey')->truncate();
        DB::table('audit_logs')->truncate();

        // Seed basic users
        DB::table('users')->insert([
            ['id' => 1, 'full_name' => 'Admin User', 'member_no' => 'M001', 'member_group' => 'youth_adult', 'status' => 'active', 'account_type' => 'admin'],
            ['id' => 2, 'full_name' => 'Teacher One', 'member_no' => 'T001', 'member_group' => 'youth_adult', 'status' => 'active', 'account_type' => 'user'],
            ['id' => 3, 'full_name' => 'Teacher Two', 'member_no' => 'T002', 'member_group' => 'youth_adult', 'status' => 'active', 'account_type' => 'user'],
            ['id' => 10, 'full_name' => 'Student Abebe', 'member_no' => 'S010', 'member_group' => 'youth_adult', 'status' => 'active', 'account_type' => 'user'],
            ['id' => 11, 'full_name' => 'Student Kebede', 'member_no' => 'S011', 'member_group' => 'youth_adult', 'status' => 'active', 'account_type' => 'user'],
        ]);
    }

    // =========================================================================
    // F8: ONLINE LEARNING GAPS
    // =========================================================================

    public function test_f8_mandatory_lesson_completion_and_sequential_unlock(): void
    {
        $catId = DB::table('edu_categories')->insertGetId(['name' => 'Theology', 'status' => 'published']);
        $subId = DB::table('edu_subjects')->insertGetId([
            'category_id' => $catId,
            'name' => 'Church History',
            'visibility' => 'enrolled',
            'sequential' => 1,
            'status' => 'published',
        ]);
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class A']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subId,
            'name' => 'Online Church History',
            'mode' => 'online',
        ]);

        $unitId = DB::table('edu_units')->insertGetId(['subject_id' => $subId, 'title' => 'Unit 1', 'status' => 'published']);

        // Lesson 1: Mandatory
        $l1 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subId,
            'unit_id' => $unitId,
            'title' => 'Lesson 1 (Mandatory)',
            'is_mandatory' => 1,
            'status' => 'published',
            'sort_order' => 1,
        ]);
        // Lesson 2: Optional
        $l2 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subId,
            'unit_id' => $unitId,
            'title' => 'Lesson 2 (Optional Extra)',
            'is_mandatory' => 0,
            'status' => 'published',
            'sort_order' => 2,
        ]);
        // Lesson 3: Mandatory
        $l3 = DB::table('edu_lessons')->insertGetId([
            'subject_id' => $subId,
            'unit_id' => $unitId,
            'title' => 'Lesson 3 (Mandatory)',
            'is_mandatory' => 1,
            'status' => 'published',
            'sort_order' => 3,
        ]);

        // 1. Non-enrolled student gets 403 NOT_ENROLLED
        try {
            EduLearning::lessonDetail($this->studentAuth, $l1);
            $this->fail('Expected 403 NOT_ENROLLED for non-enrolled student');
        } catch (ApiError $e) {
            $this->assertSame(403, $e->status);
            $this->assertSame('NOT_ENROLLED', $e->errorCode);
        }

        // Enroll student in class
        DB::table('edu_enrollments')->insert([
            'class_id' => $classId,
            'user_id' => $this->studentAuth->id,
            'status' => 'active',
        ]);

        // Now enrolled, can open Lesson 1
        $detail1 = EduLearning::lessonDetail($this->studentAuth, $l1);
        $this->assertSame('Lesson 1 (Mandatory)', $detail1['title']);
        $this->assertTrue($detail1['is_mandatory']);

        // Lesson 3 is locked because Lesson 1 mandatory is not completed yet
        try {
            EduLearning::lessonDetail($this->studentAuth, $l3);
            $this->fail('Expected 409 LESSON_LOCKED for sequential lesson 3');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('LESSON_LOCKED', $e->errorCode);
        }

        // Initial course completion: 0 / 2 mandatory completed = 0%
        $comp = EduLearning::courseCompletion($this->studentAuth->id, $courseId);
        $this->assertSame(2, $comp['total']);
        $this->assertSame(0, $comp['completed']);
        $this->assertSame(0.0, (float) $comp['percent']);

        // Complete lesson 1
        EduLearning::setProgress($this->studentAuth, $l1, 'complete');

        // Course completion is now 1 / 2 = 50%
        $comp = EduLearning::courseCompletion($this->studentAuth->id, $courseId);
        $this->assertSame(1, $comp['completed']);
        $this->assertSame(50.0, (float) $comp['percent']);

        // Lesson 3 should now be UNLOCKED even though Lesson 2 (optional) was NOT completed!
        $detail3 = EduLearning::lessonDetail($this->studentAuth, $l3);
        $this->assertSame('Lesson 3 (Mandatory)', $detail3['title']);

        // Complete optional lesson 2 -> completion percent should NOT change (remains 50%)
        EduLearning::setProgress($this->studentAuth, $l2, 'complete');
        $comp = EduLearning::courseCompletion($this->studentAuth->id, $courseId);
        $this->assertSame(50.0, (float) $comp['percent']);

        // Complete lesson 3 -> 100%
        EduLearning::setProgress($this->studentAuth, $l3, 'complete');
        $comp = EduLearning::courseCompletion($this->studentAuth->id, $courseId);
        $this->assertSame(2, $comp['completed']);
        $this->assertSame(100.0, (float) $comp['percent']);
    }

    // =========================================================================
    // F9: ASSIGNMENTS
    // =========================================================================

    public function test_f9_assignment_publish_time_and_targeting(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class B']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Assignment Course',
        ]);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id]);

        // Enroll students
        DB::table('edu_enrollments')->insert([
            ['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active'],
            ['class_id' => $classId, 'user_id' => $this->otherStudentAuth->id, 'status' => 'active'],
        ]);

        // Create assignment with future publish_at
        $future = date('Y-m-d H:i:s', strtotime('+2 days'));
        $assignFuture = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Future Assignment',
            'publish_at' => $future,
            'due_at' => date('Y-m-d H:i:s', strtotime('+5 days')),
            'status' => 'published',
        ]);

        // Student tries to submit before publish_at -> 409 ASSIGNMENT_NOT_OPEN
        try {
            Edu::submit($this->studentAuth, $assignFuture['id'], 'My early solution', null);
            $this->fail('Expected ASSIGNMENT_NOT_OPEN');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('ASSIGNMENT_NOT_OPEN', $e->errorCode);
        }

        // Create assignment targeted ONLY to otherStudentAuth (id: 11)
        $targeted = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Targeted Assignment',
            'publish_at' => date('Y-m-d H:i:s', strtotime('-1 hour')),
            'due_at' => date('Y-m-d H:i:s', strtotime('+2 days')),
            'target_user_ids' => [$this->otherStudentAuth->id],
            'status' => 'published',
        ]);

        // studentAuth (id: 10) tries to submit -> 403 NOT_TARGETED
        try {
            Edu::submit($this->studentAuth, $targeted['id'], 'Unauthorized submission', null);
            $this->fail('Expected NOT_TARGETED for non-targeted student');
        } catch (ApiError $e) {
            $this->assertSame(403, $e->status);
            $this->assertSame('NOT_TARGETED', $e->errorCode);
        }

        // otherStudentAuth (id: 11) submits successfully
        $sub = Edu::submit($this->otherStudentAuth, $targeted['id'], 'Target student solution', null);
        $this->assertSame(11, (int) $sub['submission']['user_id']);
        $this->assertFalse((bool) $sub['submission']['is_late']);
    }

    public function test_f9_assignment_deadline_and_late_policy(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class C']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Policy Course',
        ]);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active']);

        // Assignment with late_policy = 'refuse' past due date
        $pastDue = date('Y-m-d H:i:s', strtotime('-2 hours'));
        $assignRefuse = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Strict Assignment',
            'publish_at' => date('Y-m-d H:i:s', strtotime('-1 day')),
            'due_at' => $pastDue,
            'late_policy' => 'refuse',
            'status' => 'published',
        ]);

        try {
            Edu::submit($this->studentAuth, $assignRefuse['id'], 'Late attempt', null);
            $this->fail('Expected DEADLINE_PASSED');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('DEADLINE_PASSED', $e->errorCode);
        }

        // Assignment with late_policy = 'accept_marked' past due date but within late_until
        $lateUntil = date('Y-m-d H:i:s', strtotime('+1 day'));
        $assignAcceptLate = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Flexible Assignment',
            'publish_at' => date('Y-m-d H:i:s', strtotime('-1 day')),
            'due_at' => $pastDue,
            'late_policy' => 'accept_marked',
            'late_until' => $lateUntil,
            'status' => 'published',
        ]);

        $subLate = Edu::submit($this->studentAuth, $assignAcceptLate['id'], 'Late accepted answer', null);
        $this->assertTrue((bool) $subLate['submission']['is_late']);

        // After late_until has passed -> DEADLINE_PASSED
        $pastLateUntil = date('Y-m-d H:i:s', strtotime('-1 hour'));
        $assignTooLate = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Expired Late Window',
            'due_at' => date('Y-m-d H:i:s', strtotime('-3 hours')),
            'late_policy' => 'accept_marked',
            'late_until' => $pastLateUntil,
            'status' => 'published',
        ]);

        try {
            Edu::submit($this->studentAuth, $assignTooLate['id'], 'Way too late', null);
            $this->fail('Expected DEADLINE_PASSED beyond late_until');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('DEADLINE_PASSED', $e->errorCode);
        }
    }

    public function test_f9_assignment_resubmit_and_version_history(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class D']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Version Course',
        ]);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active']);

        // 1. allow_resubmit = 0
        $noResubmit = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Single Submit Assignment',
            'allow_resubmit' => 0,
            'due_at' => date('Y-m-d H:i:s', strtotime('+2 days')),
            'status' => 'published',
        ]);
        Edu::submit($this->studentAuth, $noResubmit['id'], 'First attempt', null);

        try {
            Edu::submit($this->studentAuth, $noResubmit['id'], 'Second attempt', null);
            $this->fail('Expected RESUBMIT_NOT_ALLOWED');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('RESUBMIT_NOT_ALLOWED', $e->errorCode);
        }

        // 2. allow_resubmit = 1 (default)
        $withResubmit = Edu::createAssignment($this->teacherAuth, $courseId, [
            'title' => 'Multi-version Assignment',
            'allow_resubmit' => 1,
            'due_at' => date('Y-m-d H:i:s', strtotime('+2 days')),
            'status' => 'published',
        ]);

        // Submit v1
        $s1 = Edu::submit($this->studentAuth, $withResubmit['id'], 'Version 1 Draft', null);
        $subId = $s1['submission']['id'];

        // Submit v2
        $s2 = Edu::submit($this->studentAuth, $withResubmit['id'], 'Version 2 Final Revised', null);

        // Check versions endpoint (ordered newest first)
        $versions = Edu::submissionVersions($this->studentAuth, $subId);
        $this->assertCount(2, $versions);
        $this->assertSame('Version 2 Final Revised', $versions[0]['text']);
        $this->assertSame('Version 1 Draft', $versions[1]['text']);

        // Check non-course teacher getting 403 on create
        $unrelatedTeacher = $this->makeAuth(99, 'Unrelated Teacher', []);
        try {
            Edu::createAssignment($unrelatedTeacher, $courseId, ['title' => 'Hack Attempt']);
            $this->fail('Expected 403 NOT_TEACHER for unrelated teacher');
        } catch (ApiError $e) {
            $this->assertSame(403, $e->status);
            $this->assertSame('NOT_TEACHER', $e->errorCode);
        }
    }

    // =========================================================================
    // F10: COURSE OUTCOMES & PASS MARKS
    // =========================================================================

    public function test_f10_weighted_calculation_matches_hand_calculated_totals(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class E']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Outcomes Course',
            'pass_mark' => 50.00,
        ]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active']);

        // 3 assessments:
        // A1: weight 20, max 20, score 18 (90%) -> weighted = (18/20) * 20 = 18.0
        // A2: weight 30, max 50, score 40 (80%) -> weighted = (40/50) * 30 = 24.0
        // A3: weight 50, max 100, score 60 (60%) -> weighted = (60/100) * 50 = 30.0
        // Hand calculated total: (18.0 + 24.0 + 30.0) / 100 * 100 = 72.00%
        $a1 = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Quiz', 'weight' => 20, 'max_score' => 20]);
        $a2 = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Midterm', 'weight' => 30, 'max_score' => 50]);
        $a3 = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Final Exam', 'weight' => 50, 'max_score' => 100]);

        DB::table('edu_scores')->insert([
            ['assessment_id' => $a1, 'user_id' => $this->studentAuth->id, 'score' => 18, 'status' => 'published', 'attempt' => 1],
            ['assessment_id' => $a2, 'user_id' => $this->studentAuth->id, 'score' => 40, 'status' => 'published', 'attempt' => 1],
            // A3 score is in draft (unpublished!)
            ['assessment_id' => $a3, 'user_id' => $this->studentAuth->id, 'score' => 60, 'status' => 'draft', 'attempt' => 1],
        ]);

        // 1. Unpublished score: outcome must be INCOMPLETE
        $outcomes = EduOutcomes::compute($courseId);
        $this->assertCount(1, $outcomes);
        $this->assertSame('incomplete', $outcomes[0]['result']);
        $this->assertSame(0.0, (float) $outcomes[0]['percent']);

        // 2. Publish A3 score
        DB::table('edu_scores')
            ->where('assessment_id', $a3)
            ->where('user_id', $this->studentAuth->id)
            ->update(['status' => 'published']);

        // 3. Recompute: all published -> exactly 72.00%, result passed
        $outcomes = EduOutcomes::compute($courseId);
        $this->assertCount(1, $outcomes);
        $this->assertSame('passed', $outcomes[0]['result']);
        $this->assertEquals(72.00, (float) $outcomes[0]['percent']);
        $this->assertSame('provisional', $outcomes[0]['status']);
    }

    public function test_f10_finalization_and_amendment_superseding(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class F']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Amendment Course',
            'pass_mark' => 50.00,
        ]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active']);

        $a1 = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Final Test', 'weight' => 100, 'max_score' => 100]);
        $scoreId = DB::table('edu_scores')->insertGetId([
            'assessment_id' => $a1,
            'user_id' => $this->studentAuth->id,
            'score' => 65.0,
            'status' => 'published',
            'attempt' => 1,
        ]);

        // Compute provisional outcome
        EduOutcomes::compute($courseId);

        // Finalize outcome
        $fin = EduOutcomes::finalize($this->adminAuth, $courseId);
        $this->assertSame(1, $fin['finalized']);

        $saved = DB::table('edu_course_outcomes')->where('course_id', $courseId)->where('user_id', $this->studentAuth->id)->first();
        $this->assertSame('finalized', $saved->status);
        $this->assertSame(1, (int) $saved->finalized_by);

        // Amend score down to 40% (failed) via EduMarks::amend
        EduMarks::amend(['auth' => $this->adminAuth], $a1, $this->studentAuth->id, 40.0, 'Grading error found in paper');

        // Recompute: old finalized outcome must be marked 'superseded', new outcome created
        EduOutcomes::compute($courseId);

        $allOutcomes = DB::table('edu_course_outcomes')
            ->where('course_id', $courseId)
            ->where('user_id', $this->studentAuth->id)
            ->orderBy('id', 'asc')
            ->get();

        $this->assertCount(2, $allOutcomes);
        $this->assertSame('superseded', $allOutcomes[0]->status);
        $this->assertSame('passed', $allOutcomes[0]->result);
        $this->assertStringContainsString('amendment', strtolower($allOutcomes[0]->note));

        $this->assertSame('provisional', $allOutcomes[1]->status);
        $this->assertSame('failed', $allOutcomes[1]->result);
        $this->assertEquals(40.0, (float) $allOutcomes[1]->percent);
    }

    // =========================================================================
    // F11: FAILED COURSES & ONLINE RETAKES
    // =========================================================================

    public function test_f11_retake_request_eligibility_and_progression_counting(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class G']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Retake Course',
            'mode' => 'online',
            'pass_mark' => 50.00,
        ]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active']);

        $a1 = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Exam', 'weight' => 100, 'max_score' => 100]);
        DB::table('edu_scores')->insert([
            'assessment_id' => $a1,
            'user_id' => $this->studentAuth->id,
            'score' => 35.0, // Failed
            'status' => 'published',
            'attempt' => 1,
        ]);

        // Compute and finalize failed outcome
        EduOutcomes::compute($courseId);
        EduOutcomes::finalize($this->adminAuth, $courseId);

        $originalOutcome = DB::table('edu_course_outcomes')
            ->where('course_id', $courseId)
            ->where('user_id', $this->studentAuth->id)
            ->where('status', 'finalized')
            ->first();

        $this->assertSame('failed', $originalOutcome->result);

        // 1. Student requests retake on finalized failed outcome
        $retake = EduRetakes::request($this->studentAuth, $originalOutcome->id);
        $this->assertSame('requested', $retake['status']);

        // 2. Duplicate retake request throws 409 RETAKE_EXISTS
        try {
            EduRetakes::request($this->studentAuth, $originalOutcome->id);
            $this->fail('Expected RETAKE_EXISTS for duplicate request');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('RETAKE_EXISTS', $e->errorCode);
        }

        // 3. Admin decides: approve retake
        $approved = EduRetakes::decide($this->adminAuth, $retake['id'], 'approved', 'Approved online retake for semester 2');
        $this->assertSame('approved', $approved['status']);

        // Verification: edu_course_enrollments created with status 'retake'
        $enrollment = DB::table('edu_course_enrollments')
            ->where('course_id', $courseId)
            ->where('user_id', $this->studentAuth->id)
            ->first();
        $this->assertNotNull($enrollment);
        $this->assertSame('retake', $enrollment->status);

        // 4. Enter retake score with attempt = 2
        DB::table('edu_scores')->insert([
            'assessment_id' => $a1,
            'user_id' => $this->studentAuth->id,
            'score' => 75.0, // Passed retake!
            'status' => 'published',
            'attempt' => 2,
        ]);

        // 5. Compute outcomes: now computes retake outcome as passed!
        EduOutcomes::compute($courseId);
        EduOutcomes::finalize($this->adminAuth, $courseId);

        $retakeOutcome = DB::table('edu_course_outcomes')
            ->where('course_id', $courseId)
            ->where('user_id', $this->studentAuth->id)
            ->where('attempt_type', 'retake')
            ->where('status', 'finalized')
            ->first();

        $this->assertNotNull($retakeOutcome);
        $this->assertSame('passed', $retakeOutcome->result);
        $this->assertEquals(75.0, (float) $retakeOutcome->percent);

        // Original outcome remains untouched
        $origReloaded = DB::table('edu_course_outcomes')->where('id', $originalOutcome->id)->first();
        $this->assertSame('failed', $origReloaded->result);
        $this->assertEquals(35.0, (float) $origReloaded->percent);

        // 6. Progression counting exclusivity: setCounting on retake outcome
        EduOutcomes::setCounting($this->adminAuth, $retakeOutcome->id, 'Student passed retake; use for progression');

        $origCounting = DB::table('edu_course_outcomes')->where('id', $originalOutcome->id)->value('counts_for_progression');
        $retakeCounting = DB::table('edu_course_outcomes')->where('id', $retakeOutcome->id)->value('counts_for_progression');

        $this->assertSame(0, (int) $origCounting);
        $this->assertSame(1, (int) $retakeCounting);
    }

    // =========================================================================
    // F12: ONLINE EXAMS & QUESTION BANKS
    // =========================================================================

    public function test_f12_question_bank_draws_and_attempt_locking(): void
    {
        $subId = DB::table('edu_subjects')->insertGetId(['name' => 'Patristics', 'status' => 'published']);
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class H']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subId,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Patristics Course',
        ]);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id]);
        DB::table('edu_enrollments')->insert([
            ['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active'],
            ['class_id' => $classId, 'user_id' => $this->otherStudentAuth->id, 'status' => 'active'],
        ]);

        // Create question bank with 10 questions
        $bank = EduQuizzes::createBank($this->adminAuth, $subId, ['title' => 'Patristics Bank']);
        $bankId = $bank['id'];

        $questions = [];
        for ($i = 1; $i <= 10; $i++) {
            $questions[] = [
                'type' => 'single',
                'prompt' => "Question number $i?",
                'options' => ['Option A', 'Option B'],
                'answer' => 'a',
                'explanation' => "Explanation for $i",
                'points' => 2,
            ];
        }
        EduQuizzes::setBankQuestions($this->adminAuth, $bankId, $questions);

        // Create quiz and set random draw: 4 questions from bank
        $quiz = EduQuizzes::create(['auth' => $this->adminAuth], $courseId, [
            'title' => 'Drawn Quiz',
            'kind' => 'quiz',
            'time_limit_minutes' => 30,
        ]);
        DB::table('edu_quizzes')->where('id', $quiz['id'])->update(['status' => 'published']);

        EduQuizzes::setDraws($this->adminAuth, $quiz['id'], [
            ['bank_id' => $bankId, 'count' => 4, 'points_each' => 2.5],
        ]);

        // Student 1 starts quiz
        $attempt1 = EduQuizzes::start($this->studentAuth, $quiz['id']);
        $this->assertCount(4, $attempt1['questions']);
        $firstDrawnIds = array_column($attempt1['questions'], 'id');

        // Student 1 resumes attempt -> must receive the exact same 4 locked question IDs
        $resumed = EduQuizzes::studentAttempt($this->studentAuth, $attempt1['id']);
        $resumedIds = array_column($resumed['questions'], 'id');
        $this->assertSame($firstDrawnIds, $resumedIds);

        // Student 2 starts quiz -> also receives 4 questions
        $attempt2 = EduQuizzes::start($this->otherStudentAuth, $quiz['id']);
        $this->assertCount(4, $attempt2['questions']);
    }

    public function test_f12_results_release_at_hides_answers_and_expiry(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class I']);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => 1,
            'teacher_user_id' => $this->teacherAuth->id,
            'name' => 'Exam Course',
        ]);
        $assessmentId = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Exam Assessment', 'max_score' => 100, 'weight' => 100]);
        DB::table('edu_course_teachers')->insert(['course_id' => $courseId, 'user_id' => $this->teacherAuth->id]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active']);

        // Exam kind requiring assessment_id
        $futureRelease = date('Y-m-d H:i:s', strtotime('+3 days'));
        $exam = EduQuizzes::create(['auth' => $this->adminAuth], $courseId, [
            'title' => 'Formal Final Exam',
            'kind' => 'exam',
            'assessment_id' => $assessmentId,
            'results_release_at' => $futureRelease,
            'time_limit_minutes' => 60,
        ]);
        DB::table('edu_quizzes')->where('id', $exam['id'])->update(['status' => 'published']);

        $qId = DB::table('edu_quiz_questions')->insertGetId([
            'quiz_id' => $exam['id'],
            'type' => 'single',
            'prompt' => 'Who wrote the Epistles?',
            'options' => json_encode([['id' => 'a', 'text' => 'Paul'], ['id' => 'b', 'text' => 'Peter']]),
            'answer' => json_encode('a'),
            'explanation' => 'Apostle Paul wrote most epistles.',
            'points' => 10,
        ]);

        $start = EduQuizzes::start($this->studentAuth, $exam['id']);
        $attemptId = $start['id'];

        // Submit exam answers
        $submitted = EduQuizzes::submit($this->studentAuth, $attemptId, [
            ['question_id' => $qId, 'response' => 'a'],
        ]);

        // CRITICAL CHECK: Before results_release_at, answers, explanations, and is_correct must NOT be visible!
        $this->assertArrayNotHasKey('answer', $submitted['questions'][0]);
        $this->assertArrayNotHasKey('explanation', $submitted['questions'][0]);
        $this->assertArrayNotHasKey('is_correct', $submitted['questions'][0]);

        // Double submit is idempotent -> returns identical submitted attempt
        $doubleSubmit = EduQuizzes::submit($this->studentAuth, $attemptId, []);
        $this->assertSame($submitted['id'], $doubleSubmit['id']);

        // Test submit after expiry -> 409 ATTEMPT_EXPIRED
        $expiredAttemptId = DB::table('edu_quiz_attempts')->insertGetId([
            'quiz_id' => $exam['id'],
            'user_id' => $this->otherStudentAuth->id,
            'attempt_no' => 1,
            'status' => 'in_progress',
            'started_at' => date('Y-m-d H:i:s', strtotime('-2 hours')),
            'expires_at' => date('Y-m-d H:i:s', strtotime('-1 hour')), // Expired 1 hour ago
            'created_at' => date('Y-m-d H:i:s', strtotime('-2 hours')),
            'updated_at' => date('Y-m-d H:i:s', strtotime('-2 hours')),
        ]);

        try {
            EduQuizzes::submit($this->otherStudentAuth, $expiredAttemptId, []);
            $this->fail('Expected ATTEMPT_EXPIRED for expired attempt');
        } catch (ApiError $e) {
            $this->assertSame(409, $e->status);
            $this->assertSame('ATTEMPT_EXPIRED', $e->errorCode);
        }
    }

    public function test_f12_exam_report_export(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Class J']);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'subject_id' => 1, 'name' => 'Reportable Course']);
        $assessmentId = DB::table('edu_assessments')->insertGetId(['course_id' => $courseId, 'title' => 'Report Assessment', 'max_score' => 100, 'weight' => 100]);

        $quiz = EduQuizzes::create(['auth' => $this->adminAuth], $courseId, [
            'title' => 'Reportable Exam',
            'kind' => 'exam',
            'assessment_id' => $assessmentId,
        ]);
        DB::table('edu_quizzes')->where('id', $quiz['id'])->update(['status' => 'published']);

        // Insert attempt for student
        DB::table('edu_quiz_attempts')->insert([
            'quiz_id' => $quiz['id'],
            'user_id' => $this->studentAuth->id,
            'attempt_no' => 1,
            'status' => 'submitted',
            'started_at' => date('Y-m-d H:i:s', strtotime('-1 hour')),
            'submitted_at' => date('Y-m-d H:i:s'),
            'auto_score' => 85.0,
            'manual_score' => 0.0,
            'total_score' => 85.0,
            'needs_grading' => 0,
            'created_at' => date('Y-m-d H:i:s', strtotime('-1 hour')),
            'updated_at' => date('Y-m-d H:i:s'),
        ]);

        // Export report in CSV
        [$csvBytes, $mime, $filename] = ReportExport::export(['auth' => $this->adminAuth], 'education-exam', 'csv', ['quiz_id' => $quiz['id']]);
        $this->assertNotEmpty($csvBytes);
        $this->assertSame('text/csv; charset=utf-8', $mime);
        $this->assertStringContainsString('.csv', $filename);
        $this->assertStringContainsString('Student Abebe', $csvBytes);
    }
}
