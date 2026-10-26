<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Chat;
use App\Mz\Support\Http;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Department chat (port of chat.routes.js; rules in App\Mz\Services\Chat).
Route::prefix('chat')->middleware('mz')->group(function () {
    $thread = fn () => Z::string()->regex('/^(group|user:\d+)$/')->default('group');
    $dept = fn () => Ctx::params(Z::object(['id' => Z::coerceNumber()->int()->positive()]))['id'];

    Route::get('/', fn () => Http::ok(Chat::overview(Ctx::auth())));
    Route::get('messages/{id}/file', function () {
        $f = Chat::attachment(Ctx::auth(), Ctx::id());
        $headers = ['Cache-Control' => 'private, max-age=86400', 'Content-Type' => $f['mime']];
        if ($f['name']) $headers['Content-Disposition'] = "inline; filename*=UTF-8''" . rawurlencode($f['name']);
        return response()->file($f['abs'], $headers);
    });
    Route::get('{id}/messages', function () use ($thread, $dept) {
        $id = $dept();
        $q = Ctx::query(Z::object([
            'thread' => $thread(),
            'before' => Z::coerceNumber()->int()->positive()->optional(),
            'after' => Z::coerceNumber()->int()->nonnegative()->optional(),
            'limit' => Z::coerceNumber()->int()->min(1)->max(200)->optional(),
        ]));
        return Http::ok(Chat::messages(Ctx::auth(), $id, $q));
    });
    Route::post('{id}/messages', function () use ($thread, $dept) {
        $id = $dept();
        $file = Upload::optional('chat');
        $b = Ctx::body(Z::object([
            'thread' => $thread(),
            'body' => Z::string()->max(4000)->optional(),
            'kind' => Z::enum(['text', 'meeting'])->optional(),
            'meeting_url' => Z::string()->max(500)->optional(),
            'meeting_at' => Z::string()->max(40)->optional(),
        ]));
        return Http::ok(Chat::send(Ctx::auth(), $id, $b, $file), null, 'OK', 201);
    });
    Route::delete('{id}/messages/{messageId}', function () {
        $p = Ctx::params(Z::object(['id' => Z::coerceNumber()->int()->positive(), 'messageId' => Z::coerceNumber()->int()->positive()]));
        return Http::ok(Chat::remove(Ctx::auth(), $p['id'], $p['messageId']));
    });
    Route::post('{id}/read', function () use ($thread, $dept) {
        $id = $dept();
        $b = Ctx::body(Z::object(['thread' => $thread(), 'last_id' => Z::coerceNumber()->int()->nonnegative()]));
        return Http::ok(Chat::markRead(Ctx::auth(), $id, $b['thread'], $b['last_id']));
    });
    Route::get('{id}/threads', fn () => Http::ok(Chat::threads(Ctx::auth(), $dept())));
    Route::get('{id}/contacts', function () use ($dept) {
        $id = $dept();
        $q = Ctx::q()['q'] ?? null;
        return Http::ok(Chat::contacts(Ctx::auth(), $id, is_string($q) ? mb_substr($q, 0, 100) : null));
    });
});
