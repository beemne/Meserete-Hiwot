<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\Professions;
use App\Mz\Support\Http;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Public & member accessible profession catalogue
Route::prefix('professions')->group(function () {
    Route::get('/', function () {
        $category = Ctx::q('category');
        return Http::ok(Professions::list(true, $category));
    });

    Route::get('categories', function () {
        return Http::ok(Professions::categories());
    });
});

// Admin profession catalogue management
Route::prefix('admin/professions')->middleware(['mz', 'mz:any,users.manage,settings.manage'])->group(function () {
    Route::get('/', function () {
        $category = Ctx::q('category');
        return Http::ok(Professions::list(false, $category));
    });

    Route::post('/', function () {
        $body = Ctx::body(Z::object([
            'category' => V::text(2, 100),
            'name' => V::text(2, 150),
            'is_active' => Z::boolean()->optional(),
            'sort_order' => Z::number()->int()->optional(),
        ]));
        return Http::created(Professions::create(Ctx::actx(), $body), 'Profession created');
    });

    Route::put('{id}', function (int $id) {
        $body = Ctx::body(Z::object([
            'category' => V::text(2, 100)->optional(),
            'name' => V::text(2, 150)->optional(),
            'is_active' => Z::boolean()->optional(),
            'sort_order' => Z::number()->int()->optional(),
        ]));
        return Http::ok(Professions::update(Ctx::actx(), $id, $body), null, 'Profession updated');
    });

    Route::delete('{id}', function (int $id) {
        return Http::ok(Professions::delete(Ctx::actx(), $id));
    });
});
