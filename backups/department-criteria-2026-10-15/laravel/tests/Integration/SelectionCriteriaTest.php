<?php

namespace Tests\Integration;

use App\Mz\Services\MemberGroups;
use App\Mz\Services\SelectionCriteria;
use Illuminate\Support\Facades\DB;

class SelectionCriteriaTest extends IntegrationTestCase
{
    private object $high;
    /** @var array<string, object> department part => an administrator of that department */
    private array $dept = [];
    private object $mez2;
    private object $evaluator;
    private array $applicants = [];
    private int $sid;

    /** An administrator of a part: education.manage / choir.manage / payments.manage held through a specific role. */
    private function partAdmin(string $part): object
    {
        $perm = SelectionCriteria::EDITORS[$part];
        $role = DB::table('roles')->insertGetId(['slug' => 'it-' . $part . '-' . uniqid(), 'name' => "IT $part admin", 'level' => 20, 'is_active' => 1]);
        DB::table('role_permissions')->insert(['role_id' => $role, 'permission_id' => DB::table('permissions')->where('key', $perm)->value('id')]);
        $u = $this->member([], ['account_type' => 'admin', 'role_id' => $role]);
        return $u;
    }

    /** An account with the general Admin role (which also holds education.manage, choir.manage and payments.manage). */
    private function generalAdmin(string $slug = 'admin'): object
    {
        return $this->member([], ['account_type' => 'admin', 'role_id' => DB::table('roles')->where('slug', $slug)->value('id')]);
    }

    protected function setUp(): void
    {
        parent::setUp();
        DB::table('member_groups')->insertOrIgnore(['key' => 'it_sel', 'name' => 'IT selection group', 'is_active' => 1]);
        MemberGroups::forget();
        $this->high = $this->member(['selection.finalize', 'selection.configure', 'selection.review', 'selection.view']);
        foreach (array_keys(SelectionCriteria::EDITORS) as $d) $this->dept[$d] = $this->partAdmin($d);
        $this->mez2 = $this->member(['choir.manage']); // a direct grant also makes a Mezmur administrator
        $this->evaluator = $this->member();
        foreach (['a' => 7, 'b' => 8, 'c' => 9] as $k => $no) $this->applicants[$k] = $this->member([], ['member_group' => 'it_sel', 'member_no' => 900000 + $no, 'full_name' => "IT Applicant $k", 'created_at' => '2025-12-01 00:00:00']);
        $this->sid = (int) $this->as($this->high, 'POST', 'selections', ['name' => 'IT ፋሲካ 2019', 'from' => '2026-01-01', 'to' => '2026-06-30', 'member_groups' => ['it_sel']])->assertCreated()->json('data.id');
    }

    private function c(string $key, string $name, float $weight, float $max, string $source = 'manual'): array
    {
        return ['key' => $key, 'name' => $name, 'source' => $source, 'weight' => $weight, 'max_score' => $max];
    }

    /** Education 50 (interview /20), Mezmur 30 (knowledge 10 /10 + practical 20 /100), dues 10 (dues /5), participation 10 (fixed, built-in); pass ≥ 60, one seat. */
    private function configure(?array $months = null): void
    {
        $base = "selections/{$this->sid}/criteria";
        $this->as($this->high, 'PUT', "$base/rules", ['passing' => ['total_minimum' => 60, 'quota' => 1] + ($months ? ['months' => $months] : [])])->assertOk();
        $this->as($this->dept['education'], 'PUT', "$base/departments/education", ['criteria' => [$this->c('interview', 'ቃለ መጠይቅ', 50, 20)]])->assertOk();
        $this->as($this->dept['mezmur'], 'PUT', "$base/departments/mezmur", ['criteria' => [$this->c('knowledge', 'Knowledge Assessment', 10, 10), $this->c('practical', 'Practical Assessment', 20, 100)]])->assertOk();
        $this->as($this->dept['dues'], 'PUT', "$base/departments/dues", ['criteria' => [$this->c('service', 'Dues', 10, 5)]])->assertOk();
        foreach (array_keys(SelectionCriteria::EDITORS) as $d) $this->as($this->dept[$d], 'POST', "$base/departments/$d/submit")->assertOk();
    }

    private function scores(object $as, string $key, array $rows): void
    {
        $this->as($as, 'PUT', "selections/{$this->sid}/criteria/scores/$key", ['scores' => $rows])->assertOk();
        $this->as($as, 'POST', "selections/{$this->sid}/criteria/scores/$key/submit")->assertOk();
    }

