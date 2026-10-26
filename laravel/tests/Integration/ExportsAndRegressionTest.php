<?php

namespace Tests\Integration;

use App\Mz\Services\MemberGroups;
use Illuminate\Support\Facades\DB;

class ExportsAndRegressionTest extends IntegrationTestCase
{
    private function csvRows(string $csv): array
    {
        $lines = array_values(array_filter(explode("\n", trim(preg_replace('/^\x{FEFF}/u', '', $csv)))));
        $head = str_getcsv(array_shift($lines));
        return array_map(fn ($l) => array_combine($head, str_getcsv($l)), $lines);
    }

    public function test_multi_subject_marks_export_wide_and_long(): void
    {
        $admin = $this->member(['education.manage']);
        $class = (int) $this->as($admin, 'POST', 'edu/admin/classes', ['name' => 'IT Export class', 'academic_year' => '2019', 'semester' => 'II'])->json('data.id');
        $math = (int) $this->as($admin, 'POST', "edu/admin/classes/$class/courses", ['name' => 'Mathematics'])->json('data.id');
        $db = (int) $this->as($admin, 'POST', "edu/admin/classes/$class/courses", ['name' => 'Database'])->json('data.id');
        $am = (int) $this->as($admin, 'POST', "edu/courses/$math/assessments", ['title' => 'Final', 'max_score' => 50])->json('data.id');
        $ad = (int) $this->as($admin, 'POST', "edu/courses/$db/assessments", ['title' => 'Final', 'max_score' => 50])->json('data.id');
        $s1 = $this->member([], ['full_name' => 'IT Export One', 'member_no' => 42]);
        $s2 = $this->member([], ['full_name' => 'IT Export Two', 'member_no' => 43]);
        foreach ([$s1, $s2] as $s) DB::table('edu_enrollments')->insert(['class_id' => $class, 'user_id' => $s->id, 'program' => 'regular', 'status' => 'active']);
        DB::table('edu_scores')->insert([
            ['assessment_id' => $am, 'user_id' => $s1->id, 'score' => 42, 'status' => 'published'],
            ['assessment_id' => $am, 'user_id' => $s2->id, 'score' => 0, 'status' => 'published'],
            ['assessment_id' => $ad, 'user_id' => $s1->id, 'score' => 39, 'status' => 'published'],
        ]);

        $wide = $this->csvRows($this->as($admin, 'GET', "reports/export/education-marks?format=csv&class_id=$class&course_ids=$math,$db")->assertOk()->getContent());
        $one = collect($wide)->firstWhere('Name', 'IT Export One');
        $two = collect($wide)->firstWhere('Name', 'IT Export Two');
        $this->assertSame('42', $one['Mathematics (/50)']);
        $this->assertSame('39', $one['Database (/50)']);
        $this->assertSame('0', $two['Mathematics (/50)'], 'a real zero stays 0');
        $this->assertSame('—', $two['Database (/50)'], 'a missing mark is not 0');
        $this->assertSame('2019', $one['Academic year']);

        $long = $this->csvRows($this->as($admin, 'GET', "reports/export/education-marks?format=csv&class_id=$class&layout=long")->assertOk()->getContent());
        $this->assertCount(4, $long);
        $this->assertSame('84', collect($long)->first(fn ($r) => $r['Name'] === 'IT Export One' && $r['Subject'] === 'Mathematics')['Percent']);

        $only = $this->csvRows($this->as($admin, 'GET', "reports/export/education-marks?format=csv&class_id=$class&course_ids=$db")->getContent());
        $this->assertArrayNotHasKey('Mathematics (/50)', $only[0]);

        $this->as($admin, 'GET', "reports/export/education-marks?format=xlsx&class_id=$class")->assertOk();
        $this->as($admin, 'GET', "reports/export/education-marks?format=pdf&class_id=$class")->assertOk();
        $this->as($this->member(['reports.view']), 'GET', "reports/export/education-marks?format=csv&class_id=$class")->assertForbidden();
        $this->as($s1, 'GET', "reports/export/education-marks?format=csv&class_id=$class")->assertForbidden();
    }

    public function test_selections_without_department_criteria_keep_the_former_calculation(): void
    {
        DB::table('member_groups')->insertOrIgnore(['key' => 'it_legacy', 'name' => 'IT legacy group', 'is_active' => 1]);
        MemberGroups::forget();
        $admin = $this->member(['selection.configure', 'selection.view']);
        $m = $this->member([], ['member_group' => 'it_legacy']);
        $sid = (int) $this->as($admin, 'POST', 'selections', ['name' => 'IT legacy', 'from' => '2026-01-01', 'to' => '2026-06-30', 'member_groups' => ['it_legacy']])->assertCreated()->json('data.id');
        $this->as($admin, 'POST', "selections/$sid/status", ['status' => 'open'])->assertOk();
        $r = DB::table('selection_results')->where(['selection_id' => $sid, 'user_id' => $m->id])->first();
        $this->assertNotNull($r);
        $this->assertNull($r->outcome, 'no v2 outcome');
        $this->assertNull($r->config_version_id);
        $comp = json_decode($r->components, true);
        $this->assertArrayHasKey('mezmur_attendance', $comp);
        $this->assertArrayHasKey('course_attendance', $comp);
    }
}
