<?php

use App\Mz\Notifications\Telegram;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Route;

// Telegram webhook (production). Answers 404 unless the secret header matches; the update is
// handled after the response is sent so Telegram never waits on us.
Route::post('telegram/webhook', function (Request $r) {
    if (! Telegram::verifyWebhookSecret($r->header('X-Telegram-Bot-Api-Secret-Token'))) return response('', 404);
    $update = json_decode($r->getContent(), true);
    app()->terminating(function () use ($update) {
        try {
            Telegram::handleUpdate(is_array($update) ? $update : null);
        } catch (\Throwable $e) {
            Log::error('telegram webhook update failed', ['error' => $e->getMessage()]);
        }
    });
    return response()->json(['ok' => true]);
});
