<?php

namespace Tests\Integration;

use Illuminate\Support\Facades\DB;

class WeddingSelectionTest extends IntegrationTestCase
{
    private function service(object $admin, array $extra = []): int
    {
        $res = $this->as($admin, 'POST', 'weddings', ['title' => 'IT Wedding', 'service_at' => gmdate('c', time() + 7 * 86400)] + $extra);
        $res->assertCreated();
        return (int) $res->json('data.id');
    }

    public function test_members_are_selected_by_hand_without_attendance_or_exam_requirements(): void
    {
        $admin = $this->member(['choir.manage']);
        // the former criteria would have refused everyone (no attendance, no exams in the period)
        $id = $this->service($admin, ['requires_attendance' => true, 'min_attendance' => 90, 'requires_exam' => true, 'min_exam' => 90]);
        $a = $this->member();
        $b = $this->member();

        $res = $this->as($admin, 'POST', "weddings/$id/members", ['user_ids' => [$a->id, $b->id, $a->id], 'note' => 'chosen']);
        $res->assertOk();
        $this->assertEqualsCanonicalizing([$a->id, $b->id], $res->json('data.added'));
        $this->assertSame(2, DB::table('wedding_service_members')->where(['service_id' => $id, 'status' => 'selected'])->count());
        $this->assertSame($admin->id, (int) DB::table('wedding_service_members')->where(['service_id' => $id, 'user_id' => $a->id])->value('selected_by'));
        $this->assertArrayNotHasKey('min_attendance', $res->json('data'), 'requirement fields are gone from the API');
    }

    public function test_selecting_again_creates_no_duplicates(): void
    {
        $admin = $this->member(['choir.manage']);
        $id = $this->service($admin);
        $a = $this->member();
        $this->as($admin, 'POST', "weddings/$id/members", ['user_ids' => [$a->id]])->assertOk();
        $res = $this->as($admin, 'POST', "weddings/$id/members", ['user_ids' => [$a->id]]);
        $res->assertOk()->assertJsonPath('data.already_selected', [$a->id]);
        $this->assertSame(1, DB::table('wedding_service_members')->where(['service_id' => $id, 'user_id' => $a->id])->count());
    }

    public function test_ineligible_ids_refuse_the_whole_selection(): void
    {
        $admin = $this->member(['choir.manage']);
        $id = $this->service($admin);
        $ok = $this->member();
        $child = $this->member([], ['member_group' => 'children']);
        $disabled = $this->member([], ['status' => 'disabled']);
        $this->as($admin, 'POST', "weddings/$id/members", ['user_ids' => [$ok->id, $child->id, $disabled->id]])->assertStatus(422);
        $this->assertSame(0, DB::table('wedding_service_members')->where('service_id', $id)->count());
    }

    public function test_candidates_list_identifiers_and_filters(): void
    {
        $admin = $this->member(['choir.manage']);
        $id = $this->service($admin);
        $a = $this->member([], ['full_name' => 'Wedding Candidate Zeta', 'member_no' => 4242]);
        $res = $this->as($admin, 'GET', "weddings/$id/candidates?q=Candidate%20Zeta");
        $res->assertOk();
        $row = collect($res->json('data'))->firstWhere('user_id', $a->id);
        $this->assertNotNull($row);
        $this->assertNotEmpty($row['member_id']);
        $this->assertFalse($row['selected']);
        $this->assertArrayNotHasKey('attendance', $row);

        $this->as($admin, 'POST', "weddings/$id/members", ['user_ids' => [$a->id]])->assertOk();
        $sel = $this->as($admin, 'GET', "weddings/$id/candidates?q=Candidate%20Zeta&selected=true")->json('data');
        $this->assertSame([$a->id], array_column($sel, 'user_id'));
        $this->assertSame([], $this->as($admin, 'GET', "weddings/$id/candidates?q=Candidate%20Zeta&selected=false")->json('data'));
    }

    public function test_only_choir_managers_can_select(): void
    {
        $admin = $this->member(['choir.manage']);
        $id = $this->service($admin);
        $other = $this->member(['attendance.manage']);
        $this->as($other, 'POST', "weddings/$id/members", ['user_ids' => [$other->id]])->assertForbidden();
    }

    public function test_history_of_earlier_selections_is_kept(): void
    {
        $admin = $this->member(['choir.manage']);
        $id = $this->service($admin);
        $a = $this->member();
        DB::table('wedding_service_members')->insert(['service_id' => $id, 'user_id' => $a->id, 'status' => 'participated', 'snapshot' => json_encode(['attendance' => ['percent' => 80]]), 'selected_by' => $admin->id]);
        $m = collect($this->as($admin, 'GET', "weddings/$id")->json('data.members'))->firstWhere('user_id', $a->id);
        $this->assertSame('participated', $m['status']);
        $this->assertSame(80, $m['snapshot']['attendance']['percent']);
    }
}
