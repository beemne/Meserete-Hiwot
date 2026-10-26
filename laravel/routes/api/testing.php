<?php

use App\Mz\Jobs\Jobs;
use App\Mz\Jobs\ReminderJobs;
use App\Mz\Jobs\ScheduledNotifications;
use App\Mz\Support\Dates;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\Route;

// Test environment ONLY (NODE_ENV=test): lets the API test suite run background jobs at a given
// time. Never registered in production.
if (config('mz.is_test')) {
    Route::post('__test/jobs/{name}', function (string $name) {
        $now = request()->input('now') ? Dates::of(request()->input('now')) : null;
        return Http::ok(match ($name) {
            'scheduled' => ScheduledNotifications::releaseDue($now),
            'program-reminders' => ReminderJobs::programReminders($now),
            default => Jobs::runDue([$name], true),
        });
    });
}
