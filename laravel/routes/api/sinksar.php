<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\Sinksar;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Daily Sinksar (Synaxarium) & Ethiopian Orthodox Commemorations API
Route::prefix('sinksar')->group(function () {
    // Open to all signed-in users (and fallback anonymous if token not required)
    Route::get('today', fn () => Http::ok(Sinksar::forToday()));

    Route::get('{date}', function () {
        $date = (string) request()->route('date');
        return Http::ok(Sinksar::forDate($date));
    });

    // Admin / Scheduler routes
    Route::post('refresh', function () {
        if (!Ctx::auth()->isAdmin && empty(Ctx::auth()->permissions['education.manage'])) {
            throw ApiError::forbidden('FORBIDDEN', 'Administrative permission required');
        }
        $today = Sinksar::forToday();
        return Http::ok(['refreshed' => true, 'today' => $today]);
    })->middleware('mz');

    Route::post('send-daily-notification', function () {
        if (!Ctx::auth()->isAdmin && empty(Ctx::auth()->permissions['notifications.manage'])) {
            throw ApiError::forbidden('FORBIDDEN', 'Administrative permission required');
        }
        return Http::ok(Sinksar::sendDailyNotification());
    })->middleware('mz');

    Route::post('test-notification', function () {
        $date = request()->input('date');
        return Http::ok(Sinksar::sendTestNotification(Ctx::auth(), is_string($date) ? $date : null));
    })->middleware('mz');
});
