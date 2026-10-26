<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;

/**
 * The account's sign-in sessions (one per refresh-token family). "Deleting" a session revokes it:
 * the account itself is never touched. Revoking stops the session's refresh token and — through the
 * session id in its access tokens — every request it makes from then on.
 */
final class Sessions
{
    public static function list(AuthContext $auth): array
    {
        $rows = DB::table('refresh_tokens')->where('user_id', $auth->id)->whereNull('revoked_at')
            ->orderByDesc('created_at')->get(['family_id', 'device_id', 'ip', 'user_agent', 'scope', 'created_at', 'expires_at']);
        $out = [];
        foreach ($rows as $r) {
            if (isset($out[$r->family_id])) continue;
            $started = DB::table('refresh_tokens')->where('family_id', $r->family_id)->min('created_at');
            $out[$r->family_id] = [
                'id' => $r->family_id,
                'device_id' => $r->device_id,
                'ip' => $r->ip,
                'user_agent' => $r->user_agent,
                'signed_in_at' => \App\Mz\Support\Dates::of($started),
                'last_active_at' => $r->created_at,
                'expires_at' => $r->expires_at,
                'current' => $auth->tokenSessionId !== null && $auth->tokenSessionId === $r->family_id,
            ];
        }
        return array_values($out);
    }

    private static function revokeFamilies(int $userId, array $families): int
    {
        if (! $families) return 0;
        return DB::table('refresh_tokens')->where('user_id', $userId)->whereIn('family_id', $families)->whereNull('revoked_at')->update(['revoked_at' => DB::raw('NOW()')]);
    }

    public static function revoke(array $actx, string $sessionId): void
    {
        $auth = $actx['auth'];
        if (! DB::table('refresh_tokens')->where(['user_id' => $auth->id, 'family_id' => $sessionId])->exists()) {
            throw ApiError::notFound('SESSION_NOT_FOUND', 'Session not found');
        }
        self::revokeFamilies($auth->id, [$sessionId]);
        Audit::log($actx, Audit::SESSION_REVOKE, 'user', $auth->id, ['session' => substr($sessionId, 0, 8), 'current' => $sessionId === $auth->tokenSessionId], $auth->isSystem);
    }

    /** Every session except the one making this request. */
    public static function revokeOthers(array $actx): int
    {
        $auth = $actx['auth'];
        $q = DB::table('refresh_tokens')->where('user_id', $auth->id)->whereNull('revoked_at');
        if ($auth->tokenSessionId) $q->where('family_id', '<>', $auth->tokenSessionId);
        $families = $q->distinct()->pluck('family_id')->all();
        self::revokeFamilies($auth->id, $families);
        // Older access tokens without a session id end through the token version bump; the current
        // session is kept only when it carries its id.
        if (! $auth->tokenSessionId) DB::table('users')->where('id', $auth->id)->update(['token_version' => DB::raw('token_version + 1')]);
        Audit::log($actx, Audit::SESSION_REVOKE_OTHERS, 'user', $auth->id, ['sessions' => count($families)], $auth->isSystem);
        return count($families);
    }

    /** Sign out everywhere, this phone included. */
    public static function revokeAll(array $actx): void
    {
        $auth = $actx['auth'];
        DB::transaction(function () use ($actx, $auth) {
            DB::table('refresh_tokens')->where('user_id', $auth->id)->whereNull('revoked_at')->update(['revoked_at' => DB::raw('NOW()')]);
            DB::table('users')->where('id', $auth->id)->update(['token_version' => DB::raw('token_version + 1')]);
            Audit::log($actx, Audit::SESSION_REVOKE_ALL, 'user', $auth->id, null, $auth->isSystem, inTrx: true);
        });
    }
}
