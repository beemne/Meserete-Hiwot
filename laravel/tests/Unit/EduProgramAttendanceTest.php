<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\Selections;
use App\Mz\Services\Settings;
use App\Mz\Services\Sync;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduProgramAttendanceTest extends TestCase
{
    private AuthContext $auth;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $auth = new AuthContext();
        $auth->id = 1;
        $auth->fullName = 'Admin User';
        $auth->status = 'active';
        $auth->accountType = 'admin';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = true;
        $auth->isSystem = true;
        $auth->isMemberStaff = false;
        $auth->level = 100;
        $auth->permissions = ['education.manage' => true, 'attendance.take' => true];
        $this->auth = $auth;
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->id();
                $table->string('key')->unique();
                $table->text('value')->nullable();
                $table->string('type')->default('string');
                $table->text('description')->nullable();
                $table->timestamps();
            });
        }

        DB::table('settings')->updateOrInsert(
            ['key' => 'edu.attendance_cutover'],
            ['value' => '2026-10-20', 'type' => 'string', 'description' => 'Cutover date for program class attendance']
        );

        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name')->default('Test User');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_group')->default('youth_adult');
                $table->unsignedInteger('role_id')->nullable();
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->softDeletes();
                $table->timestamps();
            });
            DB::table('users')->insert([
                ['id' => 1, 'full_name' => 'Admin User', 'status' => 'active', 'account_type' => 'admin'],
                ['id' => 2, 'full_name' => 'Student Member', 'status' => 'active', 'account_type' => 'user'],
            ]);
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->string('status')->default('active');
                $table->timestamps();
            });
            DB::table('edu_classes')->insert([
                ['id' => 1, 'name' => 'Grade 5', 'status' => 'active'],
            ]);
        }

        if (! Schema::hasTable('attendance_sync_conflicts')) {
            Schema::create('attendance_sync_conflicts', function ($table) {
                $table->id();
                $table->string('kind');
                $table->string('code');
                $table->unsignedBigInteger('program_id')->nullable();
                $table->unsignedBigInteger('class_id')->nullable();
                $table->date('occurrence_date');
                $table->unsignedBigInteger('user_id')->nullable();
                $table->unsignedBigInteger('submitted_by');
                $table->string('client_event_id')->nullable();
                $table->dateTime('client_captured_at')->nullable();
                $table->dateTime('captured_at')->nullable();
                $table->text('payload')->nullable();
                $table->string('signature_path')->nullable();
                $table->string('signature_sha256')->nullable();
                $table->string('status')->default('open');
                $table->unsignedBigInteger('resolved_by')->nullable();
                $table->dateTime('resolved_at')->nullable();
                $table->string('resolution_note', 1000)->nullable();
                $table->unsignedBigInteger('attendance_id')->nullable();
                $table->nullableTimestamps();
            });
        }

        if (! Schema::hasTable('sync_receipts')) {
            Schema::create('sync_receipts', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('op_id');
                $table->string('status');
                $table->text('result')->nullable();
                $table->unique(['user_id', 'op_id']);
                $table->nullableTimestamps();
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id')->nullable();
                $table->string('action');
                $table->string('auditable_type')->nullable();
                $table->unsignedBigInteger('auditable_id')->nullable();
                $table->text('details')->nullable();
                $table->string('ip')->nullable();
                $table->nullableTimestamps();
            });
        }

        if (! Schema::hasTable('selection_config_versions')) {
            Schema::create('selection_config_versions', function ($table) {
                $table->id();
                $table->unsignedBigInteger('selection_id');
                $table->integer('version');
                $table->text('config');
                $table->string('canonical_hash');
                $table->timestamps();
            });
        }
    }

    public function test_cutover_setting_defined_and_defaults(): void
    {
        $cutover = Settings::eduAttendanceCutover();
        $this->assertNotEmpty($cutover);
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}$/', $cutover);
    }

    public function test_edu_mark_throws_410_gone_on_or_after_cutover(): void
    {
        $cutover = Settings::eduAttendanceCutover();

        $this->expectException(ApiError::class);
        try {
            Edu::mark($this->auth, 1, [
                'user_id' => 2,
                'date' => $cutover,
                'status' => 'present',
            ]);
        } catch (ApiError $e) {
            $this->assertSame(410, $e->status);
            $this->assertSame('EDU_ATTENDANCE_MOVED', $e->errorCode);
            throw $e;
        }
    }

    public function test_sync_edu_attendance_set_creates_conflict_after_cutover(): void
    {
        $cutover = Settings::eduAttendanceCutover();

        $res = Sync::apply($this->auth, [[
            'type' => 'edu_attendance.set',
            'op_id' => 'test-cutover-' . uniqid(),
            'payload' => [
                'class_id' => 1,
                'user_id' => 2,
                'date' => $cutover,
                'status' => 'present',
            ],
            'queued_at' => Dates::iso(Dates::now()),
        ]], ['auth' => $this->auth]);

        $this->assertNotEmpty($res['results']);
        $this->assertSame('conflict', $res['results'][0]['status']);

        // Verify conflict recorded in attendance_sync_conflicts
        $conflict = DB::table('attendance_sync_conflicts')
            ->where('code', 'EDU_ATTENDANCE_MOVED')
            ->where('kind', 'legacy_class')
            ->first();

        $this->assertNotNull($conflict);
        $this->assertSame('legacy_class', $conflict->kind);
    }

    public function test_validate_interval_rules_start_not_zero(): void
    {
        $errors = [];
        Selections::validateIntervalRules('attendance_rules.mezmur', [
            'intervals' => [
                ['from' => 5, 'to' => 15, 'percent' => 100],
            ],
        ], $errors);

        $this->assertNotEmpty($errors);
        $this->assertSame('INTERVAL_START_NOT_ZERO', $errors[0]['code']);
    }

    public function test_validate_interval_rules_overlap(): void
    {
        $errors = [];
        Selections::validateIntervalRules('attendance_rules.mezmur', [
            'intervals' => [
                ['from' => 0, 'to' => 15, 'percent' => 100],
                ['from' => 10, 'to' => 30, 'percent' => 70],
            ],
        ], $errors);

        $this->assertNotEmpty($errors);
        $this->assertSame('INTERVAL_OVERLAP', $errors[0]['code']);
    }

    public function test_validate_interval_rules_gap(): void
    {
        $errors = [];
        Selections::validateIntervalRules('attendance_rules.mezmur', [
            'intervals' => [
                ['from' => 0, 'to' => 15, 'percent' => 100],
                ['from' => 20, 'to' => 30, 'percent' => 70],
            ],
        ], $errors);

        $this->assertNotEmpty($errors);
        $this->assertSame('INTERVAL_GAP', $errors[0]['code']);
    }

    public function test_validate_interval_rules_invalid_bounds(): void
    {
        $errors = [];
        Selections::validateIntervalRules('attendance_rules.mezmur', [
            'intervals' => [
                ['from' => 0, 'to' => 0, 'percent' => 100],
            ],
        ], $errors);

        $this->assertNotEmpty($errors);
        $this->assertSame('INTERVAL_INVALID', $errors[0]['code']);
    }

    public function test_score_occurrence_interval(): void
    {
        $intervals = [
            ['from' => 0, 'to' => 15, 'percent' => 100],
            ['from' => 15, 'to' => 30, 'percent' => 70],
        ];

        // 1. Within first interval: 10 mins (600s) -> 100%
        $res1 = Selections::scoreOccurrenceInterval($intervals, 0, 600, 'present', 0.5);
        $this->assertSame(100.0, (float) $res1['percent']);

        // 2. Exactly at lower boundary: 15 mins (900s) -> 70% (half-open [15, 30))
        $res2 = Selections::scoreOccurrenceInterval($intervals, 0, 900, 'present', 0.5);
        $this->assertSame(70.0, (float) $res2['percent']);

        // 3. Beyond last interval: 35 mins (2100s) -> after_last_percent (0%)
        $res3 = Selections::scoreOccurrenceInterval($intervals, 0, 2100, 'present', 0.5);
        $this->assertSame(0.0, (float) $res3['percent']);

        // 4. Excused status keeps excused weight (0.5 * 100 = 50%)
        $res4 = Selections::scoreOccurrenceInterval($intervals, 0, 600, 'excused', 0.5);
        $this->assertSame(50.0, (float) $res4['percent']);

        // 5. Absent status scores 0%
        $res5 = Selections::scoreOccurrenceInterval($intervals, 0, null, 'absent', 0.5);
        $this->assertSame(0.0, (float) $res5['percent']);

        // 6. Legacy attendance with no session (elapsed null, present): scores 100%
        $res6 = Selections::scoreOccurrenceInterval($intervals, 0, null, 'present', 0.5);
        $this->assertSame(100.0, (float) $res6['percent']);
    }

    public function test_format_interval_explanation(): void
    {
        $intervals = [
            ['from' => 0, 'to' => 15, 'percent' => 100],
            ['from' => 15, 'to' => 30, 'percent' => 70],
        ];
        $exp = Selections::formatIntervalExplanation($intervals, 0);
        $this->assertStringContainsString('0-15m: 100%', $exp);
        $this->assertStringContainsString('15-30m: 70%', $exp);
        $this->assertStringContainsString('>30m: 0%', $exp);
    }
}
