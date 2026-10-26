<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\T;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** App releases: APK hosting, the public download page and the start-up version check (port of releaseService.js). */
final class Releases
{
    public static function downloadPageUrl(): string
    {
        return config('mz.public_base_url') . '/download';
    }

    private static function fileUrl(object $r): string
    {
        return config('mz.public_base_url') . "/download/android/{$r->version_code}.apk";
    }

    public static function serialize(object $r): array
    {
        return [
            'id' => $r->id, 'platform' => $r->platform, 'version_name' => $r->version_name, 'version_code' => $r->version_code,
            'file_size' => Num::n($r->file_size), 'sha256' => $r->sha256, 'release_notes' => $r->release_notes, 'min_supported_code' => $r->min_supported_code,
            'is_mandatory' => (bool) $r->is_mandatory, 'is_published' => (bool) $r->is_published, 'download_count' => $r->download_count,
            'download_url' => self::fileUrl($r), 'created_at' => $r->created_at,
        ];
    }

    private static function published(string $platform = 'android')
    {
        return DB::table('app_releases')->where(['platform' => $platform, 'is_published' => true]);
    }

    public static function list(bool $includeUnpublished = false): array
    {
        $q = DB::table('app_releases')->orderByDesc('version_code');
        if (! $includeUnpublished) $q->where('is_published', true);
        return $q->get()->map(fn ($r) => self::serialize($r))->all();
    }

    public static function publish(array $actx, UploadedFile $file, array $input): array
    {
        if (DB::table('app_releases')->where(['platform' => 'android', 'version_code' => $input['version_code']])->exists()) {
            throw ApiError::conflict('VERSION_EXISTS', 'This version code already exists', [['field' => 'version_code', 'code' => 'VERSION_EXISTS', 'message' => 'VERSION_EXISTS']]);
        }
        $saved = Storage::save('apk', Storage::FOLDERS['RELEASES'], $file);
        try {
            $id = DB::table('app_releases')->insertGetId([
                'platform' => 'android', 'version_name' => $input['version_name'], 'version_code' => $input['version_code'], 'file_path' => $saved['path'],
                'file_size' => $saved['size'], 'sha256' => $saved['sha256'], 'release_notes' => $input['release_notes'] ?? null,
                'min_supported_code' => $input['min_supported_code'] ?? 0, 'is_mandatory' => $input['is_mandatory'] ?? false,
                'is_published' => $input['is_published'] ?? true, 'created_by' => $actx['auth']?->id,
            ]);
            Audit::log($actx, Audit::RELEASE_PUBLISH, 'release', $id, ['version' => $input['version_name'], 'code' => $input['version_code'], 'mandatory' => (bool) ($input['is_mandatory'] ?? false)]);
            return self::serialize(DB::table('app_releases')->where('id', $id)->first());
        } catch (\Throwable $e) {
            Storage::remove($saved['path']);
            throw $e;
        }
    }

    public static function update(array $actx, int $id, array $input): array
    {
        if (! DB::table('app_releases')->where('id', $id)->exists()) throw ApiError::notFound('RELEASE_NOT_FOUND', 'Release not found');
        $patch = array_intersect_key($input, array_flip(['release_notes', 'min_supported_code', 'is_mandatory', 'is_published', 'version_name']));
        if ($patch) DB::table('app_releases')->where('id', $id)->update($patch);
        Audit::log($actx, Audit::RELEASE_UPDATE, 'release', $id, (object) $patch);
        return self::serialize(DB::table('app_releases')->where('id', $id)->first());
    }

    public static function remove(array $actx, int $id): void
    {
        $r = DB::table('app_releases')->where('id', $id)->first();
        if (! $r) throw ApiError::notFound('RELEASE_NOT_FOUND', 'Release not found');
        DB::table('app_releases')->where('id', $id)->delete();
        Audit::log($actx, Audit::RELEASE_DELETE, 'release', $id, ['version' => $r->version_name]);
        Storage::remove($r->file_path);
    }

    /** Forced when older than the newest min_supported_code, or a newer published release is mandatory. */
    public static function check(string $platform, int $currentCode): array
    {
        $latest = self::published($platform)->orderByDesc('version_code')->first();
        if (! $latest) return ['update_available' => false, 'force_update' => false, 'download_page_url' => self::downloadPageUrl()];
        $minCode = (int) (self::published($platform)->max('min_supported_code') ?? 0);
        $mandatoryNewer = self::published($platform)->where('version_code', '>', $currentCode)->where('is_mandatory', true)->exists();
        return [
            'latest_version_name' => $latest->version_name,
            'latest_version_code' => $latest->version_code,
            'release_notes' => $latest->release_notes,
            'update_available' => $latest->version_code > $currentCode,
            'force_update' => $latest->version_code > $currentCode && ($currentCode < $minCode || $mandatoryNewer),
            'download_page_url' => self::downloadPageUrl(),
            'download_url' => self::fileUrl($latest),
        ];
    }

    /** A published APK for download (increments the counter). */
    public static function fileFor(string $versionCode): array
    {
        $q = self::published('android');
        $r = $versionCode === 'latest' ? $q->orderByDesc('version_code')->first() : $q->where('version_code', (int) $versionCode)->first();
        if (! $r) throw ApiError::notFound('RELEASE_NOT_FOUND', 'Release not found');
        $abs = Storage::privatePath($r->file_path);
        if (! is_file($abs)) throw ApiError::notFound('RELEASE_NOT_FOUND', 'Release not found');
        DB::table('app_releases')->where('id', $r->id)->increment('download_count');
        return ['abs' => $abs, 'filename' => "mezmur-zelideta-{$r->version_name}.apk"];
    }

