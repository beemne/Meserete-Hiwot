<?php

namespace App\Mz\Http;

use Closure;
use Illuminate\Http\Request;

/** The security headers helmet() set on every Node.js response (headers a route already set win). */
final class SecurityHeaders
{
    public function handle(Request $r, Closure $next)
    {
        $response = $next($r);
        if (function_exists('header_remove')) @header_remove('X-Powered-By');
        $h = $response->headers;
        $csp = "default-src 'self' https: data: blob:;base-uri 'self';font-src 'self' https: data:;form-action 'self';frame-ancestors 'self';img-src 'self' https: data: blob:;object-src 'none';script-src 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' https: blob:;script-src-elem 'self' 'unsafe-inline' 'unsafe-eval' 'wasm-unsafe-eval' https: blob:;worker-src 'self' blob:;connect-src 'self' https: data: blob:;style-src 'self' https: 'unsafe-inline'"
            . (config('mz.is_prod') ? ';upgrade-insecure-requests' : '');
        $defaults = [
            'Cross-Origin-Opener-Policy' => 'same-origin',
            'Cross-Origin-Resource-Policy' => 'same-origin',
            'Origin-Agent-Cluster' => '?1',
            'Referrer-Policy' => 'no-referrer',
            'Strict-Transport-Security' => 'max-age=31536000; includeSubDomains',
            'X-Content-Type-Options' => 'nosniff',
            'X-DNS-Prefetch-Control' => 'off',
            'X-Download-Options' => 'noopen',
            'X-Frame-Options' => 'SAMEORIGIN',
            'X-Permitted-Cross-Domain-Policies' => 'none',
            'X-XSS-Protection' => '0',
        ];
        // Public files decide their own CSP (PDF banners must render without a sandbox).
        if (! preg_match('#^/(files|storage)/#', '/' . ltrim($r->path(), '/'))) $defaults['Content-Security-Policy'] = $csp;
        foreach ($defaults as $k => $v) {
            if (! $h->has($k)) $h->set($k, $v);
        }
        return $response;
    }
}
