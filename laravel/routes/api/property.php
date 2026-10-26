<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\PropertyRequests;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Department property requests (port of property.routes.js).
Route::prefix('property-requests')->middleware('mz')->group(function () {
    $any = 'mz:any,property.request,property.review';
    Route::get('/', function () {
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'status' => Z::enum(['draft', 'submitted', 'under_review', 'approved', 'rejected', 'issued', 'partially_issued', 'returned', 'cancelled'])->optional(),
            'department_id' => Z::coerceNumber()->int()->positive()->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
        ]));
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        return Http::page(PropertyRequests::list(Ctx::auth(), $q, $page));
    })->middleware($any);
    Route::get('{id}', fn () => Http::ok(PropertyRequests::get(Ctx::auth(), Ctx::id())))->middleware($any);
    Route::post('/', fn () => Http::created(PropertyRequests::create(Ctx::actx(), Ctx::body(Z::object([
        'department_id' => V::id(),
        'item_id' => V::id()->nullable()->optional(),
        'item_name' => V::optionalText(200),
        'quantity' => Z::number()->int()->min(1)->max(100000)->nullable()->optional(),
        'purpose' => V::text(3, 1000),
        'needed_on' => V::dateOnly()->nullable()->optional(),
        'return_on' => V::dateOnly()->nullable()->optional(),
        'draft' => Z::boolean()->optional(),
    ])->strict()))))->middleware('mz:all,property.request');
    Route::post('{id}/{action}', function (string $id, string $action) {
        $b = Ctx::body(Z::object(['note' => V::optionalText(1000)])->strict());
        return Http::ok(PropertyRequests::transition(Ctx::actx(), (int) $id, $action, $b['note'] ?? null));
    })->where('action', 'submit|review|approve|reject|cancel')->middleware($any);
    Route::post('{id}/issue', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['quantity' => Z::number()->int()->min(1)->max(100000)->optional(), 'note' => V::optionalText(1000)])->strict());
        return Http::ok(PropertyRequests::issue(Ctx::actx(), $id, $b));
    })->middleware('mz:all,property.review');
    Route::post('{id}/return', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['quantity' => Z::number()->int()->min(1)->max(100000)->optional(), 'condition' => V::optionalText(100), 'note' => V::optionalText(1000)])->strict());
        return Http::ok(PropertyRequests::returnItems(Ctx::actx(), $id, $b));
    })->middleware('mz:all,property.review');
});