    public function test_the_split_is_fixed_at_50_30_10_10(): void
    {
        $v = $this->as($this->dept['education'], 'POST', "selections/{$this->sid}/criteria/draft")->assertOk()->json('data');
        $this->assertEquals(['education' => 50, 'mezmur' => 30, 'dues' => 10, 'participation' => 10], $v['allocation']);
        $w = fn ($d) => array_sum(array_column($v['departments'][$d]['criteria'], 'weight'));
        $this->assertEquals([50, 30, 10, 10], [$w('education'), $w('mezmur'), $w('dues'), $w('participation')]);
        $this->assertSame('contribution', $v['departments']['dues']['criteria'][0]['source']);
        $this->assertSame('participation', $v['departments']['participation']['criteria'][0]['source']);
        $this->assertSame('submitted', $v['departments']['participation']['status'], 'participation needs no configuration');
        // the split cannot be sent any more, and participation cannot be edited by anyone
        $this->as($this->high, 'PUT', "selections/{$this->sid}/criteria/rules", ['allocation' => ['education' => 60, 'mezmur' => 20, 'dues' => 10, 'participation' => 10], 'passing' => ['total_minimum' => 50]])->assertStatus(422);
        foreach ([$this->dept['education'], $this->generalAdmin('high_admin'), $this->high] as $u) {
            $this->as($u, 'PUT', "selections/{$this->sid}/criteria/departments/participation", ['criteria' => [$this->c('pp', 'X', 10, 10)]])->assertForbidden();
        }
    }

    public function test_each_part_is_edited_only_by_its_own_administrators(): void
    {
        $base = "selections/{$this->sid}/criteria";
        $edu = [$this->c('interview', 'Interview', 50, 20)];
        // the general Admin / High admin roles hold education.manage too — that does not open a part
        foreach (['admin', 'high_admin'] as $slug) $this->as($this->generalAdmin($slug), 'PUT', "$base/departments/education", ['criteria' => $edu])->assertForbidden();
        $this->as($this->high, 'PUT', "$base/departments/education", ['criteria' => $edu])->assertForbidden();
        // nor do unrelated permissions or another part's administrators
        $this->as($this->member(['selection.configure', 'hr.manage']), 'PUT', "$base/departments/education", ['criteria' => $edu])->assertForbidden();
        $this->as($this->dept['mezmur'], 'PUT', "$base/departments/education", ['criteria' => $edu])->assertForbidden();
        $this->as($this->dept['dues'], 'PUT', "$base/departments/mezmur", ['criteria' => [$this->c('m1', 'X', 30, 10)]])->assertForbidden();
        // the education administrators do (a specific role, or a direct grant)
        $this->as($this->member(['education.manage']), 'PUT', "$base/departments/education", ['criteria' => [$this->c('interview', 'Interview', 45, 20)]])->assertOk();
        $this->as($this->dept['education'], 'POST', "$base/departments/education/submit")->assertStatus(422); // 45 ≠ 50
        $this->as($this->dept['education'], 'PUT', "$base/departments/education", ['criteria' => $edu])->assertOk();
        $this->as($this->dept['education'], 'POST', "$base/departments/education/submit")->assertOk()->assertJsonPath('data.departments.education.status', 'submitted');
        // a revoked permission never counts
        $rev = $this->partAdmin('dues');
        DB::table('user_permission_revocations')->insert(['user_id' => $rev->id, 'permission_id' => DB::table('permissions')->where('key', 'payments.manage')->value('id')]);
        $this->as($rev, 'PUT', "$base/departments/dues", ['criteria' => [$this->c('d1', 'X', 10, 10)]])->assertForbidden();

        // the app is told exactly which parts this member may edit
        $access = $this->as($this->dept['dues'], 'GET', $base)->assertOk()->json('data.access');
        $this->assertEquals(['education' => false, 'mezmur' => false, 'dues' => true, 'participation' => false], $access['can_edit']);
        $this->assertFalse($access['can_decide']);
        $this->as($this->member(), 'GET', $base)->assertForbidden();
        $mine = $this->as($this->dept['mezmur'], 'GET', 'selection-criteria/mine')->assertOk()->json('data');
        $this->assertSame(['mezmur'], $mine['parts']);
        $this->assertContains($this->sid, array_column($mine['selections'], 'id'));
    }

