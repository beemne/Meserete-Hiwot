<?php

namespace App\Mz\Http;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Jwt;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\RateLimiter;

/** Authentication / authorization middleware (port of middleware/auth.js and rateLimit.js). */
final class Middleware
{
    private const PASSWORD_CHANGE_ALLOWED = '#/api/v1/(auth/(change-password|me|logout)|me)/?$#';

    private static function bearer(Request $r): ?string
    {
        $h = (string) $r->header('Authorization', '');
        $parts = explode(' ', $h, 2);
        return count($parts) === 2 && strtolower($parts[0]) === 'bearer' && $parts[1] !== '' ? $parts[1] : null;
    }

    public static function resolve(Request $r): AuthContext
    {
        $token = self::bearer($r);
        if (! $token) {
            throw ApiError::unauthorized('UNAUTHORIZED', 'Authentication required');
        }
        $payload = Jwt::verify($token, (string) config('mz.jwt.secret'), (string) config('mz.jwt.issuer'), (string) config('mz.jwt.audience'));
        if (($payload['typ'] ?? null) !== 'access') {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        $ctx = AuthContext::load((int) ($payload['sub'] ?? 0));
        if (! $ctx) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        // token_version bump = device reset / password change / force logout → every old JWT dies.
        if (($payload['tv'] ?? null) !== $ctx->tokenVersion) {
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        if ($ctx->status !== 'active') {
            throw ApiError::forbidden('ACCOUNT_DISABLED', 'Account disabled');
        }
        if ($ctx->isSystem !== (($payload['scp'] ?? null) === 'system')) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        // Normal users: the token must belong to the currently trusted device.
        if ($ctx->accountType === 'user' && (! $ctx->deviceId || ($payload['did'] ?? null) !== $ctx->deviceId)) {
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        // Signed out of: this one token stops working at once (other devices / sessions are untouched).
        if (! empty($payload['jti']) && DB::table('revoked_access_tokens')->where('jti', $payload['jti'])->exists()) {
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        $ctx->tokenDeviceId = $payload['did'] ?? null;
        // A revoked session (refresh-token family) stops its access tokens at once, not at expiry.
        if (! empty($payload['sid']) && ! DB::table('refresh_tokens')->where('family_id', $payload['sid'])->whereNull('revoked_at')->exists()) {
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        $ctx->tokenSessionId = $payload['sid'] ?? null;
        $ctx->tokenId = $payload['jti'] ?? null;
        $ctx->tokenExpires = isset($payload['exp']) ? (int) $payload['exp'] : null;
        if ($ctx->mustChangePassword && ! preg_match(self::PASSWORD_CHANGE_ALLOWED, '/' . ltrim($r->path(), '/'))) {
            throw ApiError::forbidden('PASSWORD_CHANGE_REQUIRED', 'Password change required');
        }
        return $ctx;
    }

    /** 'mz.auth' */
    public function handle(Request $r, Closure $next, string $mode = 'required', string ...$keys)
    {
        switch ($mode) {
            case 'optional':
                if (self::bearer($r)) {
                    try {
                        $r->attributes->set('mz_auth', self::resolve($r));
                    } catch (ApiError) {
                        // continue anonymously
                    }
                }
                break;
            case 'admin':
                if (! Ctx::authOrNull()?->isAdmin) {
                    throw ApiError::forbidden();
                }
                break;
            case 'all':
                self::requireAll(...$keys);
                break;
            case 'any':
                self::requireAny(...$keys);
                break;
            case 'system_auth':
                // System console: any authentication failure is a plain 404 (no 401 confirming the route).
                try {
                    $r->attributes->set('mz_auth', self::resolve($r));
                } catch (ApiError) {
                    throw ApiError::notFound();
                }
                // fall through to the system check
            case 'system':
                $allowed = config('mz.system.allowed_ips', []);
                if ($allowed && ! in_array($r->ip(), $allowed, true)) {
                    throw ApiError::notFound();
                }
                if (! Ctx::authOrNull()?->isSystem) {
                    throw ApiError::notFound();
                }
                break;
            default:
                $r->attributes->set('mz_auth', self::resolve($r));
        }
        return $next($r);
    }

    private static function deny(string $permission): ApiError
    {
        $r = request();
        Audit::log(Ctx::actx(), Audit::AUTHZ_DENIED, null, null, ['permission' => $permission, 'method' => $r->method(), 'path' => '/' . ltrim($r->path(), '/')]);
        return ApiError::forbidden();
    }

    /** Require ALL listed permissions. */
    public static function requireAll(string ...$keys): void
    {
        $a = Ctx::authOrNull();
        if (! $a?->isAdmin) {
            throw ApiError::forbidden();
        }
        foreach ($keys as $k) {
            if (! $a->can($k)) {
                throw self::deny($k);
            }
        }
    }

    /** Require at least one of the listed permissions. */
    public static function requireAny(string ...$keys): void
    {
        $a = Ctx::authOrNull();
        if (! $a?->isAdmin) {
            throw ApiError::forbidden();
        }
        foreach ($keys as $k) {
            if ($a->can($k)) {
                return;
            }
        }
        throw self::deny(implode('|', $keys));
    }
}
