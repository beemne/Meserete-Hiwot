<?php

namespace Tests\Integration;

use App\Mz\Auth\Tokens;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;

class SessionAndPermissionTest extends IntegrationTestCase
{
    // ---------------------------------------------------------------- no automatic sign-out

    public function test_sessions_never_expire_app_or_system(): void
    {
        $u = $this->member();
        foreach (['app', 'system'] as $scope) {
            $t = Tokens::issueRefresh($u->id, $scope, $scope === 'app' ? $u->device_id : null);
            $this->assertSame(Tokens::NO_EXPIRY, DB::table('refresh_tokens')->where('id', $t['id'])->value('expires_at')->format('Y-m-d H:i:s'), $scope);
        }
        // an old session that still carries a former expiry date in the past keeps working
        $old = Tokens::issueRefresh($u->id, 'app', $u->device_id);
        DB::table('refresh_tokens')->where('id', $old['id'])->update(['expires_at' => '2020-01-01 00:00:00']);
        $this->assertSame($u->id, Tokens::rotate($old['raw'], 'app', $u->device_id, null, null)['userId']);
    }

    public function test_replaying_a_token_after_a_lost_response_keeps_the_session(): void
    {
        $u = $this->member();
        $first = Tokens::issueRefresh($u->id, 'app', $u->device_id);
        $second = Tokens::rotate($first['raw'], 'app', $u->device_id, null, null); // response "lost"
        $again = Tokens::rotate($first['raw'], 'app', $u->device_id, null, null);  // phone retries with the old token
        $this->assertSame($first['familyId'], $again['refresh']['familyId']);
        $this->assertNull(DB::table('refresh_tokens')->where('id', $second['refresh']['id'])->value('revoked_at'), 'the earlier replacement stays valid too');
        $this->assertNull(DB::table('refresh_tokens')->where('id', $again['refresh']['id'])->value('revoked_at'));
        // the session still works afterwards
        $this->assertSame($u->id, Tokens::rotate($again['refresh']['raw'], 'app', $u->device_id, null, null)['userId']);
    }

    public function test_an_old_copy_of_a_token_never_signs_out_but_a_signed_out_session_stays_out(): void
    {
        $u = $this->member();
        $first = Tokens::issueRefresh($u->id, 'app', $u->device_id);
        $second = Tokens::rotate($first['raw'], 'app', $u->device_id, null, null);
        $third = Tokens::rotate($second['refresh']['raw'], 'app', $u->device_id, null, null);
        DB::table('refresh_tokens')->where('id', $first['id'])->update(['revoked_at' => DB::raw('NOW() - INTERVAL 10 DAY')]);
        // an old copy (restored backup, lost response days ago…) continues the session
        $this->assertSame($u->id, Tokens::rotate($first['raw'], 'app', $u->device_id, null, null)['userId']);
        $this->assertSame($u->id, Tokens::rotate($third['refresh']['raw'], 'app', $u->device_id, null, null)['userId'], 'the other copy keeps working too');
        // once the member signs out, no copy brings the session back
        Tokens::revokeFamily($first['raw']);
        try {
            Tokens::rotate($first['raw'], 'app', $u->device_id, null, null);
            $this->fail('a signed-out session must stay signed out');
        } catch (ApiError $e) {
            $this->assertSame('SESSION_REVOKED', $e->errorCode);
        }
    }

    public function test_two_tabs_refreshing_with_the_same_token_both_stay_signed_in(): void
    {
        $u = $this->member();
        $first = Tokens::issueRefresh($u->id, 'app', $u->device_id);
        $tabA = Tokens::rotate($first['raw'], 'app', $u->device_id, null, null);
        Tokens::rotate($tabA['refresh']['raw'], 'app', $u->device_id, null, null);          // tab A refreshes again at once
        $tabB = Tokens::rotate($first['raw'], 'app', $u->device_id, null, null);            // tab B still had the first token
        $this->assertSame($u->id, Tokens::rotate($tabB['refresh']['raw'], 'app', $u->device_id, null, null)['userId']);
        $this->assertGreaterThan(0, DB::table('refresh_tokens')->where('family_id', $first['familyId'])->whereNull('revoked_at')->count());
    }