    public function test_each_departments_administrators_score_their_members_participation(): void
    {
        $role = DB::table('roles')->insertGetId(['slug' => 'it-dept-' . uniqid(), 'name' => 'IT dept admin', 'level' => 15, 'is_active' => 1]);
        $deptA = (int) DB::table('departments')->where('is_active', true)->orderBy('id')->value('id');
        $deptB = (int) DB::table('departments')->where('is_active', true)->where('id', '<>', $deptA)->orderBy('id')->value('id');
        $admin = $this->member();
        DB::table('department_admins')->insert(['user_id' => $admin->id, 'department_id' => $deptA, 'role_id' => $role]);
        $m = $this->member();
        foreach ([$deptA, $deptB] as $d) DB::table('user_departments')->insert(['user_id' => $m->id, 'department_id' => $d, 'role' => 'member']);
        $period = \App\Mz\Support\Ethiopian::currentPeriod();
        $this->as($admin, 'PUT', "departments/$deptA/participation", ['period' => $period, 'entries' => [['user_id' => $m->id, 'score' => 8]]])->assertOk();
        $this->as($admin, 'PUT', "departments/$deptB/participation", ['period' => $period, 'entries' => [['user_id' => $m->id, 'score' => 8]]])->assertForbidden();
        $this->assertContains($deptA, array_map('intval', array_column($this->as($admin, 'GET', 'departments/led')->assertOk()->json('data'), 'id')));
        $this->as($this->generalAdmin(), 'PUT', "departments/$deptA/participation", ['period' => $period, 'entries' => [['user_id' => $m->id, 'score' => 5]]])->assertForbidden();
    }

