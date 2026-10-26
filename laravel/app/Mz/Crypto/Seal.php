<?php

namespace App\Mz\Crypto;

use RuntimeException;

/**
 * MZ-Seal v1 — the app's at-rest encryption envelope for database values.
 *
 * It is deliberately NOT a home-made cipher: the cryptography is AES-256-GCM (authenticated
 * encryption, OpenSSL). What is specific to this app is the envelope and key handling:
 *
 *   stored value = "mz1:" . base64url( kid[4] | nonce[12] | tag[16] | ciphertext )
 *
 *  - kid: first 4 bytes of SHA-256 over the key → the right key is found after a key rotation;
 *  - nonce: 12 random bytes per value (the same text never encrypts to the same value);
 *  - tag: GCM authentication tag; a modified value fails to decrypt instead of returning garbage;
 *  - AAD "mz-seal-v1" binds values to this scheme/version.
 *
 * Keys: DATA_ENCRYPTION_KEY (base64 of 32 random bytes; `php artisan mz:encrypt-data --generate-key`).
 * Without it the key is derived from APP_KEY with HKDF-SHA256 (info "mz-seal-v1") — then APP_KEY
 * must never change, or the data cannot be read. Earlier keys stay readable via
 * DATA_ENCRYPTION_OLD_KEYS (comma separated); `mz:encrypt-data --rotate` re-encrypts with the
 * current key. Losing every key means losing the encrypted data: back the key up.
 */
final class Seal
{
    public const PREFIX = 'mz1:';
    private const CIPHER = 'aes-256-gcm';
    private const AAD = 'mz-seal-v1';
    private const KID = 4;
    private const NONCE = 12;
    private const TAG = 16;

    /** @var array{0:string,1:string}|null [kid, key] */
    private static ?array $current = null;
    /** @var array<string,string>|null kid => key */
    private static ?array $keys = null;

    public static function enabled(): bool
    {
        return (bool) config('mz.data_encryption', true);
    }

    public static function isSealed(mixed $v): bool
    {
        return is_string($v) && str_starts_with($v, self::PREFIX);
    }

    public static function seal(string $plain): string
    {
        [$kid, $key] = self::current();
        $nonce = random_bytes(self::NONCE);
        $tag = '';
        $ct = openssl_encrypt($plain, self::CIPHER, $key, OPENSSL_RAW_DATA, $nonce, $tag, self::AAD, self::TAG);
        if ($ct === false) throw new RuntimeException('Data encryption failed');
        return self::PREFIX . self::b64($kid . $nonce . $tag . $ct);
    }

    public static function open(string $sealed): string
    {
        if (! self::isSealed($sealed)) return $sealed;
        $raw = self::unb64(substr($sealed, strlen(self::PREFIX)));
        // Not an envelope at all — plain text that merely starts with the marker.
        if ($raw === null || strlen($raw) < self::KID + self::NONCE + self::TAG) return $sealed;
        $kid = substr($raw, 0, self::KID);
        $key = self::keys()[$kid] ?? null;
        if ($key === null) {
            \Illuminate\Support\Facades\Log::warning('No key for an encrypted value (kid ' . bin2hex($kid) . '): set DATA_ENCRYPTION_KEY / DATA_ENCRYPTION_OLD_KEYS');
            return $sealed;
        }
        $plain = openssl_decrypt(
            substr($raw, self::KID + self::NONCE + self::TAG), self::CIPHER, $key, OPENSSL_RAW_DATA,
            substr($raw, self::KID, self::NONCE), substr($raw, self::KID + self::NONCE, self::TAG), self::AAD,
        );
        if ($plain === false) {
            \Illuminate\Support\Facades\Log::warning('Encrypted value failed authentication (wrong key or modified data)');
            return $sealed;
        }
        return $plain;
    }

    /** A real envelope this installation can open (user text that only looks like one is not). */
    public static function canOpen(mixed $v): bool
    {
        if (! self::isSealed($v)) return false;
        $raw = self::unb64(substr($v, strlen(self::PREFIX)));
        if ($raw === null || strlen($raw) < self::KID + self::NONCE + self::TAG) return false;
        try {
            self::open($v);
            return true;
        } catch (RuntimeException) {
            return false;
        }
    }

    /** Sealed with a key other than the current one (to re-encrypt after a rotation). */
    public static function isStale(string $sealed): bool
    {
        $raw = self::unb64(substr($sealed, strlen(self::PREFIX)));
        return $raw !== null && substr($raw, 0, self::KID) !== self::current()[0];
    }

    public static function generateKey(): string
    {
        return base64_encode(random_bytes(32));
    }

    /** For tests / after changing the configuration at run time. */
    public static function reset(): void
    {
        self::$current = null;
        self::$keys = null;
    }

    private static function current(): array
    {
        if (self::$current === null) {
            $key = self::parseKey((string) config('mz.data_key', '')) ?? self::derived();
            self::$current = [self::kid($key), $key];
        }
        return self::$current;
    }

    private static function keys(): array
    {
        if (self::$keys === null) {
            [$kid, $key] = self::current();
            $all = [$kid => $key];
            foreach (array_filter(array_map('trim', explode(',', (string) config('mz.data_old_keys', '')))) as $old) {
                $k = self::parseKey($old);
                if ($k !== null) $all[self::kid($k)] ??= $k;
            }
            // Values written before a dedicated key was set were sealed with the APP_KEY-derived key.
            $d = self::derived();
            $all[self::kid($d)] ??= $d;
            self::$keys = $all;
        }
        return self::$keys;
    }

    private static function derived(): string
    {
        $app = (string) config('app.key', '');
        if ($app === '') throw new RuntimeException('APP_KEY (or DATA_ENCRYPTION_KEY) is required for data encryption');
        $ikm = str_starts_with($app, 'base64:') ? base64_decode(substr($app, 7), true) : $app;
        return hash_hkdf('sha256', (string) $ikm, 32, self::AAD);
    }

    private static function parseKey(string $v): ?string
    {
        $v = trim($v);
        if ($v === '') return null;
        if (str_starts_with($v, 'base64:')) $v = substr($v, 7);
        $k = base64_decode($v, true);
        if ($k === false || strlen($k) !== 32) throw new RuntimeException('DATA_ENCRYPTION_KEY must be base64 of 32 bytes');
        return $k;
    }

    private static function kid(string $key): string
    {
        return substr(hash('sha256', $key, true), 0, self::KID);
    }

    private static function b64(string $raw): string
    {
        return rtrim(strtr(base64_encode($raw), '+/', '-_'), '=');
    }

    private static function unb64(string $s): ?string
    {
        $r = base64_decode(strtr($s, '-_', '+/'), true);
        return $r === false ? null : $r;
    }
}
