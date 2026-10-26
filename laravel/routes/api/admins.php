<?php

use App\Mz\Auth\Catalog;
use App\Mz\Http\Ctx;
use App\Mz\Services\Admins;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Administrators and roles (port of admins.routes.js).
Route::prefix('admins')->middleware('mz')->group(function () {
    $permissionKeys = fn () => Z::array(Z::enum(Catalog::allKeys()))->max(count(Catalog::allKeys()));
    $roleSchema = fn () => Z::object([
        'slug' => Z::string()->trim()->min(2)->max(64)->regex('/^[a-z0-9_]+$/', 'INVALID_SLUG'),
        'name' => V::text(1, 120),
        'description' => V::optionalText(500),
        'level' => Z::number()->int()->min(1)->max(999),
        'permissions' => $permissionKeys()->default([]),
        'is_active' => Z::boolean()->optional(),
        'department_id' => V::id()->nullable()->optional(),
        'reason' => V::optionalText(500),
    ]);

    Route::get('permissions', fn () => Http::ok(Admins::permissionCatalog(Ctx::auth())))->middleware('mz:all,admins.view');
    Route::get('roles', fn () => Http::ok(Admins::listRoles(Ctx::auth())))->middleware('mz:all,admins.view');
    Route::post('roles', fn () => Http::created(Admins::createRole(Ctx::actx(), Ctx::body($roleSchema()))))->middleware('mz:all,admins.manage');
    Route::patch('roles/{id}', function () use ($roleSchema) {
        $id = Ctx::id();
        return Http::ok(Admins::updateRole(Ctx::actx(), $id, Ctx::body($roleSchema()->omit(['slug'])->partial()->strict())));
    })->middleware('mz:all,admins.manage');
    Route::delete('roles/{id}', function () {
        Admins::deleteRole(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    })->middleware('mz:all,admins.manage');

    Route::get('/', function () {
        $q = Ctx::q();
        $out = Admins::listAdmins(Ctx::auth(), ['q' => $q['q'] ?? null, 'role_id' => (int) ($q['role_id'] ?? 0) ?: null, 'status' => $q['status'] ?? null], Page::params($q));
        return Http::page($out);
    })->middleware('mz:all,admins.view');
    Route::get('{id}', fn () => Http::ok(Admins::getAdmin(Ctx::auth(), Ctx::id())))->middleware('mz:all,admins.view');
    // Administrators are always existing members: pick the member (user_id) and the role. No new
    // account is created here (members register or are added under Users first); the member keeps
    // their account, member ID and history and sets an administrator password at next sign-in.
    Route::post('/', function () use ($permissionKeys) {
        $raw = Ctx::input();
        if (! isset($raw['user_id']) && (isset($raw['full_name']) || isset($raw['phone']))) {
            throw ApiError::validation([['field' => 'user_id', 'code' => 'ADMIN_FROM_MEMBER_ONLY', 'message' => 'Choose an existing member to make an administrator']]);
        }
        $b = Ctx::body(Z::object(['user_id' => V::id(), 'role_id' => V::id(), 'permissions' => $permissionKeys()->optional()]));
        $admin = Admins::promote(Ctx::actx(), (int) $b['user_id'], (int) $b['role_id'], $b['permissions'] ?? []);
        return Http::created(['admin' => $admin, 'temporary_password' => null]);
    })->middleware('mz:all,admins.manage');
    Route::patch('{id}', function () use ($permissionKeys) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'full_name' => V::text(2, 150)->optional(),
            'phone' => V::phone()->optional(),
            'email' => V::patchEmail(),
            'role_id' => V::id()->optional(),
            'permissions' => $permissionKeys()->optional(),
            // Role permissions taken away from this one administrator (reversible).
            'revoked_permissions' => $permissionKeys()->optional(),
            'reason' => V::optionalText(500),
            'status' => Z::enum(['active', 'disabled'])->optional(),
            'member_group' => V::memberGroup(true)->refine(fn ($v) => $v !== 'children', 'INVALID_MEMBER_GROUP')->optional(),
        ])->strict());
        return Http::ok(Admins::updateAdmin(Ctx::actx(), $id, $b));
    })->middleware('mz:all,admins.manage');
    // A member becomes an administrator (keeps every member feature) / returns to member.
    Route::post('promote', function () use ($permissionKeys) {
        $b = Ctx::body(Z::object(['user_id' => V::id(), 'role_id' => V::id(), 'permissions' => $permissionKeys()->optional()]));
        return Http::ok(Admins::promote(Ctx::actx(), (int) $b['user_id'], (int) $b['role_id'], $b['permissions'] ?? []));
    })->middleware('mz:all,admins.manage');
    Route::post('{id}/demote', function () {
        $b = Ctx::body(Z::object(['reason' => V::optionalText(500)]));
        return Http::ok(Admins::demote(Ctx::actx(), Ctx::id(), $b['reason'] ?? null));
    })->middleware('mz:all,admins.manage');
    Route::post('{id}/reset-password', fn () => Http::ok(Admins::resetAdminPassword(Ctx::actx(), Ctx::id())))->middleware('mz:all,admins.manage');
});
