<?php

use App\Mz\Auth\Audit;
use App\Mz\Http\Ctx;
use App\Mz\Services\MemberGroups;
use App\Mz\Services\MemberIds;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\Route;

// Member ID display format (prefix per member group; port of memberIds.routes.js). Numbers are never editable.
Route::prefix('member-ids')->middleware('mz')->group(function () {
    $withExamples = function (array $fmt): array {
        $examples = [];
        foreach (MemberGroups::keys() as $g) $examples[$g] = MemberIds::format(17, $g, $fmt);
        return $fmt + ['examples' => $examples];
    };
    Route::get('format', fn () => Http::ok($withExamples(MemberIds::loadFormat())))->middleware('mz:any,member_id.configure,users.view');
    Route::put('format', function () use ($withExamples) {
        $b = Ctx::body(MemberIds::formatSchema());
        $before = MemberIds::loadFormat();
        $saved = MemberIds::updateFormat($b, Ctx::auth()->id);
        Audit::log(Ctx::actx(), Audit::SETTINGS_UPDATE, 'setting', null, ['key' => 'member_id.format', 'before' => $before, 'after' => $saved]);
        return Http::ok($withExamples($saved));
    })->middleware('mz:all,member_id.configure');
});
