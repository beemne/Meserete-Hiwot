<?php

namespace App\Mz\Http;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Settings;
use App\Mz\Support\ApiError;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * 'mz.module:education' — the module switch (Settings → modules.policy) enforced by the server, not
 * only hidden in the app. Runs after 'mz' (needs the signed-in account). The hidden system authority
 * and the module's own administrators (education.manage / register / content) keep access so they
 * can still run it while it is switched off for them as members.
 */
final class ModuleGate
{
    private const STAFF = ['education' => ['education.manage', 'education.register', 'education.content']];

    public static function allows(AuthContext $auth, string $module): bool
    {
        if ($auth->isSystem) return true;
        foreach (self::STAFF[$module] ?? [] as $k) {
            if ($auth->can($k)) return true;
        }
        $group = DB::table('users')->where('id', $auth->id)->value('member_group');
        return (bool) (Settings::resolveModuleAccess($auth->id, $group)[$module] ?? true);
    }

    public static function assert(AuthContext $auth, string $module): void
    {
        if (! self::allows($auth, $module)) throw ApiError::forbidden('MODULE_DISABLED', 'This section is turned off for your account');
    }

    public function handle(Request $r, Closure $next, string $module)
    {
        self::assert(Ctx::auth(), $module);
        return $next($r);
    }
}
