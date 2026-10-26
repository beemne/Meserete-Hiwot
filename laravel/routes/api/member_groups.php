<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\MemberGroups;
use App\Mz\Support\Http;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Member types (groups): everyone signed in reads them (forms, filters, labels); member_groups.manage
// adds, renames, orders and switches off administrator-created types.
Route::prefix('member-groups')->middleware('mz')->group(function () {
    $schema = fn () => Z::object([
        'name' => V::text(2, 100),
        'name_en' => V::optionalText(100),
        'description' => V::optionalText(500),
        'sort_order' => Z::number()->int()->min(0)->max(1000)->optional(),
        'is_active' => Z::boolean()->optional(),
    ]);
    $key = fn () => Z::parse(Z::string()->regex('/^[a-z0-9_]{1,40}$/', 'INVALID_MEMBER_GROUP'), request()->route('key'));

    Route::get('/', function () {
        $auth = Ctx::auth();
        $manage = $auth->can('member_groups.manage');
        $all = (Ctx::q()['all'] ?? null) === 'true' && ($manage || $auth->isAdmin);
        return Http::ok(MemberGroups::list($all, $manage && $all));
    });
    Route::post('/', fn () => Http::created(MemberGroups::create(Ctx::actx(), Ctx::body($schema()->strict()))))->middleware('mz:all,member_groups.manage');
    Route::patch('{key}', function () use ($schema, $key) {
        $k = $key();
        return Http::ok(MemberGroups::update(Ctx::actx(), $k, Ctx::body($schema()->partial()->strict())));
    })->middleware('mz:all,member_groups.manage');
    Route::delete('{key}', function () use ($key) {
        MemberGroups::remove(Ctx::actx(), $key());
        return Http::ok(null);
    })->middleware('mz:all,member_groups.manage');
});
