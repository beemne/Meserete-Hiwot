<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\SelectionCriteria;
use App\Mz\Support\Http;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Department selection criteria (v2) of a holiday selection: versions, departments' categories,
// the overall allocation and passing rules, approval, evaluators and manual scores. Each service
// call checks the department / high-level permission itself (see SelectionCriteria).
Route::prefix('selections/{id}/criteria')->middleware('mz')->group(function () {
    $dept = fn () => Z::enum(SelectionCriteria::DEPARTMENTS);
    $key = fn () => Z::string()->regex('/^[a-z0-9_]{2,60}$/', 'INVALID_KEY');
    Route::get('/', function () {
        $auth = Ctx::auth();
        SelectionCriteria::assertCanView($auth);
        $id = Ctx::id();
        return Http::ok(['versions' => SelectionCriteria::versions($id), 'active' => SelectionCriteria::active($id), 'evaluators' => SelectionCriteria::evaluators($id),
            'parts' => SelectionCriteria::ALLOCATION, 'access' => SelectionCriteria::access($auth), 'editors' => SelectionCriteria::editors()]);
    });
    Route::post('draft', fn () => Http::ok(SelectionCriteria::draft(Ctx::actx(), Ctx::id())));
    Route::post('revise', fn () => Http::created(SelectionCriteria::revise(Ctx::actx(), Ctx::id())));
    Route::put('rules', function () use ($dept) {
        $id = Ctx::id();
        $n = fn () => Z::number()->min(0)->max(100);
        $b = Ctx::body(Z::object([
            'passing' => Z::object([
                'total_minimum' => $n(),
                'department_minimums' => Z::object(['education' => $n()->nullable(), 'mezmur' => $n()->nullable(), 'dues' => $n()->nullable(), 'participation' => $n()->nullable()])->partial()->strict()->optional(),
                'quota' => Z::number()->int()->min(1)->max(100000)->nullable()->optional(),
                // The months counted for monthly dues and department participation (Ethiopian YYYY-MM).
                'months' => Z::object([
                    'from' => Z::string()->regex('/^\d{4}-(0[1-9]|1[0-3])$/', 'INVALID_PERIOD'),
                    'to' => Z::string()->regex('/^\d{4}-(0[1-9]|1[0-3])$/', 'INVALID_PERIOD'),
                ])->strict()->nullable()->optional(),
            ])->strict(),
        ])->strict());
        return Http::ok(SelectionCriteria::setRules(Ctx::actx(), $id, $b['passing']));
    });
    Route::put('departments/{dept}', function () use ($key) {
        $id = Ctx::id();
        $d = Ctx::params(Z::object(['dept' => Z::enum(SelectionCriteria::DEPARTMENTS)]))['dept'];
        $b = Ctx::body(Z::object(['criteria' => Z::array(Z::object([
            'key' => $key(),
            'name' => V::text(1, 120),
            'name_en' => V::optionalText(120),
            'source' => Z::enum(['manual', ...SelectionCriteria::BUILT_IN]),
            'weight' => Z::number()->min(0)->max(100),
            'max_score' => Z::number()->positive()->max(100000)->optional(),
            'min_points' => Z::number()->min(0)->max(100)->nullable()->optional(),
            'enabled' => Z::boolean()->optional(),
        ])->strict())->max(50)])->strict());
        return Http::ok(SelectionCriteria::setDepartment(Ctx::actx(), $id, $d, $b['criteria']));
    });
    Route::post('departments/{dept}/submit', function () {
        $id = Ctx::id();
        $d = Ctx::params(Z::object(['dept' => Z::enum(SelectionCriteria::DEPARTMENTS)]))['dept'];
        return Http::ok(SelectionCriteria::submitDepartment(Ctx::actx(), $id, $d));
    });
    Route::post('decision', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['decision' => Z::enum(['approve', 'reject']), 'comment' => V::optionalText(2000)])->strict());
        return Http::ok(SelectionCriteria::decide(Ctx::actx(), $id, $b['decision'], $b['comment'] ?? null));
    });

    // Manual evaluations
    Route::post('evaluators', function () use ($key) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['criterion_key' => $key(), 'user_id' => V::id()])->strict());
        return Http::ok(SelectionCriteria::assignEvaluator(Ctx::actx(), $id, $b['criterion_key'], $b['user_id']));
    });
    Route::get('scores/{key}', fn (string $id, string $key) => Http::ok(SelectionCriteria::sheet(Ctx::auth(), (int) $id, $key)));
    Route::put('scores/{key}', function (string $id, string $key) {
        $b = Ctx::body(Z::object(['scores' => Z::array(Z::object([
            'user_id' => V::id(),
            'raw_score' => Z::number()->min(0)->max(100000)->nullable()->optional(),
            'participated' => Z::boolean()->optional(),
            'note' => V::optionalText(500),
        ])->strict())->max(2000)])->strict());
        return Http::ok(SelectionCriteria::enter(Ctx::auth(), Ctx::id(), $key, $b['scores']));
    });
    Route::post('scores/{key}/submit', fn (string $id, string $key) => Http::ok(SelectionCriteria::submitScores(Ctx::auth(), (int) $id, $key)));
    Route::post('scores/{key}/review', function (string $id, string $key) {
        $b = Ctx::body(Z::object(['decision' => Z::enum(['approve', 'reject']), 'user_ids' => Z::array(V::id())->max(2000)->optional(), 'note' => V::optionalText(1000)])->strict());
        return Http::ok(SelectionCriteria::reviewScores(Ctx::actx(), Ctx::id(), $key, $b['decision'], $b['user_ids'] ?? null, $b['note'] ?? null));
    });
});

// Department administrators: the selections whose criteria their departments prepare.
Route::get('selection-criteria/mine', fn () => Http::ok(SelectionCriteria::mine(Ctx::auth())))->middleware('mz');
