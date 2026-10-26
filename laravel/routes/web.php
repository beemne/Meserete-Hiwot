<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

Route::get('/health', function () {
    try {
        DB::select('SELECT 1');
        return response()->json(['status' => 'ok']);
    } catch (Throwable) {
        return response()->json(['status' => 'unavailable'], 503);
    }
});

Route::get('/', function () {
    if (file_exists(public_path('index.html'))) {
        return response()->file(public_path('index.html'));
    }
    return response()->json([
        'name' => 'Mezmur Zemseretee Hiwot API',
        'status' => 'running',
        'version' => '1.5.3',
        'health' => '/health',
        'download' => '/download',
    ]);
});

// Public files, the download page and share links: routes/web/*.php.
foreach (glob(__DIR__ . '/web/*.php') as $file) {
    require $file;
}
