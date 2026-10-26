<?php

use App\Mz\Http\Ctx;
use App\Mz\Notifications\Notifications;
use App\Mz\Services\Categories;
use App\Mz\Services\Mezmurs;
use App\Mz\Services\Programs;
use App\Mz\Services\Promotions;
use App\Mz\Services\Sync;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\Route;

// App-level aggregate endpoints: home screen payload and offline sync (port of app.routes.js).

/** Everything the home screen needs in one round trip. */
Route::get('home', function () {
    $auth = Ctx::authOrNull();
    $page = fn (int $limit) => ['page' => 1, 'limit' => $limit, 'offset' => 0];
    $categories = array_map(function ($c) {
        $n = count($c['children'] ?? []);
        unset($c['children']);
        return $c + ['child_count' => $n];
    }, Categories::tree());
    return Http::ok([
        'banners' => Promotions::activeAds(),
        // "ዛሬ የሚጠኑ" — shown at the top of the home screen.
        'today' => ['categories' => Categories::todayList(), 'mezmurs' => Mezmurs::todayList($auth)],
        'featured' => Mezmurs::list($auth, ['featured' => true], $page(8))['items'],
        'recent' => Mezmurs::list($auth, ['sort' => 'recent'], $page(10))['items'],
        'popular' => Mezmurs::list($auth, ['sort' => 'popular'], $page(10))['items'],
        'categories' => $categories,
        'upcoming_programs' => Programs::list($auth, ['scope' => 'upcoming'], $page(5))['items'],
        'unread_notifications' => $auth ? Notifications::unreadCount($auth->id) : 0,
    ]);
})->middleware('mz:optional');

// Offline queue replay. Members sync personal data; staff also sync attendance and borrowing work
// (each op checks the same permission as its online route).
Route::post('sync', function () {
    $body = Ctx::body(Sync::requestSchema());
    $auth = Ctx::auth();
    if (! in_array($auth->accountType, ['user', 'admin'], true)) throw ApiError::forbidden();
    // client_now: the phone's clock when it sent the batch — offline times are corrected by the skew.
    return Http::ok(Sync::apply($auth, $body['operations'], Ctx::actx(), $body['client_now'] ?? null));
})->middleware('mz');

// Offline pack: what a staff phone keeps in its SQLite store to scan QR codes, take attendance and
// lend items without a connection (members never receive other members' data: empty lists).
Route::get('offline/pack', fn () => Http::ok(\App\Mz\Services\OfflinePack::build(Ctx::auth())))->middleware('mz');
