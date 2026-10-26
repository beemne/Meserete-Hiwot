<?php

use App\Mz\Auth\Audit;
use App\Mz\Auth\Catalog;
use App\Mz\Auth\Tokens;
use App\Mz\Http\Ctx;
use App\Mz\Services\AuthService;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// Internal system-authority API (port of system.routes.js). Every route except login/refresh needs
// a system-scope token; anyone else receives a plain 404 so the surface is not disclosed.
Route::prefix('system')->group(function () {
    Route::post('auth/login', function () {
        $b = Ctx::body(Z::object([
            'identifier' => Z::string()->trim()->min(3)->max(190),
            'password' => Z::string()->min(1)->max(128),
            'totp' => Z::string()->regex('/^\d{6}$/', 'INVALID_CODE'),
            'device_id' => Z::string()->max(128)->optional(),
        ]));
        return Http::ok(AuthService::systemLogin($b, Ctx::meta()));
    })->middleware('mz.throttle:system');
    Route::post('auth/refresh', function () {
        $b = Ctx::body(Z::object([
            'refresh_token' => Z::string(['required_error' => 'REQUIRED'])->min(20)->max(200),
            'device_id' => Z::string()->max(128)->optional(),
        ]));
        return Http::ok(AuthService::refresh($b, Ctx::meta(), 'system'));
    })->middleware('mz.throttle:system');

    Route::middleware('mz:system_auth')->group(function () {
        /** Supervision overview: every admin (hidden included), hidden + visible audit volume. */
        Route::get('overview', function () {
            $admins = DB::table('users as u')->join('roles as r', 'r.id', '=', 'u.role_id')->where('u.account_type', 'admin')->whereNull('u.deleted_at')
                ->groupBy('r.slug', 'r.name', 'r.level', 'r.is_hidden')->selectRaw('r.slug, r.name, r.level, r.is_hidden, COUNT(*) as c')->get();
            $count = fn ($q) => (int) $q->count();
            return Http::ok([
                'admins_by_role' => $admins->map(fn ($a) => ['slug' => $a->slug, 'name' => $a->name, 'level' => $a->level, 'is_hidden' => (bool) $a->is_hidden, 'count' => (int) $a->c])->all(),
                'audit_30d' => [
                    'hidden' => $count(DB::table('audit_logs')->where('is_hidden', true)->where('created_at', '>=', DB::raw('NOW() - INTERVAL 30 DAY'))),
                    'visible' => $count(DB::table('audit_logs')->where('is_hidden', false)->where('created_at', '>=', DB::raw('NOW() - INTERVAL 30 DAY'))),
                ],
                'denied_attempts_7d' => $count(DB::table('audit_logs')->where('action', Audit::AUTHZ_DENIED)->where('created_at', '>=', DB::raw('NOW() - INTERVAL 7 DAY'))),
            ]);
        });

        /** Every administrator, with no level restriction. */
        Route::get('admins', function () {
            $qb = DB::table('users as u')->join('roles as r', 'r.id', '=', 'u.role_id')->where('u.account_type', 'admin')->whereNull('u.deleted_at')
                ->select('u.id', 'u.full_name', 'u.phone', 'u.email', 'u.status', 'u.last_login_at', 'r.name as role_name', 'r.level', 'r.is_hidden')->orderByDesc('r.level');
            return Http::page(Page::paginate($qb, Page::params(Ctx::q())));
        });

        /** Force any administrator (including high-level ones) out of all sessions. */
        Route::post('admins/{id}/force-logout', function () {
            $id = Ctx::id();
            if ($id === Ctx::auth()->id) throw ApiError::badRequest('CANNOT_TARGET_SELF', 'Cannot target yourself');
            DB::transaction(function () use ($id) {
                $n = DB::table('users')->where(['id' => $id, 'account_type' => 'admin'])->update(['token_version' => DB::raw('token_version + 1')]);
                if (! $n) throw ApiError::notFound();
                Tokens::revokeAllForUser($id);
                Audit::log(Ctx::actx(), Audit::FORCE_LOGOUT, 'admin', $id, null, inTrx: true);
            });
            return Http::ok(null);
        });

        /** Replace any role's permission set (the regular API limits this by level). */
        Route::put('roles/{id}/permissions', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['permissions' => Z::array(Z::enum(Catalog::allKeys()))]));
            DB::transaction(function () use ($id, $b) {
                $role = DB::table('roles')->where('id', $id)->first();
                if (! $role || $role->is_hidden) throw ApiError::notFound();
                $pids = DB::table('permissions')->whereIn('key', $b['permissions'])->pluck('id')->all();
                DB::table('role_permissions')->where('role_id', $role->id)->delete();
                if ($pids) DB::table('role_permissions')->insert(array_map(fn ($pid) => ['role_id' => $role->id, 'permission_id' => $pid], $pids));
                Audit::log(Ctx::actx(), Audit::ADMIN_PERMISSIONS_CHANGE, 'role', $role->id, ['after' => $b['permissions']], inTrx: true);
            });
            return Http::ok(null);
        });
    });
});
