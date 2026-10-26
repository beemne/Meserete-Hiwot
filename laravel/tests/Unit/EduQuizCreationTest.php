<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduLearning;
use App\Mz\Services\EduQuizzes;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduQuizCreationTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $editorAuth;
    private AuthContext $teacherAuth;
    private AuthContext $memberAuth;
    private array $adminActx;
    private array $editorActx;
    private array $teacherActx;
    private array $memberActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin User', ['education.manage' => true]);
        $this->editorAuth = $this->makeAuth(2, 'Editor User', ['education.content' => true]);
        $this->teacherAuth = $this->makeAuth(3, 'Teacher User', []);
        $this->memberAuth = $this->makeAuth(4, 'Regular Member', []);

        $this->adminActx = ['auth' => $this->adminAuth];
        $this->editorActx = ['auth' => $this->editorAuth];
        $this->teacherActx = ['auth' => $this->teacherAuth];
        $this->memberActx = ['auth' => $this->memberAuth];
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
                $table->string('status')->default('active');
                $table->unsignedBigInteger('created_by')->nullable();
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
                $table->string('status')->default('active');
                $table->unsignedBigInteger('teacher_user_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_teachers')) {
            Schema::create('edu_course_teachers', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->string('status')->default('active');
                $table->unsignedBigInteger('assigned_by')->nullable();
                $table->datetime('assigned_at')->nullable();
                $table->unsignedBigInteger('changed_by')->nullable();
                $table->datetime('changed_at')->nullable();
                $table->string('note')->nullable();
            });
        }

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('lesson_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->text('instructions')->nullable();
                $table->text('instructions_en')->nullable();
                $table->datetime('opens_at')->nullable();
                $table->datetime('closes_at')->nullable();
                $table->datetime('results_release_at')->nullable();
                $table->string('kind')->default('quiz');
                $table->integer('time_limit_minutes')->nullable();
                $table->integer('max_attempts')->default(1);
                $table->string('scoring')->default('best');
                $table->boolean('shuffle')->default(false);
                $table->string('review_policy')->default('after_submit');
                $table->string('status')->default('draft');
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_questions')) {
            Schema::create('edu_quiz_questions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->string('type');
                $table->text('prompt');
                $table->text('prompt_en')->nullable();
                $table->text('options')->nullable();
                $table->text('answer')->nullable();
                $table->text('explanation')->nullable();
                $table->text('explanation_en')->nullable();
                $table->decimal('points', 8, 2)->default(1);
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
                $table->boolean('needs_grading')->default(false);
                $table->decimal('max_score', 8, 2)->nullable();
                $table->decimal('auto_score', 8, 2)->nullable();
                $table->decimal('manual_score', 8, 2)->nullable();
                $table->text('question_ids')->nullable();
                $table->datetime('started_at')->nullable();
                $table->datetime('expires_at')->nullable();
                $table->datetime('submitted_at')->nullable();
                $table->datetime('transferred_at')->nullable();
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
                $table->decimal('points_awarded', 8, 2)->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_quiz_draws')) {
            Schema::create('edu_quiz_draws', function ($table) {
                $table->id();
                $table->unsignedBigInteger('quiz_id');
                $table->integer('count')->default(0);
                $table->decimal('points_each', 8, 2)->default(1);
            });
        }

        if (! Schema::hasTable('edu_assessments')) {
            Schema::create('edu_assessments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->string('title');
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
                $table->integer('est_minutes')->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status')->default('published');
                $table->datetime('published_at')->nullable();
                $table->boolean('is_mandatory')->default(true);
                $table->boolean('requires_quiz')->default(false);
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

        if (! Schema::hasTable('edu_categories')) {
            Schema::create('edu_categories', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_progress')) {
            Schema::create('edu_lesson_progress', function ($table) {
                $table->id();
                $table->unsignedBigInteger('lesson_id');
                $table->unsignedBigInteger('user_id');
                $table->datetime('last_opened_at')->nullable();
                $table->datetime('completed_at')->nullable();
                $table->boolean('bookmarked')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_materials')) {
            Schema::create('edu_lesson_materials', function ($table) {
                $table->id();
                $table->unsignedBigInteger('lesson_id');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('user_id');
                $table->string('program')->default('regular');
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

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id')->nullable();
                $table->string('action');
                $table->string('target_type')->nullable();
                $table->unsignedBigInteger('target_id')->nullable();
                $table->text('payload')->nullable();
                $table->timestamps();
            });
        }
    }

    public function test_admin_can_create_quiz_for_subject_without_existing_course(): void
    {
        // 1. Create a subject with NO linked course in edu_courses
        $subjectId = (int) DB::table('edu_subjects')->insertGetId([
            'name' => 'ክርስቲያናዊ ሥነ ምግባር',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 2. Admin creates a quiz for this subject
        $quiz = EduQuizzes::createForSubject($this->adminActx, $subjectId, [
            'title' => 'የምዕራፍ ፩ ፈተና',
        ]);

        $this->assertNotEmpty($quiz);
        $this->assertSame('የምዕራፍ ፩ ፈተና', $quiz['title']);
        $this->assertSame('draft', $quiz['status']);
        $this->assertGreaterThan(0, $quiz['id']);
        $this->assertGreaterThan(0, $quiz['course_id']);

        // 3. Verify that edu_courses record has teacher_user_id and valid class_id
        $course = DB::table('edu_courses')->where('id', $quiz['course_id'])->first();
        $this->assertNotNull($course);
        $this->assertSame($subjectId, (int) $course->subject_id);
        $this->assertSame($this->adminAuth->id, (int) $course->teacher_user_id);

        // 4. Verify edu_course_teachers has active assignment
        $teacherAssignment = DB::table('edu_course_teachers')
            ->where(['course_id' => $quiz['course_id'], 'user_id' => $this->adminAuth->id, 'status' => 'active'])
            ->first();
        $this->assertNotNull($teacherAssignment);

        // 5. Verify the quiz persists and is retrieved in forSubject()
        $quizzes = EduQuizzes::forSubject($this->adminAuth, $subjectId);
        $this->assertCount(1, $quizzes);
        $this->assertSame($quiz['id'], $quizzes[0]['id']);

        // 6. Verify teacherQuiz returns it
        $retrieved = EduQuizzes::teacherQuiz($this->adminAuth, $quiz['id']);
        $this->assertSame($quiz['id'], $retrieved['id']);
        $this->assertSame('የምዕራፍ ፩ ፈተና', $retrieved['title']);
    }

    public function test_teacher_can_create_quiz_for_taught_subject(): void
    {
        // Create subject, class, and course taught by teacher
        $subjectId = (int) DB::table('edu_subjects')->insertGetId([
            'name' => 'ነገረ መለኮት',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $classId = (int) DB::table('edu_classes')->insertGetId([
            'name' => 'ክፍል ፩',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $courseId = (int) DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'subject_id' => $subjectId,
            'name' => 'ነገረ መለኮት - ፩',
            'status' => 'active',
            'teacher_user_id' => $this->teacherAuth->id,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('edu_course_teachers')->insert([
            'course_id' => $courseId,
            'user_id' => $this->teacherAuth->id,
            'status' => 'active',
            'assigned_by' => $this->adminAuth->id,
            'assigned_at' => now(),
        ]);

        // Teacher creates quiz for subject
        $quiz = EduQuizzes::createForSubject($this->teacherActx, $subjectId, [
            'title' => 'የክፍለ ጊዜ ፈተና',
        ]);

        $this->assertSame('የክፍለ ጊዜ ፈተና', $quiz['title']);
        $this->assertSame($courseId, $quiz['course_id']);
    }

    public function test_unauthorized_member_cannot_create_quiz(): void
    {
        $subjectId = (int) DB::table('edu_subjects')->insertGetId([
            'name' => 'ትምህርተ ሃይማኖት',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->expectException(\App\Mz\Support\ApiError::class);
        try {
            EduQuizzes::createForSubject($this->memberActx, $subjectId, ['title' => 'ያልተፈቀደ ፈተና']);
        } catch (\App\Mz\Support\ApiError $e) {
            $this->assertSame(403, $e->status);
            $this->assertSame('NOT_SUBJECT_EDITOR', $e->errorCode);
            throw $e;
        }
    }

    public function test_quiz_validates_dates_and_assessment(): void
    {
        $subjectId = (int) DB::table('edu_subjects')->insertGetId([
            'name' => 'ታሪክ',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // closes_at before opens_at
        try {
            EduQuizzes::createForSubject($this->adminActx, $subjectId, [
                'title' => 'Date Test',
                'opens_at' => '2026-10-20 10:00:00',
                'closes_at' => '2026-10-19 10:00:00',
            ]);
            $this->fail('Expected CLOSES_BEFORE_OPENS');
        } catch (\App\Mz\Support\ApiError $e) {
            $this->assertSame('VALIDATION_ERROR', $e->errorCode);
            $this->assertSame('CLOSES_BEFORE_OPENS', $e->errors[0]['code']);
        }

        // Exam kind requires assessment_id
        try {
            EduQuizzes::createForSubject($this->adminActx, $subjectId, [
                'title' => 'Exam Test',
                'kind' => 'exam',
            ]);
            $this->fail('Expected ASSESSMENT_REQUIRED');
        } catch (\App\Mz\Support\ApiError $e) {
            $this->assertSame('VALIDATION_ERROR', $e->errorCode);
            $this->assertSame('ASSESSMENT_REQUIRED', $e->errors[0]['code']);
        }
    }

    public function test_subject_detail_returns_created_quizzes(): void
    {
        $subjectId = (int) DB::table('edu_subjects')->insertGetId([
            'name' => 'ስርዓተ ቤተ ክርስቲያን',
            'status' => 'published',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $quiz = EduQuizzes::createForSubject($this->adminActx, $subjectId, [
            'title' => 'የስርዓተ ቤተ ክርስቲያን ፈተና',
        ]);

        $detail = EduLearning::subjectDetail($this->adminAuth, $subjectId);
        $this->assertArrayHasKey('quizzes', $detail);
        $this->assertCount(1, $detail['quizzes']);
        $this->assertSame($quiz['id'], $detail['quizzes'][0]->id);
        $this->assertSame('የስርዓተ ቤተ ክርስቲያን ፈተና', $detail['quizzes'][0]->title);
    }

    public function test_quiz_detail_and_preview_for_admin_and_student(): void
    {
        $subjectId = (int) DB::table('edu_subjects')->insertGetId([
            'name' => 'መጽሐፍ ቅዱስ ጥናት',
            'status' => 'published',
            'visibility' => 'members',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $quiz = EduQuizzes::createForSubject($this->adminActx, $subjectId, [
            'title' => 'የመጽሐፍ ቅዱስ ፈተና',
            'title_en' => 'Bible Quiz',
            'instructions' => 'መመሪያዎችን ያንብቡ',
            'instructions_en' => 'Read instructions',
        ]);
        $quizId = (int) $quiz['id'];

        EduQuizzes::setQuestions($this->adminActx, $quizId, [
            [
                'type' => 'true_false',
                'prompt' => 'መጽሐፍ ቅዱስ 66 መጻሕፍት አሉት?',
                'prompt_en' => 'Does the Bible contain 66 books?',
                'answer' => true,
                'explanation' => 'በፕሮቴስታንት እትም',
                'explanation_en' => 'In standard protestant canon',
                'points' => 5,
            ],
        ]);

        // Admin detail check
        $adminDetail = EduQuizzes::quizDetail($this->adminAuth, $quizId);
        $this->assertTrue($adminDetail['can_edit']);
        $this->assertSame('የመጽሐፍ ቅዱስ ፈተና', $adminDetail['title']);
        $this->assertSame('Bible Quiz', $adminDetail['title_en']);
        $this->assertArrayHasKey('questions', $adminDetail);
        $this->assertCount(1, $adminDetail['questions']);
        $this->assertSame('Bible Quiz', $adminDetail['title_en']);

        // Admin can start draft quiz as preview
        $attempt = EduQuizzes::start($this->adminAuth, $quizId);
        $this->assertSame('in_progress', $attempt['status']);
        $this->assertSame($quizId, $attempt['quiz_id']);

        // Student detail check (student can open because visibility is members)
        $studentDetail = EduQuizzes::quizDetail($this->memberAuth, $quizId);
        $this->assertFalse($studentDetail['can_edit']);
        $this->assertSame('የመጽሐፍ ቅዱስ ፈተና', $studentDetail['title']);
        $this->assertArrayNotHasKey('questions', $studentDetail);
    }
}
