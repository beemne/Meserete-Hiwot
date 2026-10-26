<?php

namespace App\Mz\Notifications;

use App\Mz\Support\T;

/**
 * Links that open the exact content in the app when it is installed (Android App Links on this
 * host, or the mezmurzelideta:// scheme from the landing page), otherwise the download page.
 *  - public content: /m/12 (Mezmur), /p/12 (program), /c/12 (category), /pg/12 (page) — with a preview;
 *  - anything else (task, borrowing, class…): /open/{type}/{id} — no data on the page, the app
 *    checks the member's access as usual.
 */
final class DeepLinks
{
    private const SHARE = ['mezmur' => 'm', 'program' => 'p', 'category' => 'c', 'page' => 'pg'];
    public const OPEN_TYPES = ['project', 'project_task', 'project_suggestion', 'borrowing', 'library_request', 'edu_class', 'edu_lesson', 'edu_quiz', 'edu_assignment', 'chat', 'attendance', 'payment', 'choir', 'notification'];

    public static function forEntity(?string $type, mixed $id): ?string
    {
        $base = config('mz.public_base_url');
        if (! $type || ! $id) return "$base/open/notification/0";
        if (isset(self::SHARE[$type])) return "$base/" . self::SHARE[$type] . '/' . (int) $id;
        if (in_array($type, self::OPEN_TYPES, true)) return "$base/open/$type/" . (int) $id;
        return "$base/open/notification/0";
    }

    /** The landing page: opens the app at $appPath, or offers the download. */
    public static function landing(string $appPath, string $title, string $description = '', ?string $image = null): string
    {
        $esc = fn ($s) => htmlspecialchars((string) ($s ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $base = config('mz.public_base_url');
        $image ??= "$base/download/assets/logo.jpg";
        $download = "$base/download";
        // Chrome on Android: open the app at this page, or fall back to the download page.
        $intent = "intent://open$appPath#Intent;scheme=mezmurzelideta;package=" . config('mz.android.package') . ';S.browser_fallback_url=' . rawurlencode($download) . ';end';
        $desc = $description !== '' ? '<p>' . $esc($description) . '</p>' : '';
        return '<!doctype html>
<html lang="am">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>' . $esc($title) . ' · መሠረተ ሕይወት</title>
<meta property="og:title" content="' . $esc($title) . '">
<meta property="og:description" content="' . $esc($description) . '">
<meta property="og:image" content="' . $esc($image) . '">
<meta property="og:type" content="website">
<style>
  body { margin:0; font-family:system-ui,sans-serif; color:#3d2e31; background:#fff; }
  main { max-width:520px; margin:0 auto; padding:36px 18px; text-align:center; }
  img { width:160px; height:160px; object-fit:cover; border-radius:24px; box-shadow:0 0 0 3px #c8961e; }
  h1 { color:#6e1423; font-size:24px; margin:18px 0 8px; }
  p { color:#8a7a7d; font-size:14px; line-height:1.6; }
  a.btn { display:block; text-decoration:none; font-weight:600; font-size:16px; border-radius:100px; padding:14px; margin-top:14px; }
  .open { background:#6e1423; color:#fff; }
  .get { background:#c8961e; color:#fff; }
</style>
</head>
<body>
<main>
  <img src="' . $esc($image) . '" alt="">
  <h1>' . $esc($title) . '</h1>
  ' . $desc . '
  <a class="btn open" href="' . $esc($intent) . '">' . $esc(T::t('share.open')) . '</a>
  <a class="btn get" href="' . $esc($download) . '">⬇ ' . $esc(T::t('share.get')) . '</a>
</main>
</body>
</html>';
    }
}
