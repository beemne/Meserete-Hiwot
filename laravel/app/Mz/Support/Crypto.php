<?php

namespace App\Mz\Support;

/** Byte-compatible with the Node.js backend (utils/crypto.js), so existing secrets keep working. */
final class Crypto
{
    public static function b64url(string $bin): string
    {
        return rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
    }

    public static function b64urlDecode(string $s): string
    {
        $s = strtr($s, '-_', '+/');
        return base64_decode($s . str_repeat('=', (4 - strlen($s) % 4) % 4)) ?: '';
    }

    public static function randomToken(int $bytes = 48): string
    {
        return self::b64url(random_bytes($bytes));
    }

    public static function sha256(string $value): string
    {
        return hash('sha256', $value);
    }

    /** Keyed hash for secrets stored at rest (refresh tokens, reset codes). */
    public static function hmac(string $value, ?string $key = null): string
    {
        return hash_hmac('sha256', $value, $key ?? (string) config('mz.jwt.refresh_secret'));
    }

    public static function uuid(): string
    {
        $b = random_bytes(16);
        $b[6] = chr((ord($b[6]) & 0x0f) | 0x40);
        $b[8] = chr((ord($b[8]) & 0x3f) | 0x80);
        $h = bin2hex($b);
        return sprintf('%s-%s-%s-%s-%s', substr($h, 0, 8), substr($h, 8, 4), substr($h, 12, 4), substr($h, 16, 4), substr($h, 20));
    }

    public static function randomNumericCode(int $length = 6): string
    {
        $out = '';
        for ($i = 0; $i < $length; $i++) {
            $out .= random_int(0, 9);
        }
        return $out;
    }

    private static function key(): string
    {
        return hex2bin((string) config('mz.system.encryption_key')) ?: '';
    }

    /** AES-256-GCM: "iv.tag.ciphertext" (base64url), as Node's encryptSecret(). */
    public static function encryptSecret(string $plain): string
    {
        $iv = random_bytes(12);
        $tag = '';
        $enc = openssl_encrypt($plain, 'aes-256-gcm', self::key(), OPENSSL_RAW_DATA, $iv, $tag, '', 16);
        return implode('.', [self::b64url($iv), self::b64url($tag), self::b64url($enc)]);
    }

    public static function decryptSecret(string $payload): string
    {
        [$iv, $tag, $enc] = array_map([self::class, 'b64urlDecode'], explode('.', $payload) + ['', '', '']);
        $out = openssl_decrypt($enc, 'aes-256-gcm', self::key(), OPENSSL_RAW_DATA, $iv, $tag);
        if ($out === false) {
            throw new \RuntimeException('decrypt failed');
        }
        return $out;
    }

    public static function timingSafeEqual(string $a, string $b): bool
    {
        return hash_equals($a, $b);
    }
}
