<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\AuthService;
use App\Mz\Services\Users;
use App\Mz\Support\Http;
use App\Mz\Support\MemberSchemas;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// /auth (port of auth.routes.js + validators/auth.js)
Route::prefix('auth')->group(function () {
    $identifier = fn () => Z::string(['required_error' => 'REQUIRED'])->trim()->min(3, 'REQUIRED')->max(190);

    Route::post('register', function () {
        $body = Ctx::body(Z::object([
            'full_name' => V::text(2, 150),
            'phone' => V::phone(),
            'email' => V::optionalEmail(),
            // Members sign up with a 4 or 6 digit PIN (older app versions still send a password).
            'pin' => V::pin()->optional(),
            'password' => V::password()->optional(),
            'device_id' => V::deviceId(),
            'device_name' => V::deviceName(),
            'member_group' => V::memberGroup(true)->refine(fn ($v) => $v !== 'children', 'INVALID_MEMBER_GROUP')->optional(),
            'member_type' => Z::enum(['student', 'worker'])->nullable()->optional(),
            'profile' => MemberSchemas::profile()->optional(),
        ]));
        $body['password'] = $body['pin'] ?? $body['password'] ?? null;
        if ($body['password'] === null) throw \App\Mz\Support\ApiError::field('pin', 'REQUIRED');
        return Http::created(AuthService::register($body, Ctx::meta()), 'Registered');
    })->middleware('mz.throttle:auth');

    Route::post('login', function () use ($identifier) {
        $body = Ctx::body(Z::object([
            'identifier' => $identifier(),
            'password' => Z::string(['required_error' => 'REQUIRED'])->min(1, 'REQUIRED')->max(128),
            'device_id' => V::deviceId(),
            'device_name' => V::deviceName(),
        ]));
        return Http::ok(AuthService::login($body, Ctx::meta()), null, 'Logged in');
    })->middleware('mz.throttle:auth');

    Route::post('refresh', function () {
        $body = Ctx::body(Z::object([
            'refresh_token' => Z::string(['required_error' => 'REQUIRED'])->min(20)->max(200),
            'device_id' => Z::string()->max(128)->optional(),
        ]));
        return Http::ok(AuthService::refresh($body, Ctx::meta(), 'app'));
    })->middleware('mz.throttle:auth');

    Route::post('logout', function () {
        $body = Ctx::body(Z::object(['refresh_token' => Z::string()->max(200)->optional()]));
        AuthService::logout(Ctx::authOrNull(), $body);
        return Http::ok(null, null, 'Logged out');
    })->middleware('mz:optional');

    Route::post('forgot-password', function () use ($identifier) {
        AuthService::forgotPassword(Ctx::body(Z::object(['identifier' => $identifier()])));
        return Http::ok(null, null, 'If the account exists, a reset code has been sent');
    })->middleware('mz.throttle:reset');

    Route::post('reset-password', function () use ($identifier) {
        AuthService::resetPassword(Ctx::body(Z::object([
            'identifier' => $identifier(),
            'code' => Z::string()->regex('/^\d{6}$/', 'INVALID_CODE'),
            // Members may choose a PIN; administrators need a password (checked in the service).
            'new_password' => V::pinOrPassword(),
        ])));
        return Http::ok(null, null, 'Password reset');
    })->middleware('mz.throttle:reset');

    Route::get('me', fn () => Http::ok(Users::toPublic(Users::findPublicById(Ctx::auth()->id), Ctx::auth())))->middleware('mz');

    Route::post('change-password', function () {
        $body = Ctx::body(Z::object([
            'current_password' => Z::string(['required_error' => 'REQUIRED'])->min(1, 'REQUIRED')->max(128),
            'new_password' => V::pinOrPassword(),
        ]));
        return Http::ok(AuthService::changePassword(Ctx::auth(), $body, Ctx::meta()), null, 'Password changed');
    })->middleware(['mz', 'mz.throttle:auth']);
});
