<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\Broadcasts;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Admin messaging (port of adminNotifications.routes.js) + resend and delivery health.
$sendBody = fn () => Ctx::body(Z::object([
    'kind' => Z::enum(['announcement', 'reminder', 'program_info', 'admin_message']),
    'title' => V::text(1, 255),
    'body' => V::text(1, 2000),
    'target' => V::bulkTarget(),
    'entity_type' => Z::enum(['program', 'mezmur', 'page', 'category'])->optional(),
    'entity_id' => V::id()->optional(),
    // Also by email (to members with a registered address and email on for administrative messages).
    'email' => Z::boolean()->optional(),
])->refine(fn ($v) => isset($v['entity_type']) === isset($v['entity_id']), ['message' => 'ENTITY_REQUIRED', 'path' => ['entity_id']]));

Route::prefix('admin/notifications')->middleware(['mz', 'mz:all,notifications.send'])->group(function () use ($sendBody) {
    Route::post('send', function () use ($sendBody) {
        $b = $sendBody();
        $allowAll = Ctx::auth()->can('notifications.send_all');
        if (! empty($b['target']['all']) && ! $allowAll) throw ApiError::forbidden();
        return Http::created(Broadcasts::send(Ctx::actx(), $b, $allowAll), 'Sent');
    });
    Route::get('broadcasts', function () {
        $q = Ctx::q();
        return Http::page(Broadcasts::history(Ctx::auth(), ['kind' => $q['kind'] ?? null, 'q' => $q['q'] ?? null], Page::params($q)));
    });
    Route::get('broadcasts/{id}', fn () => Http::ok(Broadcasts::detail(Ctx::auth(), Ctx::id())))->whereNumber('id');
    // Resend → edit → change receivers → send: a NEW notification; the original stays as it was.
    Route::post('broadcasts/{id}/resend', function () use ($sendBody) {
        $b = $sendBody();
        $allowAll = Ctx::auth()->can('notifications.send_all');
        if (! empty($b['target']['all']) && ! $allowAll) throw ApiError::forbidden();
        return Http::created(Broadcasts::resend(Ctx::actx(), Ctx::id(), $b, $allowAll), 'Sent');
    })->whereNumber('id');
});

// Delivery chain health (push / email status counts, providers, background jobs).
Route::get('admin/notifications/health', fn () => Http::ok(\App\Mz\Notifications\Notifications::health()))
    ->middleware(['mz', 'mz:any,notifications.send,settings.manage']);
