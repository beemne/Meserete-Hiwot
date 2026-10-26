<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Edu;
use App\Mz\Services\EduComplaints;
use App\Mz\Services\EduJourney;
use App\Mz\Services\EduMarks;
use App\Mz\Services\EduRequests;
use App\Mz\Services\EduTeachers;
use App\Mz\Support\EduSchemas;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Course management workflows of ትምህርት: teacher assignments, mark review and publication,
// student requests (changes, add / drop), confidential complaints and the academic journey.
// Every rule is enforced here and in the services — the app only hides what is not allowed.
Route::prefix('edu')->middleware(['mz', 'mz.module:education'])->group(function () {
    $page = fn () => Page::params(Ctx::q());
    $file = function (array $f) {
        $headers = ['Cache-Control' => 'private, no-store', 'Content-Type' => $f['mime']];
        if ($f['name']) $headers['Content-Disposition'] = "attachment; filename*=UTF-8''" . rawurlencode($f['name']);
        return response()->file($f['abs'], $headers);
    };

    // ---- the signed-in student ----
    Route::get('me/journey', fn () => Http::page(EduJourney::forUser(Ctx::auth()->id, $page())));
    Route::get('me/requests', fn () => Http::ok(EduRequests::mine(Ctx::auth())));
    Route::post('me/requests', fn () => Http::created(EduRequests::create(Ctx::auth(), Ctx::body(EduSchemas::request()))));
    Route::delete('me/requests/{id}', fn () => Http::ok(EduRequests::cancel(Ctx::auth(), Ctx::id())));
    Route::get('me/complaints', fn () => Http::ok(EduComplaints::mine(Ctx::auth())));
    Route::post('me/complaints', function () {
        $file = Upload::optional('project');
        $in = Ctx::body(EduSchemas::complaint());
        return Http::created(EduComplaints::create(Ctx::auth(), $in, $file));
    });
    Route::get('me/complaints/{id}', fn () => Http::ok(EduComplaints::getOwn(Ctx::auth(), Ctx::id())));
    Route::post('me/complaints/{id}/messages', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['body' => V::text(1, 4000)])->strict());
        return Http::ok(EduComplaints::studentMessage(Ctx::auth(), $id, $b['body']));
    });
    Route::get('complaints/{id}/attachment', fn () => $file(EduComplaints::attachment(Ctx::auth(), Ctx::id())));

    // ---- teachers (an active assignment to the subject) ----
    Route::get('teaching', fn () => Http::ok(EduTeachers::teaching(Ctx::auth())));
    Route::post('assessments/{id}/submit', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['user_ids' => Z::array(V::id())->max(2000)->optional()])->strict());
        return Http::ok(EduMarks::submit(Ctx::auth(), $id, $b['user_ids'] ?? null));
    });

    // ---- education administrators ----
    Route::middleware('mz:all,education.manage')->prefix('admin')->group(function () use ($page) {
        Route::get('courses/{id}/teachers', fn () => Http::ok(EduTeachers::list(Ctx::id())));
        Route::post('courses/{id}/teachers', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['user_id' => V::id(), 'note' => V::optionalText(500)])->strict());
            return Http::created(EduTeachers::assign(Ctx::actx(), $id, $b['user_id'], $b['note'] ?? null));
        });
        Route::patch('course-teachers/{id}', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['status' => Z::enum(EduTeachers::STATUSES), 'note' => V::optionalText(500)])->strict());
            return Http::ok(EduTeachers::setStatus(Ctx::actx(), $id, $b['status'], $b['note'] ?? null));
        });

        Route::get('marks', function () use ($page) {
            $q = Ctx::query(Z::object([
                'status' => Z::enum(['submitted', 'approved', 'rejected', 'published', 'draft'])->optional(),
                'class_id' => Z::coerceNumber()->int()->positive()->optional(),
                'course_id' => Z::coerceNumber()->int()->positive()->optional(),
                'page' => Z::coerceNumber()->int()->positive()->optional(),
                'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            ]));
            return Http::page(EduMarks::queue($q, $page()));
        });
        Route::post('assessments/{id}/review', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object([
                'decision' => Z::enum(['approve', 'reject']),
                'user_ids' => Z::array(V::id())->max(2000)->optional(),
                'note' => V::optionalText(1000),
                'publish' => Z::boolean()->optional(),
            ])->strict());
            return Http::ok(EduMarks::review(Ctx::actx(), $id, $b['decision'], $b['user_ids'] ?? null, $b['note'] ?? null, (bool) ($b['publish'] ?? false)));
        });
        Route::post('assessments/{id}/publish', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['user_ids' => Z::array(V::id())->max(2000)->optional()])->strict());
            return Http::ok(EduMarks::publish(Ctx::actx(), $id, $b['user_ids'] ?? null));
        });
        Route::post('assessments/{id}/amend', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['user_id' => V::id(), 'score' => EduSchemas::score()->nullable(), 'reason' => V::text(3, 1000)])->strict());
            return Http::ok(EduMarks::amend(Ctx::actx(), $id, $b['user_id'], $b['score'] === null ? null : (float) $b['score'], $b['reason']));
        });
        Route::get('assessments/{id}/history', function () {
            $id = Ctx::id();
            $q = Ctx::query(Z::object(['user_id' => Z::coerceNumber()->int()->positive()->optional()]));
            return Http::ok(EduMarks::log($id, $q['user_id'] ?? null));
        });

        Route::get('requests', function () use ($page) {
            $q = Ctx::query(Z::object([
                'status' => Z::enum(['pending', 'approved', 'rejected', 'cancelled', 'implemented'])->optional(),
                'type' => Z::enum(EduRequests::TYPES)->optional(),
                'class_id' => Z::coerceNumber()->int()->positive()->optional(),
                'q' => Z::string()->trim()->max(100)->optional(),
                'page' => Z::coerceNumber()->int()->positive()->optional(),
                'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            ]));
            return Http::page(EduRequests::adminList($q, $page()));
        });
        Route::post('requests/{id}/review', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object(['decision' => Z::enum(['approve', 'reject']), 'note' => V::optionalText(1000)])->strict());
            return Http::ok(EduRequests::review(Ctx::actx(), $id, $b['decision'], $b['note'] ?? null));
        });

        Route::get('complaints', function () use ($page) {
            $q = Ctx::query(Z::object([
                'status' => Z::enum(EduComplaints::STATUSES)->optional(),
                'category' => Z::enum(EduComplaints::CATEGORIES)->optional(),
                'assigned_to' => Z::coerceNumber()->int()->positive()->optional(),
                'q' => Z::string()->trim()->max(100)->optional(),
                'page' => Z::coerceNumber()->int()->positive()->optional(),
                'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            ]));
            return Http::page(EduComplaints::adminList($q, $page()));
        });
        Route::get('complaints/{id}', fn () => Http::ok(EduComplaints::getForReviewer(Ctx::id())));
        Route::post('complaints/{id}/actions', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object([
                'body' => V::optionalText(4000),
                'internal' => Z::boolean()->optional(),
                'status' => Z::enum(EduComplaints::STATUSES)->optional(),
                'assigned_to' => V::id()->nullable()->optional(),
            ])->strict());
            return Http::ok(EduComplaints::act(Ctx::actx(), $id, $b));
        });

        Route::get('students/{userId}/journey', fn () => Http::page(EduJourney::forUser(Ctx::id('userId'), $page())));
        // Add or drop a subject for a student directly (recorded in the journey).
        Route::post('students/{userId}/subjects', function () {
            $uid = Ctx::id('userId');
            $b = Ctx::body(Z::object(['course_id' => V::id(), 'action' => Z::enum(['add', 'drop']), 'reason' => V::optionalText(500)])->strict());
            return Http::ok(Edu::setStudentSubject(Ctx::actx(), $uid, $b['course_id'], $b['action'] === 'add', $b['reason'] ?? null));
        });
        Route::patch('classes/{id}/students/{userId}', function () {
            $id = Ctx::id();
            $uid = Ctx::id('userId');
            $b = Ctx::body(Z::object(['program' => Z::enum(['regular', 'distance'])->optional(), 'stream' => V::optionalText(80), 'reason' => V::optionalText(500)])->strict());
            return Http::ok(Edu::updateEnrollment(Ctx::actx(), $id, $uid, $b));
        });
    });
});
