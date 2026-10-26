<?php

namespace Tests\Integration;

use App\Mz\Support\Crypto;
use Illuminate\Support\Facades\DB;

/**
 * What must keep working next to the attendance-session release: Mezmur playback, borrowing
 * signatures (a separate store from attendance signatures), monthly contributions ("paid after
 * due month" stays a financial rule) and holiday selections that read attendance (legacy late rows).
 */
class AttendanceRegressionTest extends IntegrationTestCase
{
    private const PNG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

    public function test_mezmur_detail_and_playback_tracking(): void
    {
        $user = $this->member();
        $id = DB::table('mezmurs')->insertGetId(['title' => 'IT á‹áˆ›áˆ¬', 'lyrics' => 'á‰…á‹±áˆµ', 'status' => 'published']);
        $this->as($user, 'GET', "mezmurs/$id")->assertOk()->assertJsonPath('data.id', $id);
        $event = Crypto::uuid();
        $this->as($user, 'POST', 'me/activity', ['action' => 'audio_play', 'entity_type' => 'mezmur', 'entity_id' => $id, 'client_event_id' => $event])->assertSuccessful();
        $this->as($user, 'POST', 'me/activity', ['action' => 'audio_play', 'entity_type' => 'mezmur', 'entity_id' => $id, 'client_event_id' => $event])->assertSuccessful();
        $this->assertSame(1, DB::table('activity_logs')->where(['user_id' => $user->id, 'action' => 'audio_play', 'entity_id' => $id])->count());
    }

    public function test_borrowing_signatures_stay_with_borrowings(): void
    {
        $staff = $this->member(['borrowing.manage']);
        $member = $this->member();
        $item = DB::table('items')->insertGetId(['name' => 'IT Drum', 'code' => 'IT-SIG-1', 'category' => 'equipment', 'quantity' => 2, 'available_quantity' => 2, 'condition' => 'good', 'direct_borrowable' => 1]);
        $b = $this->as($staff, 'POST', 'borrowings', ['user_id' => $member->id, 'item_id' => $item, 'quantity' => 1, 'signature' => self::PNG])->assertCreated()->json('data');
        $bid = $b['id'] ?? $b['borrowing']['id'] ?? $b['borrowings'][0]['id'];
        $this->assertTrue(DB::table('borrowing_signatures')->where(['borrowing_id' => $bid, 'user_id' => $member->id])->exists());
        $this->assertFalse(DB::table('attendance_signatures')->where('user_id', $member->id)->exists());
        $this->as($staff, 'GET', "borrowings/$bid/signature")->assertOk();
    }

    public function test_contributions_still_count_paid_after_due_month(): void
    {
        $staff = $this->member(['payments.manage', 'payments.view']);
        $member = $this->member([], ['member_type' => 'worker']);
        DB::table('payment_rates')->insert(['member_type' => 'worker', 'monthly_amount' => 50, 'effective_from' => '2020-01-01']);
        $period = gmdate('Y-m');
        $this->as($staff, 'POST', 'payments', ['user_id' => $member->id, 'period' => $period, 'method' => 'cash'])->assertCreated();
        $mine = $this->as($member, 'GET', 'me/payments')->assertOk()->json('data');
        $month = collect($mine['months'] ?? [])->firstWhere('period', $period);
        $this->assertNotNull($month);
        $this->assertContains($month['status'], ['paid', 'late'], 'the financial paid / paid-after-due rule is unchanged');
    }

    public function test_selection_scores_legacy_late_rows_and_finalizes(): void
    {
        $admin = $this->member(['selection.configure', 'selection.view', 'selection.review', 'selection.finalize']);
        $m = $this->member([], ['created_at' => '2025-06-01 00:00:00']);
        $cat = DB::table('program_categories')->insertGetId(['name' => 'IT Mezmur practice']);
        $ids = [];
        foreach (['2026-02-01', '2026-02-08'] as $d) {
            $ids[] = DB::table('programs')->insertGetId(['title' => "IT practice $d", 'starts_at' => "$d 06:00:00", 'ends_at' => "$d 08:00:00", 'status' => 'published', 'requires_attendance' => 1, 'audience' => 'all', 'category_id' => $cat]);
        }
        // One present, one recorded "late" before sessions existed: both are attendance.
        DB::table('attendance')->insert([
            ['program_id' => $ids[0], 'user_id' => $m->id, 'occurrence_date' => '2026-02-01', 'status' => 'present', 'attended_at' => '2026-02-01 06:10:00', 'via' => 'manual'],
            ['program_id' => $ids[1], 'user_id' => $m->id, 'occurrence_date' => '2026-02-08', 'status' => 'late', 'attended_at' => '2026-02-08 06:40:00', 'via' => 'manual'],
        ]);
        $sid = (int) $this->as($admin, 'POST', 'selections', ['name' => 'IT regression', 'from' => '2026-01-01', 'to' => '2026-03-31', 'member_groups' => ['youth_adult'],
            'config' => ['mezmur' => ['category_ids' => [$cat], 'included_program_ids' => [], 'excluded_program_ids' => []]]])->assertCreated()->json('data.id');
        $this->as($admin, 'POST', "selections/$sid/status", ['status' => 'open'])->assertOk();
        $r = DB::table('selection_results')->where(['selection_id' => $sid, 'user_id' => $m->id])->first();
        $this->assertNotNull($r);
        $comp = json_decode($r->components, true);
        $this->assertEquals(100, $comp['mezmur_attendance']['percent'], 'legacy late kept its saved points');
        $this->as($admin, 'POST', "selections/$sid/status", ['status' => 'review'])->assertOk();
        DB::table('holiday_selections')->where('id', $sid)->update(['required_departments' => '[]']);
        $this->as($admin, 'POST', "selections/$sid/status", ['status' => 'finalized', 'reason' => 'IT'])->assertOk();
        $this->assertSame('finalized', DB::table('holiday_selections')->where('id', $sid)->value('status'));
    }
}
