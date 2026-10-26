<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\ProfileChanges;
use App\Mz\Services\Targeting;
use App\Mz\Services\UserAdmin;
use App\Mz\Support\Http;
use App\Mz\Support\MemberSchemas;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Admin: regular member management (port of users.routes.js). Every route is permission-gated.
Route::prefix('users')->middleware('mz')->group(function () {
    Route::get('/', function () {
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'status' => Z::enum(['active', 'disabled', 'pending'])->optional(),
            'program_id' => Z::coerceNumber()->int()->positive()->optional(),
            'registered_from' => V::dateOnly()->optional(),
            'registered_to' => V::dateOnly()->optional(),
            'has_active_borrowing' => Z::enum(['true', 'false'])->transform(fn ($v) => $v === 'true')->optional(),
            'sort' => Z::enum(['recent', 'name'])->optional(),
            'member_group' => V::memberGroup()->optional(),
            'membership_status' => Z::enum(MemberSchemas::MEMBERSHIP_STATUSES)->optional(),
            'can_login' => Z::enum(['true', 'false'])->transform(fn ($v) => $v === 'true')->optional(),
            // Categorized filters (personal · membership · account · activity).
            ...V::userFilterQuery(),
        ]));
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        return Http::page(UserAdmin::list($q, $page));
    })->middleware('mz:all,users.view');

    Route::post('bulk/preview', function () {
        $ids = Targeting::resolve(Ctx::body(V::bulkTarget()));
        return Http::ok(['count' => count($ids), 'sample_ids' => array_slice($ids, 0, 20)]);
    })->middleware('mz:all,users.view');

    Route::get('change-requests', function () {
        $q = Ctx::q();
        $status = in_array($q['status'] ?? null, ['pending', 'approved', 'rejected', 'all'], true) ? $q['status'] : 'pending';
        $search = is_string($q['q'] ?? null) ? mb_substr($q['q'], 0, 100) : null;
        $out = ProfileChanges::list($status, $search, Page::params($q));
        return Http::ok($out['items'], $out['meta'] + ['pending' => ProfileChanges::pendingCount()]);
    })->middleware('mz:all,users.view');
    Route::post('change-requests/{id}/approve', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['reason' => Z::string()->trim()->max(500)->optional()]));
        ProfileChanges::review(Ctx::actx(), $id, true, $b['reason'] ?? null);
        return Http::ok(null, null, 'Approved');
    })->middleware('mz:all,users.update');
    Route::post('change-requests/{id}/reject', function () {
        $id = Ctx::id();
        // Declining always says why (the member sees the reason).
        $b = Ctx::body(Z::object(['reason' => Z::string()->trim()->min(2)->max(500)]));
        ProfileChanges::review(Ctx::actx(), $id, false, $b['reason']);
        return Http::ok(null, null, 'Rejected');
    })->middleware('mz:all,users.update');

    Route::get('{id}', fn () => Http::ok(UserAdmin::detail(Ctx::id())))->middleware('mz:all,users.view');
    // Every change of a member's details, field by field (old → new), newest first.
    Route::get('{id}/profile-history', fn () => Http::page(ProfileChanges::history(Ctx::id(), Page::params(Ctx::q()))))->middleware('mz:all,users.view');
    Route::post('/', function () {
        $b = Ctx::body(Z::object(array_merge([
            'full_name' => V::text(2, 150),
            'phone' => V::phone()->optional(),
            'email' => V::optionalEmail(),
            'password' => V::password()->optional(),
        ], MemberSchemas::memberFields())));
        return Http::created(UserAdmin::create(Ctx::actx(), $b));
    })->middleware('mz:all,users.create');
    Route::patch('{id}', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(array_merge([
            'full_name' => V::text(2, 150)->optional(),
            'phone' => V::phone()->optional(),
            'email' => V::patchEmail(),
        ], MemberSchemas::memberFields()))->strict());
        return Http::ok(UserAdmin::update(Ctx::actx(), $id, $b));
    })->middleware('mz:all,users.update');
    Route::post('{id}/disable', fn () => Http::ok(UserAdmin::setStatus(Ctx::actx(), Ctx::id(), 'disabled')))->middleware('mz:all,users.disable');
    Route::post('{id}/enable', fn () => Http::ok(UserAdmin::setStatus(Ctx::actx(), Ctx::id(), 'active')))->middleware('mz:all,users.disable');
    Route::delete('{id}', function () {
        UserAdmin::softDelete(Ctx::actx(), Ctx::id());
        return Http::ok(null, null, 'Deleted');
    })->middleware('mz:all,users.disable');
    Route::post('{id}/reset-password', fn () => Http::ok(UserAdmin::resetPassword(Ctx::actx(), Ctx::id())))->middleware('mz:all,users.update');

    Route::get('{id}/devices', function () {
        $out = UserAdmin::deviceHistory(Ctx::id(), Page::params(Ctx::q()));
        return Http::ok(['current' => $out['current'], 'history' => $out['items']], $out['meta']);
    })->middleware('mz:all,users.view');
    Route::post('{id}/reset-device', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['reason' => Z::string()->trim()->max(255)->optional()]));
        return Http::ok(UserAdmin::resetDevice(Ctx::actx(), $id, $b['reason'] ?? null), null, 'Device reset');
    })->middleware('mz:all,users.reset_device');
    Route::post('{id}/force-logout', function () {
        UserAdmin::forceLogout(Ctx::actx(), Ctx::id());
        return Http::ok(null, null, 'Logged out');
    })->middleware('mz:all,users.reset_device');
});
