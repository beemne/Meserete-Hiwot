<?php

namespace App\Mz\Http;

use App\Mz\Support\ApiError;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;

/**
 * Per-IP rate limits (port of middleware/rateLimit.js): 'mz.throttle:global' 300/min,
 * 'auth' 30/15min, 'reset' 10/h, 'system' 10/15min. Effectively off in tests.
 */
final class Throttle
{
    private const LIMITS = [
        'global' => [300, 60],
        'auth' => [30, 900],
        'reset' => [10, 3600],
        'system' => [10, 900],
    ];

    public function handle(Request $r, Closure $next, string $name = 'global')
    {
        [$limit, $window] = self::LIMITS[$name] ?? self::LIMITS['global'];
        if (config('mz.is_test')) {
            $limit = 10000;
        }
        $key = "mz:$name:" . $r->ip();
        if (RateLimiter::tooManyAttempts($key, $limit)) {
            throw ApiError::tooMany();
        }
        RateLimiter::hit($key, $window);
        return $next($r);
    }
}
