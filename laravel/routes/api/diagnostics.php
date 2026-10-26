<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Diagnostics;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Centralized error & problem reporting (user/mobile submission + admin supervision dashboard).
Route::prefix('diagnostics')->group(function () {
    // Submit an error report or user problem report
    Route::post('reports', function () {
        // Can be authenticated or guest (e.g. login error or offline queue sync)
        $auth = Ctx::authOrNull();
        $screenshot = Upload::single('diagnostic', 'screenshot', false);

        $input = request()->all();
        $res = Diagnostics::submitReport($auth, $input, $screenshot);
        return Http::created($res);
    })->middleware('mz.throttle:default');
});

Route::prefix('admin/diagnostics')->middleware('mz')->group(function () {
    // List reports with filters, search, and pagination
    Route::get('/', function () {
        $q = Ctx::q();
        $filters = [
            'status' => $q['status'] ?? null,
            'module' => $q['module'] ?? null,
            'severity' => $q['severity'] ?? null,
            'category' => $q['category'] ?? null,
            'is_user_report' => $q['is_user_report'] ?? null,
            'q' => $q['q'] ?? null,
        ];
        $pageParams = Page::params($q);
        return Http::ok(Diagnostics::listReports(Ctx::auth(), $filters, $pageParams));
    });

    // Get report details
    Route::get('{id}', function () {
        return Http::ok(Diagnostics::getReport(Ctx::auth(), Ctx::id()));
    });

    // Update report status
    Route::patch('{id}', function () {
        $b = Ctx::body(Z::object([
            'status' => Z::enum(['new', 'investigating', 'resolved', 'dismissed']),
            'note' => V::optionalText(2000),
        ]));
        return Http::ok(Diagnostics::updateStatus(Ctx::auth(), Ctx::id(), $b['status'], $b['note'] ?? null));
    });

    // Download/view screenshot securely
    Route::get('{id}/screenshot', function () {
        $res = Diagnostics::getScreenshot(Ctx::auth(), Ctx::id());
        return response()->file($res['abs'], [
            'Content-Type' => $res['mime'],
            'Content-Disposition' => "inline; filename=\"{$res['name']}\"",
            'Cache-Control' => 'private, no-cache',
        ]);
    });
});
