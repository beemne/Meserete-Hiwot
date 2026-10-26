<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\Choir;
use App\Mz\Services\Selections;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// The member's holiday-selection dashboard (choir.routes.js) and selection management (selections.routes.js).
Route::prefix('choir')->middleware('mz')->group(function () {
    Route::get('me', fn () => Http::ok(Choir::mine(Ctx::auth()->id)));
    Route::get('me/education-calendar', function () {
        $q = Ctx::query(Z::object(['from' => V::dateOnly(), 'to' => V::dateOnly()]));
        return Http::ok(Choir::educationCalendar(Ctx::auth()->id, $q['from'], $q['to']));
    });
});

Route::prefix('selections')->middleware('mz')->group(function () {
    $ids = fn () => Z::array(V::id())->max(200);
    $n = fn () => Z::number()->min(0)->max(100);
    $config = fn () => Z::object([
        'weights' => Z::object(['course_attendance' => $n(), 'exam' => $n(), 'mezmur_attendance' => $n(), 'contribution' => $n(), 'participation' => $n()])->partial()->strict(),
        'minimums' => Z::object(['course_attendance' => $n()->nullable(), 'exam' => $n()->nullable(), 'mezmur_attendance' => $n()->nullable(), 'contribution' => $n()->nullable(), 'participation' => $n()->nullable()])->partial()->strict(),
        'total_minimum' => Z::number()->min(0)->max(130),
        'exams_required' => Z::boolean(),
        'education' => Z::object(['class_ids' => $ids(), 'course_ids' => $ids()])->strict(),
        'mezmur' => Z::object(['category_ids' => $ids(), 'included_program_ids' => $ids(), 'excluded_program_ids' => $ids()])->strict(),
        'contribution' => Z::object([
            'late_credit' => Z::number()->min(0)->max(1)->optional(),
            'year' => Z::coerceNumber()->int()->min(1900)->max(2200)->nullable()->optional(),
            'start_month' => Z::coerceNumber()->int()->min(1)->max(13)->nullable()->optional(),
            'end_month' => Z::coerceNumber()->int()->min(1)->max(13)->nullable()->optional(),
        ])->strict()->refine(function ($c) {
            $sm = $c['start_month'] ?? null;
            $em = $c['end_month'] ?? null;
            if (($sm === null) !== ($em === null)) {
                return false;
            }
            if ($sm !== null && $em !== null && $sm > $em) {
                return false;
            }
            return true;
        }, 'MONTH_RANGE_INVALID'),
        'bonus' => Z::object(['max' => Z::number()->min(0)->max(Selections::BONUS_MAX), 'category_ids' => $ids(), 'program_ids' => $ids()])->strict(),
        // Points per attendance status (0–100) and per-program weights, set per selection.
        'attendance' => Z::object([
            'present' => $n(), 'late' => $n(), 'excused' => $n()->nullable(), 'absent' => $n(),
            'program_weights' => Z::array(Z::object(['program_id' => V::id(), 'weight' => Z::number()->min(0)->max(10)])->strict())->max(200),
        ])->partial()->strict(),
        'attendance_rules' => Z::object([
            'mezmur' => Z::object([
                'category_ids' => $ids()->optional(),
                'intervals' => Z::array(Z::object([
                    'from' => Z::number()->min(0),
                    'to' => Z::number()->min(0),
                    'percent' => $n(),
                ])->strict())->optional(),
                'after_last_percent' => $n()->optional(),
            ])->partial()->strict()->optional(),
            'education' => Z::object([
                'class_ids' => $ids()->optional(),
                'course_ids' => $ids()->optional(),
                'intervals' => Z::array(Z::object([
                    'from' => Z::number()->min(0),
                    'to' => Z::number()->min(0),
                    'percent' => $n(),
                ])->strict())->optional(),
                'after_last_percent' => $n()->optional(),
                'overrides' => Z::array(Z::object([
                    'class_id' => V::id(),
                    'intervals' => Z::array(Z::object([
                        'from' => Z::number()->min(0),
                        'to' => Z::number()->min(0),
                        'percent' => $n(),
                    ])->strict())->optional(),
                    'after_last_percent' => $n()->optional(),
                ])->strict())->optional(),
            ])->partial()->strict()->optional(),
        ])->partial()->strict()->optional(),
    ])->partial()->strict();
    $groups = fn () => V::memberGroups();
    $view = 'mz:any,selection.view,selection.configure,selection.review,selection.finalize';

    Route::get('options', fn () => Http::ok(Selections::options()))->middleware($view);
    Route::get('/', function () {
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'status' => Z::enum(['draft', 'open', 'review', 'finalized', 'cancelled'])->optional(),
        ]));
        return Http::page(Selections::list($q['status'] ?? null, Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null])));
    })->middleware($view);
    Route::get('{id}', fn () => Http::ok(Selections::get(Ctx::id())))->middleware($view);
    Route::post('/', function () use ($config, $groups) {
        $b = Ctx::body(Z::object(['name' => V::text(2, 150), 'from' => V::dateOnly(), 'to' => V::dateOnly(), 'member_groups' => $groups()->optional(), 'config' => $config()->optional()])->strict());
        return Http::created(Selections::create(Ctx::actx(), $b));
    })->middleware('mz:all,selection.configure');
    Route::patch('{id}', function () use ($config, $groups) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'name' => V::text(2, 150)->optional(),
            'from' => V::dateOnly()->optional(),
            'to' => V::dateOnly()->optional(),
            'member_groups' => $groups()->optional(),
            'config' => $config()->optional(),
            'reason' => V::optionalText(500),
        ])->strict());
        return Http::ok(Selections::update(Ctx::actx(), $id, $b));
    })->middleware('mz:any,selection.configure,selection.exams');
    Route::post('{id}/status', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['status' => Z::enum(['open', 'review', 'finalized', 'cancelled']), 'reason' => V::optionalText(500)])->strict());
        return Http::ok(Selections::setStatus(Ctx::actx(), $id, $b['status'], $b['reason'] ?? null));
    })->middleware('mz:any,selection.configure,selection.review,selection.finalize');
    Route::post('{id}/compute', fn () => Http::ok(Selections::compute(Ctx::id())))->middleware('mz:any,selection.configure,selection.review');
    Route::get('{id}/results', function () {
        $id = Ctx::id();
        $q = Ctx::query(Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'result' => Z::enum(['qualified', 'not_qualified'])->optional(),
            'missing' => Z::enum(['true'])->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
        ]));
        $page = Page::params(['page' => $q['page'] ?? null, 'limit' => $q['limit'] ?? null]);
        unset($q['page'], $q['limit']);
        $out = Selections::results($id, $q, $page);
        return Http::ok($out['items'], $out['meta']);
    })->middleware($view);
    Route::get('{id}/results/{userId}', fn () => Http::ok(Selections::result(Ctx::id(), Ctx::id('userId'))))->middleware($view);
    Route::put('{id}/results/{userId}/override', function () {
        $id = Ctx::id();
        $uid = Ctx::id('userId');
        $b = Ctx::body(Z::object(['decision' => Z::enum(['qualified', 'not_qualified', 'clear']), 'reason' => V::text(3, 1000)])->strict());
        return Http::ok(Selections::override(Ctx::actx(), $id, $uid, $b['decision'], $b['reason']));
    })->middleware('mz:any,selection.review,selection.finalize');

    // Reviews (Req 22)
    Route::get('{id}/reviews', fn () => Http::ok(Selections::reviews(Ctx::id())))->middleware($view);
    Route::post('{id}/reviews', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'department_name' => Z::string()->trim()->max(150)->optional(),
            'department_id' => V::id()->optional(),
            'decision' => Z::enum(['approved', 'rejected']),
            'comments' => V::optionalText(1000),
        ])->strict());
        return Http::ok(Selections::submitReview(Ctx::actx(), $id, $b));
    })->middleware('mz:any,selection.review,selection.configure');
    Route::put('{id}/required-reviewers', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['departments' => Z::array(Z::string()->trim()->max(150))->min(1)])->strict());
        return Http::ok(Selections::setRequiredDepartments(Ctx::actx(), $id, $b['departments']));
    })->middleware('mz:all,selection.configure');

    // Service Categories & Ranking (Req 24)
    Route::post('{id}/categories/assign', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'assignments' => Z::array(Z::object([
                'user_id' => V::id(),
                'category' => Z::enum(Selections::SERVICE_CATEGORIES)->nullable(),
            ])->strict())->min(1),
        ])->strict());
        return Http::ok(Selections::assignCategories(Ctx::actx(), $id, $b['assignments']));
    })->middleware('mz:any,selection.finalize,choir.manage,choir.assign');
    Route::get('{id}/ranked-categories', fn () => Http::ok(Selections::rankedCategories(Ctx::id())))->middleware($view);
    Route::post('{id}/publish', fn () => Http::ok(Selections::publish(Ctx::actx(), Ctx::id())))->middleware('mz:all,selection.finalize');

    // Member Feedback (Req 25)
    Route::post('{id}/feedback', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['comments' => V::text(3, 2000)])->strict());
        return Http::ok(Selections::submitFeedback(Ctx::actx(), $id, $b['comments']));
    })->middleware('mz');
    Route::get('{id}/feedback', fn () => Http::ok(Selections::feedbackList(Ctx::id())))->middleware($view);
});
