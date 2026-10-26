<?php

namespace App\Mz\Auth;

use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use App\Mz\Support\Jwt;
use Illuminate\Support\Facades\DB;

/** Access tokens (JWT) and rotating refresh tokens (port of tokenService.js). */
final class Tokens
{
    /** @return array{token:string, expiresIn:int} */
    public static function signAccess(object|array $user, string $scope = 'app', ?string $deviceId = null, ?string $sessionId = null): array
    {
        $user = (object) $user;
        $ttl = $scope === 'system' ? config('mz.system.access_ttl') : config('mz.jwt.access_ttl');
        $seconds = Jwt::ttlToSeconds((string) $ttl);
        $now = time();
        $claims = ['tv' => (int) ($user->token_version ?? 0), 'scp' => $scope];
        if ($deviceId) {
            $claims['did'] = $deviceId;
        }
        // The session (refresh-token family) this token belongs to: revoking the session stops it at once.
        if ($sessionId) {
            $claims['sid'] = $sessionId;
        }
        $claims += [
            'typ' => 'access',
            'iat' => $now,
            'exp' => $now + $seconds,
            'aud' => config('mz.jwt.audience'),
            'iss' => config('mz.jwt.issuer'),
            'sub' => (string) $user->id,
            'jti' => Crypto::uuid(),
        ];
        return ['token' => Jwt::sign($claims, (string) config('mz.jwt.secret')), 'expiresIn' => $seconds];
    }

    /** Stored expiry of an app session that never times out (the column is NOT NULL). */
    public const NO_EXPIRY = '2099-12-31 23:59:59';

    /**
     * When a new refresh token expires: never (JWT_REFRESH_TTL_DAYS=0 / SYSTEM_REFRESH_TTL_HOURS=0,
     * the defaults). After signing in an account stays signed in — only signing out, an
     * administrator's force-logout, a password change, a device reset or a disabled account end it.
     */
    private static function expiryOf(string $scope): int
    {
        $seconds = $scope === 'system' ? (int) config('mz.system.refresh_ttl_hours') * 3600 : (int) config('mz.jwt.refresh_ttl_days') * 86400;
        return $seconds > 0 ? time() + $seconds : strtotime(self::NO_EXPIRY . ' UTC');
    }

    /** New opaque refresh token; only its keyed hash is stored. @return array{raw:string,id:int,expiresAt:\App\Mz\Db\UtcDateTime} */
    public static function issueRefresh(int $userId, string $scope = 'app', ?string $deviceId = null, ?string $familyId = null, ?string $ip = null, ?string $userAgent = null): array
    {
        $raw = Crypto::randomToken(48);
        $familyId = $familyId ?: Crypto::uuid();
        $expires = self::expiryOf($scope);
        $expiresAt = new \App\Mz\Db\UtcDateTime('@' . $expires);
        $id = DB::table('refresh_tokens')->insertGetId([
            'user_id' => $userId,
            'token_hash' => Crypto::hmac($raw),
            'family_id' => $familyId,
            'scope' => $scope,
            'device_id' => $deviceId,
            'expires_at' => gmdate('Y-m-d H:i:s', $expires),
            'ip' => $ip ? substr($ip, 0, 45) : null,
            'user_agent' => $userAgent ? substr($userAgent, 0, 255) : null,
        ]);
        return ['raw' => $raw, 'id' => $id, 'expiresAt' => $expiresAt, 'familyId' => $familyId];
    }

    /**
     * Rotate. A session is never ended here by itself: an already-rotated token (lost response, two
     * tabs, a retry, an old copy) continues the same session as long as that session was not signed
     * out (it still has a live token); a stored expiry date is not enforced. Only a session that was
     * ended on purpose (sign-out, force-logout, device reset) is refused.
     */
    public static function rotate(string $raw, string $scope, ?string $deviceId, ?string $ip, ?string $userAgent): array
    {
        $out = DB::transaction(function () use ($raw, $scope, $deviceId, $ip, $userAgent) {
            $row = DB::table('refresh_tokens')->where('token_hash', Crypto::hmac($raw))->lockForUpdate()->first();
            if (! $row || $row->scope !== $scope) {
                throw ApiError::unauthorized('INVALID_REFRESH_TOKEN', 'Invalid refresh token');
            }
            if ($row->revoked_at) {
                $familyAlive = DB::table('refresh_tokens')->where('family_id', $row->family_id)->whereNull('revoked_at')->exists();
                if (! $familyAlive) return ['reused' => true]; // this session was signed out on purpose
                if ($row->device_id && $deviceId && $row->device_id !== $deviceId) throw ApiError::unauthorized('INVALID_REFRESH_TOKEN', 'Invalid refresh token');
                $next = self::issueRefresh($row->user_id, $scope, $row->device_id, $row->family_id, $ip, $userAgent);
                return ['userId' => $row->user_id, 'deviceId' => $row->device_id, 'refresh' => $next];
            }
            if ($row->device_id && $deviceId && $row->device_id !== $deviceId) {
                throw ApiError::unauthorized('INVALID_REFRESH_TOKEN', 'Invalid refresh token');
            }
            $next = self::issueRefresh($row->user_id, $scope, $row->device_id, $row->family_id, $ip, $userAgent);
            DB::table('refresh_tokens')->where('id', $row->id)->update(['revoked_at' => DB::raw('NOW()'), 'replaced_by' => $next['id']]);
            return ['userId' => $row->user_id, 'deviceId' => $row->device_id, 'refresh' => $next];
        });
        if (! empty($out['reused'])) {
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        return $out;
    }

    public static function revokeFamily(string $raw): ?int
    {
        $row = DB::table('refresh_tokens')->where('token_hash', Crypto::hmac($raw))->first(['family_id', 'user_id']);
        if (! $row) {
            return null;
        }
        DB::table('refresh_tokens')->where('family_id', $row->family_id)->whereNull('revoked_at')->update(['revoked_at' => DB::raw('NOW()')]);
        return $row->user_id;
    }

    public static function revokeAllForUser(int $userId): void
    {
        DB::table('refresh_tokens')->where('user_id', $userId)->whereNull('revoked_at')->update(['revoked_at' => DB::raw('NOW()')]);
    }
}
