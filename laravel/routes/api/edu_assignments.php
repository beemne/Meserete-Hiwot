<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\EduAssignments;
use App\Mz\Support\EduSchemas;
use App\Mz\Support\Http;
use Illuminate\Support\Facades\Route;

Route::prefix('edu')->middleware(['mz', 'mz.module:education'])->group(function () {
    // ---- students: assignments list & detail & submission ----
    Route::get('me/assignments', function () {
        $courseId = Ctx::q()['course_id'] ?? null;
        return Http::ok(EduAssignments::studentList(Ctx::auth(), is_numeric($courseId) ? (int) $courseId : null));
    });
    Route::get('assignments/{id}', fn () => Http::ok(EduAssignments::studentDetail(Ctx::auth(), Ctx::id())));
    Route::post('assignments/{id}/submit', function () {
        $id = Ctx::id();
        $file = Upload::single('submission');
        $body = Ctx::input();
        return Http::ok(EduAssignments::submit(Ctx::auth(), $id, $body, $file));
    });

    // ---- teachers & admins: assignment authoring, grading & release ----
    Route::get('courses/{id}/assignments', fn () => Http::ok(EduAssignments::teacherList(Ctx::auth(), Ctx::id())));
    Route::post('courses/{id}/assignments', function () {
        $id = Ctx::id();
        $body = Ctx::body(EduSchemas::assignment()->partial());
        $body['course_id'] = $id;
        return Http::created(EduAssignments::create(Ctx::actx(), $body));
    });
    Route::get('teacher/assignments', fn () => Http::ok(EduAssignments::teacherList(Ctx::auth())));
    Route::post('assignments', fn () => Http::created(EduAssignments::create(Ctx::actx(), Ctx::body(EduSchemas::assignment()))));
    Route::patch('assignments/{id}', function () {
        $id = Ctx::id();
        return Http::ok(EduAssignments::update(Ctx::actx(), $id, Ctx::body(EduSchemas::assignment()->partial()->strict())));
    });
    Route::delete('assignments/{id}', function () {
        EduAssignments::delete(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::get('assignments/{id}/submissions', fn () => Http::ok(EduAssignments::listSubmissions(Ctx::auth(), Ctx::id())));
    Route::put('assignment-submissions/{id}/grade', function () {
        $id = Ctx::id();
        $b = Ctx::body(EduSchemas::assignmentGrade());
        return Http::ok(EduAssignments::gradeSubmission(
            Ctx::actx(),
            $id,
            (float) $b['score'],
            $b['feedback'] ?? null,
            isset($b['release']) ? (bool) $b['release'] : true
        ));
    });
    Route::post('assignments/{id}/release', fn () => Http::ok(EduAssignments::releaseGrades(Ctx::actx(), Ctx::id())));
});
