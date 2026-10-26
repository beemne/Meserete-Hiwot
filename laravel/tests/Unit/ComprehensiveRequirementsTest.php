<?php

namespace Tests\Unit;

use App\Mz\Auth\Audit;
use App\Mz\Services\MemberGroups;
use App\Mz\Services\ReportExport;
use App\Mz\Services\Schedule;
use App\Mz\Services\Selections;
use App\Mz\Support\Dates;
use ReflectionMethod;
use Tests\TestCase;
use Illuminate\Support\Facades\Schema;

class ComprehensiveRequirementsTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        if (! Schema::hasTable('member_groups')) {
            Schema::create('member_groups', function ($table) {
                $table->id();
                $table->string('key')->unique();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('built_in')->default(false);
                $table->timestamps();
            });
        }
        MemberGroups::forget();
    }
    public function test_audit_redact_sensitive(): void
    {
        $input = [
            'username' => 'abel',
            'password' => 'secret123',
            'pin' => '1234',
            'token' => 'jwt.token.here',
            'access_token' => 'abcxyz',
            'nested' => [
                'refresh_token' => 'refresh123',
                'secret' => 'supersecret',
                'normal_field' => 'ok_value',
            ],
            'array_list' => [
                ['password_hash' => 'hash123', 'id' => 1],
            ],
        ];

        $method = new ReflectionMethod(Audit::class, 'redactSensitive');
        $method->setAccessible(true);
        $redacted = $method->invoke(null, $input);

        $this->assertSame('abel', $redacted['username']);
        $this->assertSame('[REDACTED]', $redacted['password']);
        $this->assertSame('[REDACTED]', $redacted['pin']);
        $this->assertSame('[REDACTED]', $redacted['token']);
        $this->assertSame('[REDACTED]', $redacted['access_token']);
        $this->assertSame('[REDACTED]', $redacted['nested']['refresh_token']);
        $this->assertSame('[REDACTED]', $redacted['nested']['secret']);
        $this->assertSame('ok_value', $redacted['nested']['normal_field']);
        $this->assertSame('[REDACTED]', $redacted['array_list'][0]['password_hash']);
        $this->assertSame(1, $redacted['array_list'][0]['id']);
    }

    public function test_member_groups_has_distance_members(): void
    {
        $this->assertContains('distance_members', MemberGroups::BUILT_IN);
        $this->assertContains('youth_adult', MemberGroups::BUILT_IN);
        $this->assertContains('children', MemberGroups::BUILT_IN);
        $this->assertContains('married', MemberGroups::BUILT_IN);

        $this->assertSame('የሩቅ አባላት', MemberGroups::name('distance_members', 'am'));
        $this->assertSame('Distance Members', MemberGroups::name('distance_members', 'en'));
    }

    public function test_report_export_kinds_and_permissions(): void
    {
        $this->assertContains('education', ReportExport::KINDS);
        $this->assertContains('programs', ReportExport::KINDS);
        $this->assertContains('attendance', ReportExport::KINDS);

        $eduPerms = ReportExport::permissionsFor('education');
        $this->assertContains('education.manage', $eduPerms);

        $progPerms = ReportExport::permissionsFor('programs');
        $this->assertContains('programs.manage', $progPerms);
    }

    public function test_twice_monthly_recurrence_candidates(): void
    {
        $prog = (object) [
            'id' => 999,
            'title' => 'Twice Monthly Event',
            'starts_at' => '2026-10-01 18:00:00',
            'ends_at' => null,
            'recurrence' => 'twice_monthly',
            'recurrence_rule' => null,
            'status' => 'published',
            'requires_attendance' => true,
        ];

        $dates = Schedule::between($prog, '2026-10-01', '2026-10-31');
        $this->assertNotEmpty($dates);
        // Candidate dates should reflect 1st and 15th/interval
        $this->assertGreaterThanOrEqual(2, count($dates));
    }

    public function test_selection_default_categories_and_reviewers(): void
    {
        $this->assertSame('ለወረብ አገልግሎት የተመረጡ', Selections::CATEGORY_WEREB);
        $this->assertSame('ለመዝሙር አገልግሎት የተመረጡ', Selections::CATEGORY_MEZMUR);

        $this->assertContains('Hymns and Arts Department', Selections::DEFAULT_DEPARTMENTS);
        $this->assertContains('Education and Training Department', Selections::DEFAULT_DEPARTMENTS);
        $this->assertContains('Human Resources Management Department', Selections::DEFAULT_DEPARTMENTS);
    }
}
