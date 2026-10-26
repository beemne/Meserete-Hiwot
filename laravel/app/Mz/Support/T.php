<?php

namespace App\Mz\Support;

/** Server-side message catalog (Amharic). Missing keys fall back to the key (visible in QA). */
final class T
{
    private static ?array $am = null;

    public static function t(string $key, array $params = []): string
    {
        self::$am ??= json_decode(file_get_contents(resource_path('am.json')), true) ?: [];
        $template = self::$am[$key] ?? $key;
        return preg_replace_callback('/\{(\w+)\}/', fn ($m) => (string) ($params[$m[1]] ?? ''), $template);
    }
}