    public function test_full_cycle_scoring_quota_and_mezmur_export(): void
    {
        $base = "selections/{$this->sid}/criteria";
        $this->configure();
        $this->as($this->high, 'POST', "selections/{$this->sid}/status", ['status' => 'open'])->assertStatus(409); // not approved yet
        $this->as($this->dept['education'], 'POST', "$base/decision", ['decision' => 'approve'])->assertForbidden();
        $this->as($this->high, 'POST', "$base/decision", ['decision' => 'reject'])->assertStatus(422);
        $this->as($this->high, 'POST', "$base/decision", ['decision' => 'approve', 'comment' => 'ok'])->assertOk()->assertJsonPath('data.status', 'approved');

        [$a, $b, $c] = [$this->applicants['a'], $this->applicants['b'], $this->applicants['c']];
        $this->as($this->high, 'POST', "$base/evaluators", ['criterion_key' => 'interview', 'user_id' => $this->evaluator->id])->assertForbidden();
        $this->as($this->dept['education'], 'POST', "$base/evaluators", ['criterion_key' => 'interview', 'user_id' => $this->evaluator->id])->assertOk();
        $this->as($this->evaluator, 'PUT', "$base/scores/knowledge", ['scores' => [['user_id' => $a->id, 'raw_score' => 5]]])->assertForbidden();
        $this->as($this->evaluator, 'PUT', "$base/scores/interview", ['scores' => [['user_id' => $a->id, 'raw_score' => 25]]])->assertStatus(422); // > max 20
        $this->scores($this->evaluator, 'interview', [['user_id' => $a->id, 'raw_score' => 16], ['user_id' => $b->id, 'raw_score' => 20]]);
        $this->as($this->evaluator, 'POST', "$base/scores/interview/review", ['decision' => 'approve'])->assertForbidden();
        $this->as($this->generalAdmin(), 'POST', "$base/scores/interview/review", ['decision' => 'approve'])->assertForbidden();
        $this->as($this->dept['education'], 'POST', "$base/scores/interview/review", ['decision' => 'approve'])->assertOk();

        $this->scores($this->dept['mezmur'], 'knowledge', [['user_id' => $a->id, 'raw_score' => 8], ['user_id' => $b->id, 'raw_score' => 10]]);
        $this->scores($this->dept['mezmur'], 'practical', [['user_id' => $a->id, 'raw_score' => 50], ['user_id' => $b->id, 'raw_score' => 100], ['user_id' => $c->id, 'participated' => false]]);
        $this->as($this->dept['mezmur'], 'POST', "$base/scores/knowledge/review", ['decision' => 'approve'])->assertForbidden(); // own entries
        $this->as($this->mez2, 'POST', "$base/scores/knowledge/review", ['decision' => 'approve'])->assertOk();
        $this->as($this->mez2, 'POST', "$base/scores/practical/review", ['decision' => 'approve'])->assertOk();
        $this->scores($this->dept['dues'], 'service', [['user_id' => $a->id, 'raw_score' => 5], ['user_id' => $b->id, 'raw_score' => 4]]);
        DB::table('selection_scores')->where(['selection_id' => $this->sid, 'criterion_key' => 'service'])->update(['status' => 'approved']);
        // participation: each department records its members' monthly score (a and b: full marks in Jan–Jun 2026)
        $dept = (int) DB::table('departments')->where('is_active', true)->orderBy('id')->value('id');
        $max = \App\Mz\Services\Departments::participationPolicy()['max_score'];
        foreach ([$a, $b] as $u) {
            DB::table('user_departments')->insert(['user_id' => $u->id, 'department_id' => $dept, 'role' => 'member']);
            $from = \App\Mz\Support\Ethiopian::periodOfDate('2026-01-01');
            foreach (\App\Mz\Support\Ethiopian::monthsBetween($from, \App\Mz\Support\Ethiopian::periodOfDate('2026-06-30')) as $period) {
                DB::table('department_participation')->insert(['user_id' => $u->id, 'department_id' => $dept, 'period' => $period, 'score' => $max]);
            }
        }

        $this->as($this->high, 'POST', "selections/{$this->sid}/status", ['status' => 'open'])->assertOk();
        $res = fn ($u) => DB::table('selection_results')->where(['selection_id' => $this->sid, 'user_id' => $u->id])->first();
        // a: 16/20·50 = 40 · 8/10·10 + 50/100·20 = 18 · dues 5/5·10 = 10 · participation 100 % → 10 → 78 ; b: 50 + 30 + 8 + 10 → 98 ; c: pending
        $this->assertEquals(78, (float) $res($a)->total);
        $this->assertEquals(98, (float) $res($b)->total);
        $this->assertSame('selected', $res($b)->outcome);
        $this->assertSame(1, (int) $res($b)->rank);
        $this->assertSame('eligible_not_selected', $res($a)->outcome, 'passed but beyond the quota of one');
        $this->assertSame('pending', $res($c)->outcome, 'missing evaluations are pending, never 0');
        $detail = $this->as($this->high, 'GET', "selections/{$this->sid}/results/{$a->id}")->assertOk()->json('data');
        $this->assertEquals(18, $detail['departments']['mezmur']['score']);
        $this->assertEquals(10, $detail['departments']['dues']['score']);
        $this->assertEquals(10, $detail['departments']['participation']['score']);

        // Mezmur export: Mezmur administrators only — not general admins, not the final approver
        $csv = $this->as($this->dept['mezmur'], 'GET', "reports/export/mezmur-selection?format=csv&selection_id={$this->sid}")->assertOk()->getContent();
        $this->as($this->generalAdmin(), 'GET', "reports/export/mezmur-selection?format=csv&selection_id={$this->sid}")->assertForbidden();
        $this->as($this->dept['education'], 'GET', "reports/export/mezmur-selection?format=csv&selection_id={$this->sid}")->assertForbidden();
        $this->as($this->high, 'GET', "reports/export/mezmur-selection?format=csv&selection_id={$this->sid}")->assertForbidden();
        $lines = array_values(array_filter(explode("\n", trim($csv))));
        $head = str_getcsv(preg_replace('/^\x{FEFF}/u', '', $lines[0]));
        $rowOf = fn ($name) => array_combine($head, str_getcsv(collect($lines)->first(fn ($l) => str_contains($l, $name))));
        $this->assertSame('Pending', $rowOf('IT Applicant c')['Knowledge Assessment']);
        $this->assertSame('Not participated', $rowOf('IT Applicant c')['Practical Assessment']);
        $this->assertSame('Pending', $rowOf('IT Applicant c')['Final result']);
        $this->assertSame('Provisional: Pass', $rowOf('IT Applicant a')['Final result']);

        // finalization: blocked while c is pending; an explicit decision resolves it
        $this->as($this->high, 'POST', "selections/{$this->sid}/status", ['status' => 'review'])->assertOk();
        $this->as($this->high, 'PUT', "selections/{$this->sid}/results/{$c->id}/override", ['decision' => 'not_qualified', 'reason' => 'Did not take the assessments'])->assertOk();
        foreach (['Hymns and Arts Department', 'Education and Training Department', 'Human Resources Management Department'] as $d) {
            $this->as($this->high, 'POST', "selections/{$this->sid}/reviews", ['department_name' => $d, 'decision' => 'approved'])->assertOk();
        }
        $this->as($this->high, 'POST', "selections/{$this->sid}/status", ['status' => 'finalized'])->assertOk();
        $this->as($this->mez2, 'GET', "reports/export/mezmur-selection?format=xlsx&selection_id={$this->sid}")->assertOk();
        $this->as($this->dept['mezmur'], 'GET', "reports/export/mezmur-selection?format=pdf&selection_id={$this->sid}")->assertOk();
        $this->as($this->high, 'POST', "selections/{$this->sid}/publish")->assertOk();
        $body = DB::table('notifications')->where(['user_id' => $a->id, 'dedupe_key' => "selection:{$this->sid}:published:{$a->id}"])->value('body');
        $this->assertStringContainsString('ቦታ ብዛት', (string) $body, 'eligible but beyond the quota gets its own message');
    }