    // ------------------------------------------------------------------ download page (no scripts)
    private static function esc($s): string
    {
        return str_replace(['&', '<', '>', '"'], ['&amp;', '&lt;', '&gt;', '&quot;'], (string) ($s ?? ''));
    }

    private static function mb($n): string
    {
        return number_format(Num::n($n) / (1024 * 1024), 1, '.', '') . ' MB';
    }

    private static function day($d): string
    {
        return substr(json_decode(json_encode(Dates::of($d))), 0, 10);
    }

    public static function renderDownloadPage(): string
    {
        $releases = self::list();
        $latest = $releases[0] ?? null;
        $older = array_slice($releases, 1);
        $e = fn ($s) => self::esc($s);
        $notes = fn ($r) => $r['release_notes'] ? '<p class="notes">' . str_replace("\n", '<br>', $e($r['release_notes'])) . '</p>' : '';
        if ($latest) {
            $latestHtml = '<section class="card">
    <span class="pill">' . $e(T::t('release.page.latest')) . '</span>' . ($latest['is_mandatory'] ? ' <span class="pill m">' . $e(T::t('release.page.mandatory')) . '</span>' : '') . '
    <h2>v' . $e($latest['version_name']) . '</h2>
    <div class="meta">' . $e(T::t('release.page.published')) . ': ' . self::day($latest['created_at']) . ' · ' . $e(T::t('release.page.size')) . ': ' . self::mb($latest['file_size']) . '</div>
    ' . $notes($latest) . '
    <a class="btn" href="' . $e($latest['download_url']) . '">⬇ ' . $e(T::t('release.page.download')) . '</a>
    <p class="hint">' . $e(T::t('release.page.install')) . '</p>
  </section>';
        } else {
            $latestHtml = '<section class="card"><p>' . $e(T::t('release.page.none')) . '</p></section>';
        }
        $olderHtml = $older ? '<section class="card"><h2>' . $e(T::t('release.page.older')) . '</h2><ul>' . implode('', array_map(
            fn ($r) => '<li><div><strong>v' . $e($r['version_name']) . '</strong><div class="meta">' . self::day($r['created_at']) . ' · ' . self::mb($r['file_size']) . '</div></div><a href="' . $e($r['download_url']) . '">⬇ APK</a></li>',
            $older,
        )) . '</ul></section>' : '';
        $title = $e(T::t('release.page.title'));
        return <<<HTML
<!doctype html>
<html lang="am">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$title</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Noto+Serif+Ethiopic:wght@600;700&family=Noto+Sans+Ethiopic:wght@400;600&display=swap" rel="stylesheet">
<style>
  :root { --maroon:#6e1423; --gold:#c8961e; --gold-d:#b08a1e; --cream:#f7e9d8; --text:#3d2e31; --muted:#8a7a7d; --border:#eee0e3; }
  * { box-sizing: border-box; }
  body { margin:0; font-family:'Noto Sans Ethiopic',system-ui,sans-serif; color:var(--text); background:#fff;
    background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='56' height='56'%3E%3Cg fill='none' stroke='%236e1423' stroke-opacity='0.08' stroke-width='1.2'%3E%3Cpath d='M28 12v32M12 28h32'/%3E%3Cpath d='M28 12l-4.5 6h9zM28 44l-4.5-6h9zM12 28l6-4.5v9zM44 28l-6-4.5v9z'/%3E%3Ccircle cx='28' cy='28' r='4.5'/%3E%3C/g%3E%3C/svg%3E"); }
  main { max-width:560px; margin:0 auto; padding:32px 18px 48px; }
  header { text-align:center; }
  header img { width:112px; height:112px; border-radius:50%; box-shadow:0 0 0 3px var(--gold); }
  h1 { font-family:'Noto Serif Ethiopic',serif; color:var(--maroon); font-size:28px; margin:16px 0 4px; }
  .sub { color:var(--muted); font-size:14px; margin:0; }
  .card { background:#fff; border:1px solid var(--border); border-radius:18px; padding:18px; margin-top:22px; box-shadow:0 2px 12px rgba(110,20,35,.06); }
  .card h2 { font-family:'Noto Serif Ethiopic',serif; color:var(--maroon); font-size:18px; margin:0 0 6px; }
  .meta { color:var(--muted); font-size:13px; }
  .pill { display:inline-block; background:var(--cream); color:var(--gold-d); border-radius:100px; padding:3px 12px; font-size:12px; font-weight:600; }
  .pill.m { background:var(--maroon); color:#fff; }
  .btn { display:block; text-align:center; background:var(--gold); color:#fff; text-decoration:none; font-weight:600; font-size:16px; border-radius:100px; padding:14px; margin-top:14px; box-shadow:0 4px 14px rgba(200,150,30,.35); }
  .notes { font-size:14px; line-height:1.7; margin:10px 0 0; }
  .hint { color:var(--muted); font-size:12px; margin-top:10px; }
  ul { list-style:none; padding:0; margin:0; }
  li { display:flex; justify-content:space-between; align-items:center; gap:10px; padding:12px 0; border-top:1px solid var(--border); }
  li:first-child { border-top:0; }
  li a { color:var(--maroon); font-weight:600; text-decoration:none; white-space:nowrap; }
</style>
</head>
<body>
<main>
  <header>
    <img src="/download/assets/logo.jpg" alt="">
    <h1>መሠረተ ሕይወት</h1>
    <p class="sub">መሠረተ ሕይወት ሰንበት ት/ቤት</p>
  </header>
  $latestHtml
  $olderHtml
</main>
</body>
</html>
HTML;
    }
}
