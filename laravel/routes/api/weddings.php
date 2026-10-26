<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\Weddings;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Wedding ceremony Mezmur services (port of weddings.routes.js; choir.manage).
Route::prefix('weddings')->middleware(['mz', 'mz:all,choir.manage'])->group(function () {
    $schema = fn () => Z::object([
        'title' => V::text(2, 200),
        'service_at' => Z::coerceDate(),
        'location' => V::optionalText(200),
        'notes' => V::optionalText(2000),
        'status' => Z::enum(['planned', 'completed', 'cancelled'])->optional(),
        // Former automatic requirements, still sent by old app versions: accepted, ignored.
        'requires_attendance' => Z::any()->optional(),
        'min_attendance' => Z::any()->optional(),
        'requires_exam' => Z::any()->optional(),
        'min_exam' => Z::any()->optional(),
        'lookback_months' => Z::any()->optional(),
        'category_ids' => Z::any()->optional(),
        // Create only: participants chosen in the same step.
        'user_ids' => Z::array(V::id())->max(100)->optional(),
        'note_for_members' => V::optionalText(500),
    ]);
    Route::get('/', function () {
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'scope' => Z::enum(['upcoming', 'all'])->optional(),
        ]));
        return Http::page(Weddings::list($q['scope'] ?? null, Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null])));
    });
    Route::post('/', fn () => Http::created(Weddings::create(Ctx::actx(), Ctx::body($schema()->strict()))));
    // Eligible members for a service being created (no service yet).
    Route::get('eligible', function () {
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(50)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'member_group' => Z::string()->trim()->max(40)->optional(),
        ]));
        return Http::page(Weddings::candidates(null, $q['q'] ?? null, Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]), ['member_group' => $q['member_group'] ?? null]));
    });
    Route::get('{id}', fn () => Http::ok(Weddings::get(Ctx::id())));
    Route::patch('{id}', function () use ($schema) {
        $id = Ctx::id();
        return Http::ok(Weddings::update(Ctx::actx(), $id, Ctx::body($schema()->partial()->strict())));
    });
    Route::get('{id}/candidates', function () {
        $id = Ctx::id();
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(50)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
            'member_group' => Z::string()->trim()->max(40)->optional(),
            'selected' => Z::enum(['true', 'false'])->optional(),
        ]));
        $filter = ['member_group' => $q['member_group'] ?? null, 'selected' => isset($q['selected']) ? $q['selected'] === 'true' : null];
        return Http::page(Weddings::candidates($id, $q['q'] ?? null, Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]), $filter));
    });
    Route::post('{id}/members', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['user_ids' => Z::array(V::id())->min(1)->max(100), 'note' => V::optionalText(500)])->strict());
        return Http::ok(Weddings::select(Ctx::actx(), $id, $b['user_ids'], $b['note'] ?? null));
    });
    Route::patch('{id}/members/{userId}', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        $b = Ctx::body(Z::object(['status' => Z::enum(['selected', 'participated', 'absent', 'withdrawn']), 'note' => V::optionalText(500)])->strict());
        return Http::ok(Weddings::setMember(Ctx::actx(), $id, $uid, $b['status'], $b['note'] ?? null));
    });
    Route::post('{id}/announce', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['title' => V::optionalText(200), 'body' => V::optionalText(1000)]));
        return Http::ok(Weddings::announce(Ctx::actx(), $id, $b));
    });
});
