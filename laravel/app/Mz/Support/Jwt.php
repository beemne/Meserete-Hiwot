<?php

namespace App\Mz\Support;

/** HS256 JSON Web Tokens, compatible with the jsonwebtoken package used by the Node.js backend. */
final class Jwt
{
    public static function ttlToSeconds(string $ttl): int
    {
        if (! preg_match('/^(\d+)([smhd])$/', $ttl, $m)) {
            return 900;
        }
        return (int) $m[1] * ['s' => 1, 'm' => 60, 'h' => 3600, 'd' => 86400][$m[2]];
    }

    public static function sign(array $claims, string $secret): string
    {
        $h = Crypto::b64url(json_encode(['alg' => 'HS256', 'typ' => 'JWT']));
        $p = Crypto::b64url(json_encode($claims, JSON_UNESCAPED_SLASHES));
        $s = Crypto::b64url(hash_hmac('sha256', "$h.$p", $secret, true));
        return "$h.$p.$s";
    }

    /**
     * Verify signature, issuer, audience and expiry.
     * @throws ApiError TOKEN_EXPIRED | INVALID_TOKEN
     */
    public static function verify(string $token, string $secret, string $issuer, string $audience): array
    {
        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        [$h, $p, $s] = $parts;
        $header = json_decode(Crypto::b64urlDecode($h), true);
        if (($header['alg'] ?? null) !== 'HS256') {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        $expected = Crypto::b64url(hash_hmac('sha256', "$h.$p", $secret, true));
        if (! hash_equals($expected, $s)) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        $claims = json_decode(Crypto::b64urlDecode($p), true);
        if (! is_array($claims)) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        $aud = $claims['aud'] ?? null;
        if (($claims['iss'] ?? null) !== $issuer || ! (is_array($aud) ? in_array($audience, $aud, true) : $aud === $audience)) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        $now = time();
        if (isset($claims['nbf']) && $claims['nbf'] > $now) {
            throw ApiError::unauthorized('INVALID_TOKEN', 'Invalid token');
        }
        if (isset($claims['exp']) && $claims['exp'] <= $now) {
            throw ApiError::unauthorized('TOKEN_EXPIRED', 'Access token expired');
        }
        return $claims;
    }
}
