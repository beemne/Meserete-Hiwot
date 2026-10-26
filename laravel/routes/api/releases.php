<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Releases;
use App\Mz\Support\Http;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// App versions (port of releases.routes.js): public version check + admin publishing.
Route::get('app/version', function () {
    $q = Ctx::query(Z::object([
        'platform' => Z::enum(['android'])->default('android'),
        'version_code' => Z::coerceNumber()->int()->min(0)->default(0),
    ]));
    return Http::ok(Releases::check($q['platform'], $q['version_code']));
});

Route::prefix('releases')->middleware(['mz', 'mz:all,releases.manage'])->group(function () {
    $bool = fn () => Z::union([Z::boolean(), Z::enum(['true', 'false'])->transform(fn ($v) => $v === 'true')]);
    $schema = fn () => Z::object([
        'version_name' => Z::string()->trim()->regex('/^\d+\.\d+\.\d+([-+][0-9A-Za-z.]+)?$/', 'INVALID_VERSION'),
        'version_code' => Z::coerceNumber()->int()->positive(),
        'release_notes' => V::optionalText(5000),
        'min_supported_code' => Z::coerceNumber()->int()->min(0)->optional(),
        'is_mandatory' => $bool()->optional(),
        'is_published' => $bool()->optional(),
    ]);
    Route::get('/', fn () => Http::ok(Releases::list(true)));
    Route::post('/', function () use ($schema) {
        $file = Upload::single('apk');
        return Http::created(Releases::publish(Ctx::actx(), $file, Ctx::body($schema())));
    });
    Route::patch('{id}', function () use ($schema) {
        $id = Ctx::id();
        return Http::ok(Releases::update(Ctx::actx(), $id, Ctx::body($schema()->omit(['version_code'])->partial()->strict())));
    });
    Route::delete('{id}', function () {
        Releases::remove(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });
});
