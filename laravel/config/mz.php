<?php

// Application configuration. The variable names are the same as the Node.js backend's .env, so one
// .env file works for both during the switch-over.

$bool = static function ($v, bool $def): bool {
    if ($v === null || $v === '') {
        return $def;
    }
    return in_array(strtolower((string) $v), ['1', 'true', 'yes'], true);
};
$csv = static fn ($v) => array_values(array_filter(array_map('trim', explode(',', (string) $v)), fn ($x) => $x !== ''));
$ttl = static fn ($v, $def) => $v ?: $def;
$base = rtrim((string) env('PUBLIC_BASE_URL', 'http://localhost:8000'), '/');
$storage = env('STORAGE_PATH', storage_path('mz'));
if (! preg_match('#^([A-Za-z]:[\\\\/]|/)#', $storage)) {
    $storage = base_path($storage);
}
$env = env('NODE_ENV', env('APP_ENV', 'production'));
$isTest = in_array($env, ['test', 'testing'], true);

return [
    'env' => $env,
    'is_prod' => $env === 'production',
    'is_test' => $isTest,
    'public_base_url' => $base,
    'cors_origins' => $csv(env('CORS_ORIGINS', '')),
    'timezone' => env('APP_TIMEZONE', 'Africa/Addis_Ababa'),

    'jwt' => [
        'secret' => env('JWT_SECRET', ''),
        'refresh_secret' => env('JWT_REFRESH_SECRET', ''),
        'access_ttl' => $ttl(env('JWT_ACCESS_TTL'), '15m'),
        // 0 = app sessions never time out (members stay signed in until they or an admin sign them out).
        'refresh_ttl_days' => (int) env('JWT_REFRESH_TTL_DAYS', 0),
        'issuer' => env('JWT_ISSUER', 'mezmur-zelideta-api'),
        'audience' => env('JWT_AUDIENCE', 'mezmur-zelideta-app'),
    ],
    'system' => [
        // 32 bytes hex (AES-256-GCM key for TOTP seeds)
        'encryption_key' => env('SYSTEM_ENCRYPTION_KEY', ''),
        'access_ttl' => $ttl(env('SYSTEM_ACCESS_TTL'), '10m'),
        // 0 = the system console stays signed in too.
        'refresh_ttl_hours' => (int) env('SYSTEM_REFRESH_TTL_HOURS', 0),
        'allowed_ips' => $csv(env('SYSTEM_ALLOWED_IPS', '')),
    ],
    'firebase' => [
        'project_id' => env('FIREBASE_PROJECT_ID', ''),
        'client_email' => env('FIREBASE_CLIENT_EMAIL', ''),
        'private_key' => str_replace('\\n', "\n", (string) env('FIREBASE_PRIVATE_KEY', '')),
    ],
    'storage' => [
        'root' => $storage,
        'max_image_bytes' => (int) round((float) env('MAX_IMAGE_MB', 5) * 1024 * 1024),
        'max_audio_bytes' => (int) round((float) env('MAX_AUDIO_MB', 40) * 1024 * 1024),
        'max_apk_bytes' => (int) round((float) env('MAX_APK_MB', 250) * 1024 * 1024),
        'max_document_bytes' => (int) round((float) env('MAX_DOCUMENT_MB', 20) * 1024 * 1024),
        'max_book_bytes' => (int) round((float) env('MAX_BOOK_MB', 60) * 1024 * 1024),
    ],

    // At-rest encryption of sensitive columns (MZ-Seal, AES-256-GCM; see App\Mz\Crypto\Seal).
    // DATA_ENCRYPTION_KEY: base64 of 32 bytes (`php artisan mz:encrypt-data --generate-key`); when
    // empty the key is derived from APP_KEY. Keep it backed up: without it the data is unreadable.
    'data_encryption' => filter_var(env('DATA_ENCRYPTION', true), FILTER_VALIDATE_BOOL),
    'data_key' => env('DATA_ENCRYPTION_KEY', ''),
    'data_old_keys' => env('DATA_ENCRYPTION_OLD_KEYS', ''),

    'smtp' => [
        'host' => env('SMTP_HOST', ''),
        'port' => (int) env('SMTP_PORT', 587),
        'user' => env('SMTP_USER', ''),
        'password' => env('SMTP_PASSWORD', ''),
        'from' => env('SMTP_FROM', ''),
    ],
    'telegram' => [
        'token' => env('TELEGRAM_BOT_TOKEN', ''),
        'username' => ltrim((string) env('TELEGRAM_BOT_USERNAME', ''), '@'),
        'webhook_secret' => env('TELEGRAM_WEBHOOK_SECRET', ''),
        'api_base' => rtrim((string) env('TELEGRAM_API_BASE', 'https://api.telegram.org'), '/'),
    ],
    'android' => [
        'package' => env('ANDROID_PACKAGE', 'com.mezmur.zelideta'),
        'cert_sha256' => array_map('strtoupper', $csv(env('ANDROID_CERT_SHA256') ?: 'A9:83:41:56:73:25:FF:68:D7:1D:09:FD:70:BF:FE:C6:DD:CE:BE:8E:F1:DB:A5:40:99:34:40:49:16:84:BA:93')),
    ],
    'jobs_enabled' => $bool(env('JOBS_ENABLED'), true) && ! $isTest,
];
