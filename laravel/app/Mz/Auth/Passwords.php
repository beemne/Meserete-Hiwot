<?php

namespace App\Mz\Auth;

/**
 * Argon2id with OWASP parameters (19 MiB, t=2, p=1) — the same encoding as the Node argon2 package,
 * so existing hashes verify unchanged.
 */
final class Passwords
{
    private const OPTIONS = ['memory_cost' => 19456, 'time_cost' => 2, 'threads' => 1];
    private static ?string $dummy = null;

    public static function hash(string $plain): string
    {
        return password_hash($plain, PASSWORD_ARGON2ID, self::OPTIONS);
    }

    public static function verify(?string $hash, string $plain): bool
    {
        if (! $hash) {
            return false;
        }
        try {
            return password_verify($plain, $hash);
        } catch (\Throwable) {
            return false;
        }
    }

    /** Equalise response time when the account does not exist (prevents enumeration by timing). */
    public static function burnVerify(?string $plain): bool
    {
        self::$dummy ??= self::hash('dummy-password-for-timing-1');
        self::verify(self::$dummy, $plain ?: 'x');
        return false;
    }

    public static function needsRehash(string $hash): bool
    {
        return password_needs_rehash($hash, PASSWORD_ARGON2ID, self::OPTIONS);
    }
}
