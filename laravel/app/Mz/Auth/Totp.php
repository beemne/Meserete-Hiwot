<?php

namespace App\Mz\Auth;

/** RFC 6238 TOTP (6 digits, 30 s, SHA-1) as otplib's authenticator; ±1 step of clock drift. */
final class Totp
{
    public static function base32Decode(string $s): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $s = strtoupper(preg_replace('/[^A-Za-z2-7]/', '', $s));
        $bits = '';
        foreach (str_split($s) as $c) {
            $bits .= str_pad(decbin(strpos($alphabet, $c)), 5, '0', STR_PAD_LEFT);
        }
        $out = '';
        foreach (str_split($bits, 8) as $byte) {
            if (strlen($byte) === 8) {
                $out .= chr(bindec($byte));
            }
        }
        return $out;
    }

    /** A random base32 secret (as otplib's authenticator.generateSecret()). */
    public static function generateSecret(int $bytes = 20): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $bits = '';
        foreach (str_split(random_bytes($bytes)) as $c) $bits .= str_pad(decbin(ord($c)), 8, '0', STR_PAD_LEFT);
        $out = '';
        foreach (str_split($bits, 5) as $chunk) $out .= $alphabet[bindec(str_pad($chunk, 5, '0'))];
        return $out;
    }

    /** otpauth:// URI for authenticator apps (as otplib's authenticator.keyuri()). */
    public static function keyUri(string $account, string $issuer, string $secret): string
    {
        return 'otpauth://totp/' . rawurlencode($issuer) . ':' . rawurlencode($account)
            . '?secret=' . $secret . '&period=30&digits=6&algorithm=SHA1&issuer=' . rawurlencode($issuer);
    }

    public static function generate(string $secret, ?int $time = null): string
    {
        $counter = intdiv($time ?? time(), 30);
        $key = self::base32Decode($secret);
        $bin = pack('N*', 0) . pack('N*', $counter);
        $h = hash_hmac('sha1', $bin, $key, true);
        $o = ord($h[19]) & 0xf;
        $code = ((ord($h[$o]) & 0x7f) << 24 | (ord($h[$o + 1]) & 0xff) << 16 | (ord($h[$o + 2]) & 0xff) << 8 | (ord($h[$o + 3]) & 0xff)) % 1000000;
        return str_pad((string) $code, 6, '0', STR_PAD_LEFT);
    }

    public static function check(string $token, string $secret): bool
    {
        $now = time();
        foreach ([0, -30, 30] as $drift) {
            if (hash_equals(self::generate($secret, $now + $drift), $token)) {
                return true;
            }
        }
        return false;
    }
}