    public function test_revision_does_not_change_the_version_in_force(): void
    {
        $this->configure();
        $this->as($this->high, 'POST', "selections/{$this->sid}/criteria/decision", ['decision' => 'approve'])->assertOk();
        $v1 = (int) DB::table('selection_config_versions')->where('selection_id', $this->sid)->value('id');
        $this->as($this->dept['education'], 'POST', "selections/{$this->sid}/criteria/revise")->assertCreated()->assertJsonPath('data.version', 2);
        $this->as($this->dept['education'], 'PUT', "selections/{$this->sid}/criteria/departments/education", ['criteria' => [$this->c('interview', 'ቃለ መጠይቅ', 50, 50)]])->assertOk();
        $active = $this->as($this->high, 'GET', "selections/{$this->sid}/criteria")->json('data.active');
        $this->assertSame($v1, $active['id']);
        $this->assertEquals(20, $active['departments']['education']['criteria'][0]['max_score']);
    }

    public function test_the_submitter_of_a_part_cannot_give_the_final_approval(): void
    {
        $this->grant($this->dept['dues']->id, 'selection.finalize');
        $this->configure();
        $this->as($this->dept['dues'], 'POST', "selections/{$this->sid}/criteria/decision", ['decision' => 'approve'])->assertForbidden();
        $this->as($this->high, 'POST', "selections/{$this->sid}/criteria/decision", ['decision' => 'approve'])->assertOk();
    }

    /** The department of a part (by its code), created when the test database has none. */
    private function partDepartment(string $code): int
    {
        return (int) (DB::table('departments')->where('code_prefix', $code)->value('id')
            ?? DB::table('departments')->insertGetId(['name' => "IT $code", 'code_prefix' => $code, 'is_active' => 1]));
    }

    public function test_a_parts_own_department_administrator_edits_it_even_with_the_general_admin_role(): void
    {
        // The Hymns & Arts department's administrator, assigned there with the general "Admin" role.
        $mezAdmin = $this->member();
        DB::table('department_admins')->insert(['user_id' => $mezAdmin->id, 'department_id' => $this->partDepartment('HYM'), 'role_id' => DB::table('roles')->where('slug', 'admin')->value('id')]);
        $base = "selections/{$this->sid}/criteria";
        $this->as($this->high, 'POST', "$base/draft")->assertOk();
        $this->as($mezAdmin, 'PUT', "$base/departments/mezmur", ['criteria' => [$this->c('knowledge', 'Knowledge', 30, 10)]])->assertOk();
        // …only the Mezmur part, although the Admin role also holds education.manage and payments.manage.
        $this->as($mezAdmin, 'PUT', "$base/departments/education", ['criteria' => [$this->c('interview', 'Interview', 50, 20)]])->assertForbidden();
        $this->as($mezAdmin, 'PUT', "$base/departments/dues", ['criteria' => [$this->c('dues', 'Dues', 10, 5)]])->assertForbidden();
        $res = $this->as($this->high, 'GET', $base)->assertOk();
        $this->assertContains($mezAdmin->full_name, $res->json('data.editors.mezmur'));
        $this->assertNotContains($mezAdmin->full_name, $res->json('data.editors.education'));
        $this->assertNotContains($this->high->full_name, $res->json('data.editors.mezmur'));
    }