    public function test_an_admin_signed_in_on_two_devices_is_not_signed_out_of_the_first(): void
    {
        $role = DB::table('roles')->where('slug', 'admin')->value('id');
        $phone = '09' . random_int(10000000, 99999999);
        $admin = $this->member([], ['account_type' => 'admin', 'role_id' => $role, 'phone' => \App\Mz\Support\V::normalizePhone($phone), 'password_hash' => \App\Mz\Auth\Passwords::hash('4826'), 'device_id' => null]);
        $login = fn ($device) => $this->json('POST', '/api/v1/auth/login', ['identifier' => $phone, 'password' => '4826', 'device_id' => $device])->assertOk()->json('data');
        $web = $login('web-it-device-1');
        $mobile = $login('android-it-device-2');
        foreach ([$web, $mobile] as $s) {
            $this->json('GET', '/api/v1/me', [], ['Authorization' => 'Bearer ' . $s['access_token']])->assertOk();
            $this->json('POST', '/api/v1/auth/refresh', ['refresh_token' => $s['refresh_token']])->assertOk();
        }
    }

    // ---------------------------------------------------------------- cancelling a mistaken excuse

    private function approvedPermission(): array
    {
        $admin = $this->member(['attendance.manage']);
        $member = $this->member();
        $p = $this->program();
        $this->as($member, 'POST', "programs/{$p->id}/permission", ['reason' => 'travel'])->assertSuccessful();
        $req = DB::table('permission_requests')->where(['program_id' => $p->id, 'user_id' => $member->id])->first();
        $this->as($admin, 'PATCH', "permissions/{$req->id}", ['status' => 'approved'])->assertOk();
        return [$admin, $member, $p, $req];
    }

    public function test_admin_cancels_an_excuse_approved_by_mistake(): void
    {
        [$admin, $member, $p, $req] = $this->approvedPermission();
        $this->assertSame('excused', DB::table('attendance')->where(['program_id' => $p->id, 'user_id' => $member->id])->value('status'));

        $res = $this->as($admin, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'Approved the wrong member']);
        $res->assertOk()->assertJsonPath('data.status', 'cancelled');

        $row = DB::table('permission_requests')->where('id', $req->id)->first();
        $this->assertSame('cancelled', $row->status);
        $this->assertSame($admin->id, (int) $row->cancelled_by);
        $this->assertSame('Approved the wrong member', $row->cancel_reason);
        $this->assertNotNull($row->cancelled_at);
        $this->assertFalse(DB::table('attendance')->where(['program_id' => $p->id, 'user_id' => $member->id])->exists(), 'excused mark removed');
        $this->assertTrue(DB::table('audit_logs')->where(['action' => 'permission.cancel', 'entity_id' => $req->id])->exists());
        $this->assertTrue(DB::table('notifications')->where('user_id', $member->id)->where('dedupe_key', 'like', "permission:{$req->id}:cancelled:%")->exists());

        // repeating is harmless: still one audit entry, still cancelled
        $this->as($admin, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'again'])->assertOk();
        $this->assertSame(1, DB::table('audit_logs')->where(['action' => 'permission.cancel', 'entity_id' => $req->id])->count());
    }

    public function test_cancel_keeps_an_excuse_set_by_the_attendance_taker(): void
    {
        [$admin, $member, $p, $req] = $this->approvedPermission();
        DB::table('attendance')->where(['program_id' => $p->id, 'user_id' => $member->id])->update(['notes' => 'sick note shown to taker']);
        $this->as($admin, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'mistake'])->assertOk();
        $this->assertSame('excused', DB::table('attendance')->where(['program_id' => $p->id, 'user_id' => $member->id])->value('status'));
    }

    public function test_only_approved_requests_can_be_cancelled_and_only_by_attendance_managers(): void
    {
        [$admin, $member, , $req] = $this->approvedPermission();
        $this->as($member, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'self'])->assertForbidden();
        $this->as($admin, 'POST', "permissions/{$req->id}/cancel", [])->assertStatus(422);
        DB::table('permission_requests')->where('id', $req->id)->update(['status' => 'pending']);
        $this->as($admin, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'x y z'])->assertStatus(409);
    }

    public function test_unrelated_roles_and_permissions_are_untouched(): void
    {
        [$admin, , , $req] = $this->approvedPermission();
        $before = DB::table('user_permissions')->where('user_id', $admin->id)->count();
        $this->as($admin, 'POST', "permissions/{$req->id}/cancel", ['reason' => 'mistake'])->assertOk();
        $this->assertSame($before, DB::table('user_permissions')->where('user_id', $admin->id)->count());
    }
}
