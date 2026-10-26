<?php

namespace Tests\Integration;

use App\Mz\Support\TextRepair;
use Illuminate\Support\Facades\DB;

/** Follow-up requests of 2026-10-14. */
class FollowUpFixesTest extends IntegrationTestCase
{
    public function test_a_member_can_no_longer_cancel_an_approved_excuse(): void
    {
        $admin = $this->member(['attendance.manage']);
        $member = $this->member();
        $p = $this->program();
        $this->as($member, 'POST', "programs/{$p->id}/permission", ['reason' => 'travel'])->assertSuccessful()->assertJsonPath('data.permission.can_cancel', true);
        $req = DB::table('permission_requests')->where(['program_id' => $p->id, 'user_id' => $member->id])->first();
        $this->as($admin, 'PATCH', "permissions/{$req->id}", ['status' => 'approved'])->assertOk();

        $this->as($member, 'GET', "programs/{$p->id}")->assertOk()->assertJsonPath('data.permission.can_cancel', false);
        $this->as($member, 'DELETE', "programs/{$p->id}/permission")->assertStatus(409);
        $this->assertSame('approved', DB::table('permission_requests')->where('id', $req->id)->value('status'));
        // the administrator can still undo a mistaken approval
        $this->as($admin, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'approved by mistake'])->assertOk()->assertJsonPath('data.status', 'cancelled');
    }

    public function test_a_wedding_service_is_created_with_its_participants_in_one_step(): void
    {
        $admin = $this->member(['choir.manage']);
        $a = $this->member([], ['full_name' => 'IT Wed One']);
        $b = $this->member([], ['full_name' => 'IT Wed Two']);
        $res = $this->as($admin, 'POST', 'weddings', ['title' => 'IT ሰርግ', 'service_at' => gmdate('c', time() + 86400 * 5), 'user_ids' => [$a->id, $b->id]]);
        $res->assertCreated();
        $this->assertEqualsCanonicalizing([$a->id, $b->id], array_column($res->json('data.members'), 'user_id'));

        // the picker before the service exists
        $this->assertContains($a->id, array_column($this->as($admin, 'GET', 'weddings/eligible?q=IT%20Wed%20One')->assertOk()->json('data'), 'user_id'));

        // one ineligible member: neither the service nor any participant is saved
        $before = DB::table('wedding_services')->count();
        $child = $this->member([], ['member_group' => 'children']);
        $this->as($admin, 'POST', 'weddings', ['title' => 'IT ሰርግ 2', 'service_at' => gmdate('c', time() + 86400 * 6), 'user_ids' => [$a->id, $child->id]])->assertStatus(422);
        $this->assertSame($before, DB::table('wedding_services')->count());
    }

    public function test_twice_a_month_programs_keep_their_day_or_weekday_rule(): void
    {
        $admin = $this->member(['programs.manage']);
        // 2026-11-07 is the 1st Saturday (Addis Ababa) → 1st and 3rd Saturdays
        $res = $this->as($admin, 'POST', 'programs', ['title' => 'IT twice', 'starts_at' => '2026-11-07T06:00:00Z', 'recurrence' => 'twice_monthly', 'monthly_rule' => 'nth_weekday', 'status' => 'published']);
        $res->assertSuccessful();
        $this->assertSame('nth_weekday', $res->json('data.monthly_rule'));
        $dates = array_column($res->json('data.upcoming_occurrences'), 'date');
        $this->assertContains('2026-11-21', $dates, '3rd Saturday');
        $this->assertNotContains('2026-11-14', $dates);

        $days = $this->as($admin, 'POST', 'programs', ['title' => 'IT twice days', 'starts_at' => '2026-11-03T06:00:00Z', 'recurrence' => 'twice_monthly', 'status' => 'published']);
        $this->assertSame('day_of_month', $days->json('data.monthly_rule'));
        $this->assertContains('2026-11-17', array_column($days->json('data.upcoming_occurrences'), 'date'), 'day 3 and day 17');
    }

    public function test_text_saved_as_question_marks_is_restored_from_the_dump(): void
    {
        $id = DB::table('items')->insertGetId(['name' => '???? ???', 'code' => 'IT-Q-1', 'category' => 'equipment', 'quantity' => 1, 'available_quantity' => 1, 'condition' => 'good']);
        $sql = "INSERT INTO `items` (`id`, `name`, `code`, `category`, `condition`) VALUES\n($id, 'የሙከራ ዕቃ', 'IT-Q-1', 'equipment', 'good'),\n(999999, 'ሌላ', 'X', NULL, NULL);\n";
        $this->assertCount(1, TextRepair::repair($sql, 'items', true), 'only the "?" value');
        TextRepair::repair($sql, 'items', false);
        $this->assertSame('የሙከራ ዕቃ', DB::table('items')->where('id', $id)->value('name'));
        $this->assertSame('good', DB::table('items')->where('id', $id)->value('condition'), 'real values are left alone');
        $this->assertSame([], TextRepair::repair($sql, 'items', true));
    }

    public function test_a_subject_added_from_another_class_is_fully_visible_to_the_student(): void
    {
        $admin = $this->member(['education.manage']);
        $teacher = $this->member();
        $second = $this->member();
        $own = (int) $this->as($admin, 'POST', 'edu/admin/classes', ['name' => 'IT Own'])->json('data.id');
        $other = (int) $this->as($admin, 'POST', 'edu/admin/classes', ['name' => 'IT Other class'])->json('data.id');
        $added = (int) $this->as($admin, 'POST', "edu/admin/classes/$other/courses", ['name' => 'Added subject', 'teacher_user_id' => $teacher->id])->json('data.id');
        $notMine = (int) $this->as($admin, 'POST', "edu/admin/classes/$other/courses", ['name' => 'Not taken'])->json('data.id');
        $s = $this->member();
        DB::table('edu_enrollments')->insert(['class_id' => $own, 'user_id' => $s->id, 'program' => 'regular', 'status' => 'active']);
        $this->as($admin, 'POST', "edu/admin/students/{$s->id}/subjects", ['course_id' => $added, 'action' => 'add'])->assertOk();

        $classes = collect($this->as($s, 'GET', 'edu/overview')->assertOk()->json('data.classes'));
        $this->assertTrue($classes->firstWhere('id', $other)['added_subjects_only'] ?? false, 'the other class is listed');
        $this->as($s, 'GET', "edu/classes/$other")->assertOk()->assertJsonPath('data.has_added_subjects', true);

        $this->as($teacher, 'POST', "edu/courses/$added/assignments", ['title' => 'Essay'])->assertSuccessful();
        $this->as($admin, 'POST', "edu/courses/$notMine/assignments", ['title' => 'Other essay'])->assertSuccessful();
        $work = $this->as($s, 'GET', "edu/classes/$other/my-assignments")->assertOk()->json('data');
        $this->assertSame(['Essay'], array_column($work, 'title'), 'only the subject the student takes');
        $this->as($s, 'POST', "edu/assignments/{$work[0]['id']}/submit", ['text' => 'My essay'])->assertOk();

        $a = (int) $this->as($teacher, 'POST', "edu/courses/$added/assessments", ['title' => 'Final', 'max_score' => 20])->json('data.id');
        $this->as($teacher, 'PUT', "edu/assessments/$a/scores", ['scores' => [['user_id' => $s->id, 'score' => 17]]])->assertOk();
        $this->as($teacher, 'POST', "edu/assessments/$a/submit")->assertOk();
        $this->as($admin, 'POST', "edu/admin/assessments/$a/review", ['decision' => 'approve', 'publish' => true])->assertOk();
        $res = collect($this->as($s, 'GET', "edu/classes/$other/my-results")->assertOk()->json('data.courses'));
        $this->assertEquals(17, $res->firstWhere('course.id', $added)['assessments'][0]['score']);
        $this->assertNull($res->firstWhere('course.id', $notMine), 'a subject not taken is not listed');

        // a second teacher (Teachers list, not the main teacher) is a teacher of the class
        $this->as($admin, 'POST', "edu/admin/courses/$added/teachers", ['user_id' => $second->id])->assertCreated();
        $this->as($second, 'GET', "edu/classes/$other")->assertOk()->assertJsonPath('data.is_teacher', true)->assertJsonPath('data.takes_attendance', true);
    }
}
