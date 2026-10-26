<?php

namespace App\Mz\Notifications;

use App\Mz\Support\Crypto;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging (HTTP v1). Server credentials live only in the environment, never in the
 * app. Port of fcmService.js (firebase-admin) without the SDK: a service-account JWT (RS256) is
 * exchanged for an OAuth token, then each message is POSTed (concurrently).
 */
final class Fcm
{
    private static ?string $initError = null;

    public static function configured(): bool
    {
        $f = config('mz.firebase');
        return (bool) ($f['project_id'] && $f['client_email'] && $f['private_key']);
    }

    public static function enabled(): bool
    {
        return self::configured() && self::accessToken() !== null;
    }

    /** Why push does or does not work — for the admin push test. */
    public static function status(): array
    {
        $ready = self::configured() && self::accessToken() !== null;
        return ['configured' => self::configured(), 'ready' => $ready, 'error' => self::$initError];
    }

    private static function accessToken(): ?string
    {
        if (! self::configured()) {
            return null;
        }
        $f = config('mz.firebase');
        $cacheKey = 'mz:fcm-token:' . sha1($f['client_email']);
        $cached = Cache::get($cacheKey);
        if ($cached) {
            return $cached;
        }
        try {
            $now = time();
            $header = Crypto::b64url(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
            $claims = Crypto::b64url(json_encode([
                'iss' => $f['client_email'],
                'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
                'aud' => 'https://oauth2.googleapis.com/token',
                'iat' => $now,
                'exp' => $now + 3600,
            ]));
            $key = openssl_pkey_get_private($f['private_key']);
            if (! $key) {
                throw new \RuntimeException('Invalid FIREBASE_PRIVATE_KEY (its "\\n" line breaks may be lost)');
            }
            openssl_sign("$header.$claims", $sig, $key, OPENSSL_ALGO_SHA256);
            $res = Http::asForm()->timeout(15)->post('https://oauth2.googleapis.com/token', [
                'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                'assertion' => "$header.$claims." . Crypto::b64url($sig),
            ]);
            $token = $res->json('access_token');
            if (! $token) {
                throw new \RuntimeException('FCM token exchange failed: ' . ($res->json('error_description') ?? $res->status()));
            }
            Cache::put($cacheKey, $token, now()->addMinutes(50));
            self::$initError = null;
            return $token;
        } catch (\Throwable $e) {
            self::$initError = $e->getMessage();
            Log::error('FCM initialisation failed', ['error' => $e->getMessage()]);
            return null;
        }
    }

    /**
     * Send messages. Each: {token, title, body, data: array<string,string>}.
     * @return array<array{token:string, ok:bool, dead:bool, error?:string}>
     */
    public static function sendBatch(array $messages): array
    {
        $access = self::accessToken();
        if (! $access || ! $messages) {
            return array_map(fn ($m) => ['token' => $m['token'], 'ok' => false, 'dead' => false], $messages);
        }
        $url = 'https://fcm.googleapis.com/v1/projects/' . config('mz.firebase.project_id') . '/messages:send';
        $results = [];
        foreach (array_chunk($messages, 50) as $chunk) {
            $responses = Http::pool(function ($pool) use ($chunk, $url, $access) {
                foreach ($chunk as $i => $m) {
                    $data = array_map('strval', $m['data'] ?? []);
                    $pool->as((string) $i)->withToken($access)->timeout(20)->post($url, ['message' => [
                        'token' => $m['token'],
                        'notification' => ['title' => $m['title'], 'body' => $m['body']],
                        'data' => (object) $data,
                        'android' => [
                            'priority' => 'high',
                            'notification' => array_filter([
                                'channel_id' => $data['channel'] ?? 'default',
                                'click_action' => 'FLUTTER_NOTIFICATION_CLICK',
                                // One tray entry per in-app notification: the app removes it (tag "n<id>") once read.
                                'tag' => ! empty($data['notification_id']) ? 'n' . $data['notification_id'] : null,
                            ]),
                        ],
                        'apns' => ['payload' => ['aps' => ['sound' => 'default']]],
                    ]]);
                }
            });
            foreach ($chunk as $i => $m) {
                $r = $responses[(string) $i] ?? null;
                if ($r instanceof \Illuminate\Http\Client\Response && $r->successful()) {
                    $results[] = ['token' => $m['token'], 'ok' => true, 'dead' => false];
                    continue;
                }
                $status = $r instanceof \Illuminate\Http\Client\Response ? ($r->json('error.status') ?? '') : 'NETWORK';
                $detail = '';
                if ($r instanceof \Illuminate\Http\Client\Response) {
                    foreach ((array) $r->json('error.details') as $d) {
                        $detail = $d['errorCode'] ?? $detail;
                    }
                }
                $dead = in_array($detail, ['UNREGISTERED', 'INVALID_ARGUMENT'], true) || in_array($status, ['NOT_FOUND', 'INVALID_ARGUMENT'], true);
                $results[] = ['token' => $m['token'], 'ok' => false, 'dead' => $dead, 'error' => $detail ?: $status];
            }
        }
        return $results;
    }
}