    public function test_the_first_draft_starts_from_the_selections_own_passing_score_and_minimums(): void
    {
        $sid = (int) $this->as($this->high, 'POST', 'selections', ['name' => 'IT seed', 'from' => '2026-01-01', 'to' => '2026-06-30', 'member_groups' => ['it_sel'], 'config' => [
            'weights' => ['course_attendance' => 20, 'exam' => 30, 'mezmur_attendance' => 30, 'contribution' => 10, 'participation' => 10],
            'minimums' => ['course_attendance' => 8, 'exam' => 12, 'mezmur_attendance' => 15, 'contribution' => 3, 'participation' => 5],
            'total_minimum' => 43,
        ]])->assertCreated()->json('data.id');
        $v = $this->as($this->high, 'POST', "selections/$sid/criteria/draft")->assertOk()->json('data');
        $this->assertEqualsWithDelta(43, $v['passing']['total_minimum'], 0.0001);
        $edu = collect($v['departments']['education']['criteria'])->keyBy('key');
        $this->assertEqualsWithDelta(20, $edu['course_attendance']['weight'], 0.0001);
        $this->assertEqualsWithDelta(12, $edu['exam']['min_points'], 0.0001);
        $this->assertEqualsWithDelta(15, $v['departments']['mezmur']['criteria'][0]['min_points'], 0.0001);
        // Every section already fits its share, so each department can submit it as is.
        $this->as($this->dept['education'], 'POST', "selections/$sid/criteria/departments/education/submit")->assertOk();
    }

    public function test_the_selection_weights_must_follow_the_fixed_split(): void
    {
        $this->as($this->high, 'PATCH', "selections/{$this->sid}", ['config' => ['weights' => ['course_attendance' => 40, 'exam' => 20, 'mezmur_attendance' => 20, 'contribution' => 10, 'participation' => 10]]])
            ->assertStatus(422)->assertJsonPath('errors.0.code', 'ALLOCATION_IS_FIXED');
        $this->as($this->high, 'PATCH', "selections/{$this->sid}", ['config' => ['weights' => ['course_attendance' => 10, 'exam' => 40, 'mezmur_attendance' => 30, 'contribution' => 10, 'participation' => 10]]])->assertOk();
    }

    public function test_the_monthly_parts_are_counted_over_the_criterias_own_months(): void
    {
        $base = "selections/{$this->sid}/criteria";
        $E = \App\Mz\Support\Ethiopian::class;
        $first = $E::periodOfDate('2026-01-15');
        $range = ['from' => $first, 'to' => $E::addMonths($first, 1)];
        // Invalid ranges are refused.
        $this->as($this->high, 'PUT', "$base/rules", ['passing' => ['total_minimum' => 60, 'months' => ['from' => $range['to'], 'to' => $range['from']]]])->assertStatus(422);
        $this->as($this->high, 'PUT', "$base/rules", ['passing' => ['total_minimum' => 60, 'months' => ['from' => '2018-14', 'to' => '2018-15']]])->assertStatus(422);
        $this->configure($range);
        $this->as($this->high, 'POST', "$base/decision", ['decision' => 'approve'])->assertOk()->assertJsonPath('data.passing.months.from', $range['from']);
        // a: full participation in the two months of the range, nothing in the other months of the selection.
        $a = $this->applicants['a'];
        $dept = (int) DB::table('departments')->where('is_active', true)->orderBy('id')->value('id');
        DB::table('user_departments')->insert(['user_id' => $a->id, 'department_id' => $dept, 'role' => 'member']);
        $max = \App\Mz\Services\Departments::participationPolicy()['max_score'];
        foreach ($E::monthsBetween($first, $E::periodOfDate('2026-06-30')) as $period) {
            DB::table('department_participation')->insert(['user_id' => $a->id, 'department_id' => $dept, 'period' => $period, 'score' => in_array($period, $range, true) ? $max : 0]);
        }
        $this->as($this->high, 'POST', "selections/{$this->sid}/status", ['status' => 'open'])->assertOk();
        $d = $this->as($this->high, 'GET', "selections/{$this->sid}/results/{$a->id}")->assertOk()->json('data');
        $this->assertEquals(10, $d['departments']['participation']['score'], 'only the two months of the range count');
        $this->assertCount(2, $d['components']['participation']['detail']['months']);
    }
}
