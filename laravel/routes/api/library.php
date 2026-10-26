<?php

use App\Mz\Http\Ctx;
use App\Mz\Services\Library;
use App\Mz\Services\LibraryCirculation;
use App\Mz\Services\Storage;
use App\Mz\Support\BorrowSchemas;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;

// The members' library: digital books (PDF downloads) and requests for physical books, handed over
// with the member's signature by the librarian (rules in App\Mz\Services\Library).
Route::prefix('library')->middleware('mz')->group(function () {
    $domain = fn (array $q) => in_array($q['domain'] ?? null, ['mezmur', 'timhirt'], true) ? $q['domain'] : null;

    // ---- Books & categories (members) ----
    Route::get('books', function () use ($domain) {
        $q = Ctx::q();
        return Http::page(Library::books(Ctx::auth(), [
            'domain' => $domain($q),
            'kind' => in_array($q['kind'] ?? null, ['physical', 'digital'], true) ? $q['kind'] : null,
            'category' => is_string($q['category'] ?? null) ? mb_substr($q['category'], 0, 100) : null,
            'category_id' => ! empty($q['category_id']) ? (int) $q['category_id'] : null,
            'favorites_only' => ! empty($q['favorites_only']) && ($q['favorites_only'] === 'true' || $q['favorites_only'] === '1' || $q['favorites_only'] === true),
            'q' => is_string($q['q'] ?? null) ? mb_substr(trim($q['q']), 0, 100) : null,
        ], Page::params($q)));
    });

    Route::get('books/{id}', fn () => Http::ok(Library::book(Ctx::auth(), Ctx::id())));

    Route::get('categories', function () use ($domain) {
        $q = Ctx::q();
        $tree = ! empty($q['tree']) && ($q['tree'] === 'true' || $q['tree'] === '1');
        return Http::ok(Library::categories($domain($q), $tree));
    });

    Route::get('books/{id}/file', function () {
        $f = Library::file(Ctx::auth(), Ctx::id());
        if (request()->query('download') === '1' || request()->query('download') === 'true') {
            return response()->download($f['abs'], $f['name'], ['Content-Type' => $f['mime'], 'Cache-Control' => 'private, max-age=3600']);
        }
        return response()->file($f['abs'], [
            'Content-Type' => $f['mime'],
            'Content-Disposition' => 'inline; filename="' . $f['name'] . '"',
            'Accept-Ranges' => 'bytes',
            'Cache-Control' => 'private, max-age=3600',
        ]);
    });

    Route::get('books/{id}/narration', function () {
        $f = Library::narrationFile(Ctx::auth(), Ctx::id());
        return response()->file($f['abs'], ['Content-Type' => $f['mime'], 'Cache-Control' => 'private, max-age=86400']);
    });

    // ---- Favorites (F16) ----
    Route::get('favorites', fn () => Http::page(Library::myFavorites(Ctx::auth(), Page::params(Ctx::q()))));
    Route::post('books/{id}/favorite', fn () => Http::ok(Library::favorite(Ctx::auth()->id, Ctx::id(), true)));
    Route::delete('books/{id}/favorite', fn () => Http::ok(Library::favorite(Ctx::auth()->id, Ctx::id(), false)));

    // ---- Progress (F16) ----
    Route::get('books/{id}/progress', fn () => Http::ok(Library::getProgress(Ctx::auth()->id, Ctx::id()) ?: ['page' => 1, 'page_count' => null, 'audio_position_ms' => 0]));
    Route::post('books/{id}/progress', function () {
        $b = Ctx::body(Z::object([
            'page' => Z::number()->int()->min(1),
            'page_count' => Z::number()->int()->min(1)->optional(),
            'audio_position_ms' => Z::number()->int()->min(0)->optional(),
        ]));
        return Http::ok(Library::saveProgress(Ctx::auth()->id, Ctx::id(), $b));
    });

    // ---- Requests (Legacy / Hold requests) ----
    Route::post('books/{id}/request', function () {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'quantity' => Z::number()->int()->min(1)->max(20)->optional(),
            'note' => V::optionalText(500),
            'needed_on' => V::dateOnly()->nullable()->optional(),
        ]));
        return Http::created(Library::request(Ctx::actx(), $id, $b));
    });
    Route::get('requests/me', fn () => Http::page(Library::myRequests(Ctx::auth(), Page::params(Ctx::q()))));
    Route::delete('requests/{id}', fn () => Http::ok(Library::cancel(Ctx::actx(), Ctx::id())));

    // ---- Staff: Categories Management (items.manage / library.circulate) ----
    Route::middleware('mz:all,items.manage,library.circulate')->group(function () {
        Route::post('categories', function () {
            $b = Ctx::body(Z::object([
                'name' => V::text(1, 200),
                'name_en' => V::optionalText(200),
                'code' => V::optionalText(32),
                'domain' => Z::enum(['timhirt', 'mezmur'])->optional(),
                'parent_id' => Z::number()->int()->positive()->optional(),
                'sort_order' => Z::number()->int()->min(0)->optional(),
            ]));
            return Http::created(Library::saveCategory(Ctx::actx(), $b));
        });

        Route::put('categories/{id}', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object([
                'name' => V::text(1, 200),
                'name_en' => V::optionalText(200),
                'code' => V::optionalText(32),
                'domain' => Z::enum(['timhirt', 'mezmur'])->optional(),
                'parent_id' => Z::number()->int()->positive()->nullable()->optional(),
                'sort_order' => Z::number()->int()->min(0)->optional(),
            ]));
            return Http::ok(Library::saveCategory(Ctx::actx(), $b, $id));
        });

        Route::delete('categories/{id}', fn () => Http::ok(Library::deleteCategory(Ctx::actx(), Ctx::id())));

        Route::post('books/{id}/narration', function () {
            $id = Ctx::id();
            $file = request()->file('file');
            if (! $file) throw \App\Mz\Support\ApiError::field('file', 'FILE_REQUIRED', 'Audio file required');
            $duration = request()->input('duration') ? (int) request()->input('duration') : null;
            return Http::ok(Library::uploadNarration(Ctx::actx(), $id, $file, $duration));
        });
    });

    // ---- Librarian Requests (borrowing.manage) ----
    Route::middleware('mz:all,borrowing.manage')->group(function () use ($domain) {
        Route::get('requests', function () use ($domain) {
            $q = Ctx::q();
            $status = array_values(array_intersect(explode(',', (string) ($q['status'] ?? '')), ['requested', 'approved', 'rejected', 'issued', 'cancelled']));
            return Http::page(Library::adminRequests(['status' => $status ?: null, 'domain' => $domain($q), 'q' => is_string($q['q'] ?? null) ? mb_substr($q['q'], 0, 100) : null], Page::params($q)));
        });
        Route::post('requests/{id}/approve', function () {
            $id = Ctx::id();
            return Http::ok(Library::approve(Ctx::actx(), $id, Ctx::body(Z::object(['note' => V::optionalText(500)]))['note'] ?? null));
        });
        Route::post('requests/{id}/reject', function () {
            $id = Ctx::id();
            return Http::ok(Library::reject(Ctx::actx(), $id, Ctx::body(Z::object(['reason' => V::text(2, 500)]))['reason']));
        });
        Route::post('requests/{id}/issue', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object([
                'signature' => BorrowSchemas::signature(),
                'due_on' => V::dateOnly()->optional(),
                'loan_days' => Z::number()->int()->min(1)->max(365)->optional(),
                'notes' => V::optionalText(500),
            ]));
            return Http::ok(Library::issue(Ctx::actx(), $id, $b));
        });
    });

    // ---- F17 Physical Sunday-School Library Circulation (library.circulate, borrowing.manage) ----
    Route::middleware('mz:all,library.circulate,borrowing.manage')->prefix('circulation')->group(function () use ($domain) {
        Route::get('copies', function () use ($domain) {
            $q = Ctx::q();
            return Http::page(LibraryCirculation::copies([
                'domain' => $domain($q),
                'item_id' => ! empty($q['item_id']) ? (int) $q['item_id'] : null,
                'status' => in_array($q['status'] ?? null, LibraryCirculation::STATUSES, true) ? $q['status'] : null,
                'condition' => in_array($q['condition'] ?? null, LibraryCirculation::CONDITIONS, true) ? $q['condition'] : null,
                'q' => is_string($q['q'] ?? null) ? mb_substr(trim($q['q']), 0, 100) : null,
            ], Page::params($q)));
        });

        Route::get('copies/find', function () {
            $code = (string) (Ctx::q()['code'] ?? '');
            $copy = LibraryCirculation::findCopyByCode($code);
            if (! $copy) throw \App\Mz\Support\ApiError::notFound('COPY_NOT_FOUND', 'Copy not found');
            return Http::ok($copy);
        });

        Route::post('copies', function () {
            $b = Ctx::body(Z::object([
                'item_id' => Z::number()->int()->positive(),
                'condition' => Z::enum(LibraryCirculation::CONDITIONS)->optional(),
                'location' => V::optionalText(100),
            ]));
            return Http::created(LibraryCirculation::addCopy(Ctx::actx(), (int) $b['item_id'], $b));
        });

        Route::get('copies/{id}/history', fn () => Http::ok(LibraryCirculation::copyHistory(Ctx::id())));

        Route::post('checkout', function () {
            $b = Ctx::body(Z::object([
                'copy_id' => Z::number()->int()->positive()->optional(),
                'copy_code' => V::optionalText(64),
                'user_id' => Z::number()->int()->positive(),
                'due_on' => V::dateOnly(),
                'condition_out' => Z::enum(LibraryCirculation::CONDITIONS)->optional(),
                'signature' => BorrowSchemas::signature(),
                'notes' => V::optionalText(500),
            ]));
            return Http::created(LibraryCirculation::checkout(Ctx::actx(), $b));
        });

        Route::post('return', function () {
            $b = Ctx::body(Z::object([
                'loan_id' => Z::number()->int()->positive()->optional(),
                'copy_code' => V::optionalText(64),
                'condition_in' => Z::enum(LibraryCirculation::CONDITIONS)->optional(),
                'notes' => V::optionalText(500),
            ]));
            return Http::ok(LibraryCirculation::returnCopy(Ctx::actx(), $b));
        });

        Route::get('loans', function () {
            $q = Ctx::q();
            return Http::page(LibraryCirculation::loans([
                'status' => in_array($q['status'] ?? null, LibraryCirculation::LOAN_STATUSES, true) ? $q['status'] : null,
                'user_id' => ! empty($q['user_id']) ? (int) $q['user_id'] : null,
                'copy_id' => ! empty($q['copy_id']) ? (int) $q['copy_id'] : null,
                'item_id' => ! empty($q['item_id']) ? (int) $q['item_id'] : null,
                'q' => is_string($q['q'] ?? null) ? mb_substr(trim($q['q']), 0, 100) : null,
            ], Page::params($q)));
        });

        Route::get('overdue', fn () => Http::page(LibraryCirculation::overdue(Page::params(Ctx::q()))));

        Route::get('loans/{id}/signature', function () {
            $id = Ctx::id();
            $loan = DB::table('library_loans')->where('id', $id)->first();
            if (! $loan || ! $loan->signature_path) throw \App\Mz\Support\ApiError::notFound('SIGNATURE_NOT_FOUND', 'Signature not found');
            $abs = Storage::privatePath($loan->signature_path);
            if (! is_file($abs)) throw \App\Mz\Support\ApiError::notFound('SIGNATURE_NOT_FOUND', 'Signature file not found on disk');
            return response()->file($abs, ['Content-Type' => 'image/png']);
        });

        Route::get('conflicts', fn () => Http::page(LibraryCirculation::conflicts(Ctx::q(), Page::params(Ctx::q()))));
        Route::post('conflicts/{id}/resolve', function () {
            $b = Ctx::body(Z::object([
                'status' => Z::enum(['resolved', 'dismissed'])->default('resolved'),
                'note' => V::optionalText(500),
            ]));
            return Http::ok(LibraryCirculation::resolveConflict(Ctx::actx(), Ctx::id(), $b['status'] ?? 'resolved', $b['note'] ?? null));
        });
    });
});
