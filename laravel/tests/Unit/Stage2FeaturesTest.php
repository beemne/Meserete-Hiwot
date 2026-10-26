<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Services\EduQuizzes;
use App\Mz\Services\EduScores;
use App\Mz\Services\Payments;
use App\Mz\Services\Reports;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class Stage2FeaturesTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $financeAuth;
    private AuthContext $studentAuth;
    private AuthContext $otherStudentAuth;
    private array $adminActx;
    private array $financeActx;
    private array $studentActx;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth(1, 'Admin User', ['education.reports' => true, 'education.manage' => true, 'finance.manage' => true, 'audit_logs.view' => true]);
        $this->financeAuth = $this->makeAuth(2, 'Finance Officer', ['finance.manage' => true]);
        $this->studentAuth = $this->makeAuth(10, 'Student Abebe', []);
        $this->otherStudentAuth = $this->makeAuth(11, 'Student Kebede', []);

        $this->adminActx = ['auth' => $this->adminAuth, 'ip' => '127.0.0.1', 'userAgent' => 'PHPUnit'];
        $this->financeActx = ['auth' => $this->financeAuth, 'ip' => '127.0.0.1', 'userAgent' => 'PHPUnit'];
        $this->studentActx = ['auth' => $this->studentAuth, 'ip' => '127.0.0.1', 'userAgent' => 'PHPUnit'];

        DB::table('users')->truncate();
        DB::table('users')->insert([
            ['id' => 1, 'full_name' => 'Admin User', 'phone' => '0911000001', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 2, 'full_name' => 'Finance Officer', 'phone' => '0911000002', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 10, 'full_name' => 'Student Abebe', 'phone' => '0911000010', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()],
            ['id' => 11, 'full_name' => 'Student Kebede', 'phone' => '0911000011', 'status' => 'active', 'created_at' => now(), 'updated_at' => now()],
        ]);
    }

    private function makeAuth(int $id, string $name, array $perms = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = ! empty($perms) ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = ! empty($perms);
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->level = ! empty($perms) ? 100 : 10;
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
                $table->string('member_type')->nullable();
                $table->string('member_group')->nullable();
                $table->string('status')->default('active');
                $table->unsignedBigInteger('role_id')->nullable();
                $table->softDeletes();
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

        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->string('key')->primary();
                $table->text('value')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('contribution_receipts')) {
            Schema::create('contribution_receipts', function ($table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('user_id');
                $table->unsignedInteger('months')->default(1);
                $table->string('start_period', 7);
                $table->string('end_period', 7);
                $table->decimal('amount', 12, 2)->nullable();
                $table->string('currency', 3)->default('ETB');
                $table->string('file_path', 500);
                $table->string('file_name', 255);
                $table->string('mime_type', 100);
                $table->unsignedInteger('file_size')->default(0);
                $table->text('note')->nullable();
                $table->string('status', 20)->default('pending');
                $table->text('rejection_reason')->nullable();
                $table->unsignedBigInteger('verified_by')->nullable();
                $table->dateTime('verified_at')->nullable();
                $table->unsignedBigInteger('payment_id')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('payments')) {
            Schema::create('payments', function ($table) {
                $table->bigIncrements('id');
                $table->unsignedBigInteger('user_id');
                $table->string('period', 7)->nullable();
                $table->unsignedInteger('months')->default(1);
                $table->string('coverage_end', 7)->nullable();
                $table->string('member_type', 50)->nullable();
                $table->decimal('monthly_rate', 12, 2)->default(0);
                $table->decimal('amount', 12, 2)->default(0);
                $table->string('currency', 3)->default('ETB');
                $table->string('method', 50)->default('manual');
                $table->string('reference', 100)->nullable();
                $table->date('paid_on')->nullable();
                $table->string('receipt', 500)->nullable();
                $table->string('status', 20)->default('completed');
                $table->unsignedBigInteger('recorded_by')->nullable();
                $table->unsignedBigInteger('verified_by')->nullable();
                $table->text('note')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('notifications')) {
            Schema::create('notifications', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('type');
                $table->string('title');
                $table->text('body');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->string('dedupe_key')->nullable();
                $table->boolean('is_read')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('actor_id')->nullable();
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->text('metadata')->nullable();
                $table->string('ip')->nullable();
                $table->string('user_agent')->nullable();
                $table->boolean('is_hidden')->default(false);
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

        if (! Schema::hasTable('edu_subjects')) {
            Schema::create('edu_subjects', function ($table) {
                $table->id();
                $table->unsignedBigInteger('category_id');
                $table->string('name');
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_question_banks')) {
            Schema::create('edu_question_banks', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id');
                $table->string('title');
                $table->string('category', 100)->nullable();
                $table->string('difficulty', 20)->default('mixed');
                $table->text('description')->nullable();
                $table->unsignedBigInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_academic_years')) {
            Schema::create('edu_academic_years', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_terms')) {
            Schema::create('edu_terms', function ($table) {
                $table->id();
                $table->string('name');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('academic_year_id')->nullable();
                $table->unsignedBigInteger('term_id')->nullable();
                $table->string('name');
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

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedBigInteger('class_id');
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('title')->default('Course');
                $table->string('name')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_outcomes')) {
            Schema::create('edu_course_outcomes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id');
                $table->unsignedBigInteger('user_id');
                $table->decimal('score_percent', 5, 2)->default(0);
                $table->decimal('pass_mark', 5, 2)->default(50);
                $table->string('result')->default('incomplete');
                $table->string('status')->default('provisional');
                $table->tinyInteger('counts_for_progression')->default(1);
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

        if (! Schema::hasTable('edu_quizzes')) {
            Schema::create('edu_quizzes', function ($table) {
                $table->id();
                $table->unsignedBigInteger('course_id')->nullable();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->unsignedBigInteger('assessment_id')->nullable();
                $table->string('title');
                $table->string('title_en')->nullable();
                $table->string('review_policy')->default('always');
                $table->string('status')->default('published');
                $table->decimal('total_points', 6, 2)->default(100.0);
                $table->integer('max_attempts')->default(1);
                $table->datetime('results_release_at')->nullable();
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
                $table->datetime('started_at');
                $table->datetime('submitted_at')->nullable();
                $table->datetime('expires_at')->nullable();
                $table->decimal('auto_score', 6, 2)->default(0.00);
                $table->decimal('manual_score', 6, 2)->default(0.00);
                $table->decimal('max_score', 6, 2)->default(100.00);
                $table->boolean('needs_grading')->default(false);
                $table->json('question_ids')->nullable();
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
                $table->json('options')->nullable();
                $table->text('answer')->nullable();
                $table->decimal('points', 6, 2)->default(1.00);
                $table->integer('sort_order')->default(0);
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
                $table->text('feedback')->nullable();
                $table->unsignedBigInteger('graded_by')->nullable();
                $table->datetime('graded_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lesson_progress')) {
            Schema::create('edu_lesson_progress', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->unsignedBigInteger('lesson_id');
                $table->unsignedBigInteger('course_id');
                $table->boolean('completed')->default(false);
                $table->datetime('completed_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_units')) {
            Schema::create('edu_units', function ($table) {
                $table->id();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('title');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_lessons')) {
            Schema::create('edu_lessons', function ($table) {
                $table->id();
                $table->unsignedBigInteger('unit_id')->nullable();
                $table->unsignedBigInteger('subject_id')->nullable();
                $table->string('title');
                $table->timestamps();
            });
        }
    }

    // =========================================================================
    // 1. Monthly Contribution Receipt Upload & Review Flow
    // =========================================================================

    public function test_receipt_submission_review_and_approval(): void
    {
        // 1. Submit receipt
        $file = UploadedFile::fake()->image('bank_receipt.jpg', 600, 400);
        $input = [
            'months' => 3,
            'period' => '2026-10',
            'amount' => 600.00,
            'note' => 'Payment for Tikimt to Tahsas',
        ];

        $receipt = Payments::submitReceipt($this->studentActx, $input, $file);

        $this->assertEquals('pending', $receipt['status']);
        $this->assertEquals(3, $receipt['months']);
        $this->assertEquals('2026-10', $receipt['start_period']);
        $this->assertEquals('2026-12', $receipt['end_period']);
        $this->assertEquals(600.00, (float) $receipt['amount']);
        $this->assertNull($receipt['verified_at']);

        // Check member receipts list
        $myReceipts = Payments::myReceipts($this->studentAuth->id);
        $this->assertCount(1, $myReceipts);
        $this->assertEquals($receipt['id'], $myReceipts[0]['id']);

        // Check admin queue
        $queue = Payments::receiptList(['status' => 'pending'], ['page' => 1, 'limit' => 20]);
        $this->assertGreaterThanOrEqual(1, count($queue['items']));

        // 2. Finance admin approves receipt
        $approved = Payments::approveReceipt($this->financeActx, $receipt['id']);
        $this->assertEquals('approved', $approved['status']);
        $this->assertNotNull($approved['verified_at']);
        $this->assertEquals($this->financeAuth->id, $approved['verified_by']);
        $this->assertNotNull($approved['payment_id']);

        // Verify payment record was created
        $payment = DB::table('payments')->where('id', $approved['payment_id'])->first();
        $this->assertNotNull($payment);
        $this->assertEquals(600.00, (float) $payment->amount);
        $this->assertEquals($this->studentAuth->id, (int) $payment->user_id);
    }

    public function test_receipt_rejection_requires_reason(): void
    {
        $file = UploadedFile::fake()->image('unclear_receipt.png', 600, 400);
        $receipt = Payments::submitReceipt($this->studentActx, ['months' => 1, 'period' => '2026-10', 'amount' => 200], $file);

        // Rejection without reason must fail
        try {
            Payments::rejectReceipt($this->financeActx, $receipt['id'], '   ');
            $this->fail('Expected ApiError for empty rejection reason');
        } catch (ApiError $e) {
            $this->assertEquals('REASON_REQUIRED', $e->errorCode);
        }

        // Rejection with valid reason
        $rejected = Payments::rejectReceipt($this->financeActx, $receipt['id'], 'ደረሰኙ ግልጽ አይደለም፣ እባክዎ በድጋሚ ይላኩ።');
        $this->assertEquals('rejected', $rejected['status']);
        $this->assertEquals('ደረሰኙ ግልጽ አይደለም፣ እባክዎ በድጋሚ ይላኩ።', $rejected['rejection_reason']);
        $this->assertEquals($this->financeAuth->id, $rejected['verified_by']);
    }

    // =========================================================================
    // 2. Education Scores & Privacy
    // =========================================================================

    public function test_scores_privacy_and_pending_grading_withholding(): void
    {
        // Setup academic history
        $ayId = DB::table('edu_academic_years')->insertGetId(['name' => '2019 ዓ.ም', 'created_at' => now(), 'updated_at' => now()]);
        $classId = DB::table('edu_classes')->insertGetId(['academic_year_id' => $ayId, 'name' => 'ክፍል 10A', 'created_at' => now(), 'updated_at' => now()]);
        DB::table('edu_enrollments')->insert(['class_id' => $classId, 'user_id' => $this->studentAuth->id, 'status' => 'active', 'created_at' => now(), 'updated_at' => now()]);
        $courseId = DB::table('edu_courses')->insertGetId(['class_id' => $classId, 'name' => 'ነገረ መለኮት', 'created_at' => now(), 'updated_at' => now()]);

        // Create quiz attempt with pending grading
        $quizId = DB::table('edu_quizzes')->insertGetId(['course_id' => $courseId, 'title' => 'ምዕራፍ 1 ፈተና', 'status' => 'published', 'total_points' => 50, 'max_attempts' => 1, 'created_at' => now(), 'updated_at' => now()]);
        $attemptId = DB::table('edu_quiz_attempts')->insertGetId([
            'quiz_id' => $quizId,
            'user_id' => $this->studentAuth->id,
            'attempt_no' => 1,
            'status' => 'pending_grading',
            'started_at' => now(),
            'submitted_at' => now(),
            'auto_score' => 20,
            'manual_score' => 0,
            'max_score' => 50,
            'needs_grading' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Student can view their own scores
        $studentScores = EduScores::forStudent($this->studentAuth, $this->studentAuth->id);
        $this->assertEquals($this->studentAuth->id, $studentScores['student']['id']);
        $this->assertCount(1, $studentScores['quiz_attempts']);
        $this->assertTrue($studentScores['quiz_attempts'][0]['pending_grading']);
        $this->assertNull($studentScores['quiz_attempts'][0]['score'], 'Pending grading score must be hidden from student');

        // Other student cannot view another student's scores
        try {
            EduScores::forStudent($this->otherStudentAuth, $this->studentAuth->id);
            $this->fail('Expected ApiError::forbidden');
        } catch (ApiError $e) {
            $this->assertEquals('FORBIDDEN', $e->errorCode);
        }

        // Admin can view any student's scores
        $adminView = EduScores::forStudent($this->adminAuth, $this->studentAuth->id);
        $this->assertEquals($this->studentAuth->id, $adminView['student']['id']);
    }

    // =========================================================================
    // 3. Question Bank Tags, Difficulty, and Name/Title Compatibility
    // =========================================================================

    public function test_question_bank_flexible_fields(): void
    {
        $catId = DB::table('edu_categories')->insertGetId(['name' => 'ሃይማኖት', 'created_at' => now(), 'updated_at' => now()]);
        $subjectId = DB::table('edu_subjects')->insertGetId(['category_id' => $catId, 'name' => 'መጽሐፍ ቅዱስ ጥናት', 'created_at' => now(), 'updated_at' => now()]);

        // Create with 'name' (mobile compatibility)
        $bank = EduQuizzes::createBank($this->adminAuth, $subjectId, [
            'name' => 'ብሉይ ኪዳን ጥያቄዎች',
            'category' => 'ኦሪት',
            'difficulty' => 'medium',
            'description' => 'የኦሪት ዘፍጥረት ጥያቄዎች ባንክ',
        ]);

        $this->assertEquals('ብሉይ ኪዳን ጥያቄዎች', $bank['title']);
        $this->assertEquals('ኦሪት', $bank['category']);
        $this->assertEquals('medium', $bank['difficulty']);
        $this->assertEquals('የኦሪት ዘፍጥረት ጥያቄዎች ባንክ', $bank['description']);

        // List banks returns new metadata
        $banks = EduQuizzes::listBanks($this->adminAuth, $subjectId);
        $this->assertCount(1, $banks);
        $this->assertEquals('ብሉይ ኪዳን ጥያቄዎች', $banks[0]['title']);
        $this->assertEquals('ኦሪት', $banks[0]['category']);
    }

    // =========================================================================
    // 4. Notification Settings & Mandatory Categories
    // =========================================================================

    public function test_mandatory_notification_categories(): void
    {
        $mandatory = Notifications::MANDATORY_TOPICS;
        $this->assertContains('system', $mandatory);
        $this->assertContains('program', $mandatory);
        $this->assertContains('attendance', $mandatory);
        $this->assertContains('education', $mandatory);
        $this->assertContains('payment', $mandatory);

        $this->assertTrue(Notifications::isMandatory('system'));
        $this->assertTrue(Notifications::isMandatory('education'));
        $this->assertTrue(Notifications::isMandatory('payment'));
        $this->assertFalse(Notifications::isMandatory('mezmur'));
    }

    // =========================================================================
    // 5. Audit Log Filtering
    // =========================================================================

    public function test_audit_logs_rich_query_filtering(): void
    {
        DB::table('audit_logs')->truncate();
        DB::table('audit_logs')->insert([
            ['actor_id' => 1, 'action' => 'edu.class.create', 'entity_type' => 'edu_class', 'entity_id' => 101, 'metadata' => json_encode(['name' => 'Class 9A']), 'ip' => '127.0.0.1', 'is_hidden' => 0, 'created_at' => now()],
            ['actor_id' => 2, 'action' => 'payments.receipt.approve', 'entity_type' => 'contribution_receipt', 'entity_id' => 201, 'metadata' => json_encode(['amount' => 500, 'outcome' => 'approved']), 'ip' => '127.0.0.1', 'is_hidden' => 0, 'created_at' => now()],
            ['actor_id' => 1, 'action' => 'mezmur.song.publish', 'entity_type' => 'mezmur', 'entity_id' => 301, 'metadata' => json_encode(['title' => 'እግዚአብሔር ብርሃኔ ነው'], JSON_UNESCAPED_UNICODE), 'ip' => '127.0.0.1', 'is_hidden' => 0, 'created_at' => now()],
        ]);

        // Filter by module 'education'
        $eduLogs = Reports::auditLogs($this->adminAuth, ['module' => 'education'], ['page' => 1, 'limit' => 10]);
        $this->assertCount(1, $eduLogs['items']);
        $this->assertEquals('edu.class.create', $eduLogs['items'][0]->action);

        // Filter by module 'finance'
        $financeLogs = Reports::auditLogs($this->adminAuth, ['module' => 'finance'], ['page' => 1, 'limit' => 10]);
        $this->assertCount(1, $financeLogs['items']);
        $this->assertEquals('payments.receipt.approve', $financeLogs['items'][0]->action);

        // Filter by free-text search query
        $searchLogs = Reports::auditLogs($this->adminAuth, ['q' => 'ብርሃኔ'], ['page' => 1, 'limit' => 10]);
        $this->assertCount(1, $searchLogs['items']);
        $this->assertEquals('mezmur.song.publish', $searchLogs['items'][0]->action);

        // Filter by outcome
        $outcomeLogs = Reports::auditLogs($this->adminAuth, ['outcome' => 'approved'], ['page' => 1, 'limit' => 10]);
        $this->assertCount(1, $outcomeLogs['items']);
        $this->assertEquals('payments.receipt.approve', $outcomeLogs['items'][0]->action);
    }
}
