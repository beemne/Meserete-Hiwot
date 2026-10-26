<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Diagnostics;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class DiagnosticsTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();
    }

    private function setUpSchema(): void
    {
        if (!Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name')->nullable();
                $table->string('phone')->nullable();
                $table->string('email')->nullable();
                $table->timestamps();
            });
        }
        if (!Schema::hasTable('diagnostic_reports')) {
            Schema::create('diagnostic_reports', function ($table) {
                $table->id();
                $table->string('report_id', 64)->unique();
                $table->unsignedBigInteger('user_id')->nullable()->index();
                $table->boolean('is_user_report')->default(false)->index();
                $table->string('module', 40)->default('general')->index();
                $table->string('screen', 100)->nullable()->index();
                $table->string('operation', 100)->nullable();
                $table->string('category', 40)->default('error')->index();
                $table->string('severity', 20)->default('error')->index();
                $table->text('message');
                $table->longText('stack_trace')->nullable();
                $table->string('endpoint', 255)->nullable();
                $table->integer('http_status')->nullable();
                $table->string('app_version', 32)->nullable();
                $table->string('platform', 32)->nullable();
                $table->boolean('is_offline')->default(false);
                $table->string('screenshot_path', 255)->nullable();
                $table->text('user_description')->nullable();
                $table->text('reproduce_steps')->nullable();
                $table->string('status', 30)->default('new')->index();
                $table->text('status_note')->nullable();
                $table->unsignedBigInteger('resolved_by')->nullable();
                $table->timestamp('resolved_at')->nullable();
                $table->unsignedInteger('occurrences')->default(1);
                $table->timestamp('first_seen_at')->nullable();
                $table->timestamp('last_seen_at')->nullable()->index();
                $table->timestamps();
            });
        }
        DB::table('diagnostic_reports')->delete();
    }

    public function test_submit_automated_report_and_deduplication(): void
    {
        $input = [
            'module' => 'education',
            'screen' => 'EduScoresScreen',
            'operation' => 'fetch_scores',
            'category' => 'api_error',
            'severity' => 'error',
            'message' => '500 Server Error: Unknown column publish_at',
            'endpoint' => '/api/v1/edu/admin/scores?course_id=12&token=secret_123',
            'http_status' => 500,
            'app_version' => '1.5.3',
            'platform' => 'android',
        ];

        $res1 = Diagnostics::submitReport(null, $input);
        $this->assertEquals('recorded', $res1['status']);
        $this->assertNotEmpty($res1['report_id']);
        $this->assertStringStartsWith('ERR-', $res1['report_id']);

        // Check DB row and sanitization of endpoint
        $row = DB::table('diagnostic_reports')->where('id', $res1['id'])->first();
        $this->assertEquals('education', $row->module);
        $this->assertEquals('/api/v1/edu/admin/scores', $row->endpoint); // Query params stripped
        $this->assertEquals(1, $row->occurrences);

        // Submitting same error again within 2 hours should deduplicate
        $res2 = Diagnostics::submitReport(null, $input);
        $this->assertEquals('deduplicated', $res2['status']);
        $this->assertEquals($res1['report_id'], $res2['report_id']);
        $this->assertEquals(2, $res2['occurrences']);

        $updated = DB::table('diagnostic_reports')->where('id', $res1['id'])->first();
        $this->assertEquals(2, $updated->occurrences);
    }

    public function test_sanitize_strips_jwt_and_passwords(): void
    {
        $dirty = 'Crash during Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.e30.t-ID where {"password": "supersecretpassword123"} was sent';
        $clean = Diagnostics::sanitize($dirty);

        $this->assertStringNotContainsString('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9', $clean);
        $this->assertStringNotContainsString('supersecretpassword123', $clean);
        $this->assertStringContainsString('[REDACTED_JWT]', $clean);
        $this->assertStringContainsString('[REDACTED]', $clean);
    }

    public function test_submit_user_report(): void
    {
        $auth = new AuthContext();
        $auth->id = 42;
        $auth->accountType = 'member';
        $auth->fullName = 'Abebe Kebede';

        $input = [
            'is_user_report' => true,
            'module' => 'sinksar',
            'screen' => 'SinksarScreen',
            'user_description' => 'The daily feast descriptions are not loading when offline.',
            'reproduce_steps' => '1. Turn on airplane mode. 2. Open Sinksar screen.',
            'app_version' => '1.5.3',
            'platform' => 'android',
            'is_offline' => true,
        ];

        $res = Diagnostics::submitReport($auth, $input);
        $this->assertEquals('recorded', $res['status']);
        $this->assertTrue($res['is_user_report']);
        $this->assertStringStartsWith('REP-', $res['report_id']);

        $row = DB::table('diagnostic_reports')->where('id', $res['id'])->first();
        $this->assertEquals(42, $row->user_id);
        $this->assertEquals(1, $row->is_user_report);
        $this->assertEquals('The daily feast descriptions are not loading when offline.', $row->user_description);
        $this->assertEquals('1. Turn on airplane mode. 2. Open Sinksar screen.', $row->reproduce_steps);
        $this->assertEquals(1, $row->is_offline);
    }

    public function test_super_admin_diagnostic_dashboard_and_status_update(): void
    {
        // Insert test report
        $input = [
            'module' => 'education',
            'screen' => 'EduScoresScreen',
            'message' => 'Something went wrong',
            'stack_trace' => 'Fatal error in EduScores.php:155',
            'user_description' => 'User could not see their score',
            'is_user_report' => true,
        ];
        $rep = Diagnostics::submitReport(null, $input);

        // Regular admin (not super admin)
        $admin = new AuthContext();
        $admin->id = 10;
        $admin->accountType = 'admin';
        $admin->isAdmin = true;
        $admin->role = ['id' => 3, 'slug' => 'dept_education', 'name' => 'Education Head', 'level' => 30];

        $list = Diagnostics::listReports($admin, ['module' => 'education']);
        $this->assertCount(1, $list['data']);
        $this->assertEquals(1, $list['summary']['total_reports']);
        $this->assertEquals(1, $list['summary']['total_unresolved']);

        // Stack trace should be restricted for regular admin
        $detailsAdmin = Diagnostics::getReport($admin, $rep['id']);
        $this->assertEquals('[Stack trace restricted to Super Administrator]', $detailsAdmin['stack_trace']);

        // Super Admin (high_admin)
        $superAdmin = new AuthContext();
        $superAdmin->id = 2;
        $superAdmin->accountType = 'admin';
        $superAdmin->isAdmin = true;
        $superAdmin->fullName = 'Head Super Admin';
        $superAdmin->role = ['id' => 2, 'slug' => 'high_admin', 'name' => 'ከፍተኛ አስተዳዳሪ', 'level' => 50];

        $detailsSuper = Diagnostics::getReport($superAdmin, $rep['id']);
        $this->assertEquals('Fatal error in EduScores.php:155', $detailsSuper['stack_trace']);

        // Update status to investigating then resolved
        $updated = Diagnostics::updateStatus($superAdmin, $rep['id'], 'investigating', 'Investigating SQL column mismatch');
        $this->assertEquals('investigating', $updated['status']);
        $this->assertStringContainsString('Investigating SQL column mismatch', $updated['status_note']);

        $resolved = Diagnostics::updateStatus($superAdmin, $rep['id'], 'resolved', 'Fixed column publish_at to opens_at');
        $this->assertEquals('resolved', $resolved['status']);
        $this->assertEquals(2, $resolved['resolved_by']);
        $this->assertNotNull($resolved['resolved_at']);
    }
}
