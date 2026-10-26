<?php

use App\Mz\Auth\Audit;
use App\Mz\Http\Ctx;
use App\Mz\Http\Middleware;
use App\Mz\Services\Import;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Admin bulk import (port of import.routes.js). Each kind needs its own permission.
Route::prefix('import')->middleware('mz')->group(function () {
    $kinds = [
        'mezmurs' => ['mezmurs.create', 'mezmurs', 'mezmurs-template.txt', 'text/plain'],
        'categories' => ['categories.manage', 'categories', 'categories-template.csv', 'text/csv'],
        'users' => ['users.create', 'users', 'users-template.csv', 'text/csv'],
    ];
    $kindOf = function (string $kind) use ($kinds): array {
        $k = $kinds[$kind] ?? null;
        if (! $k) throw ApiError::notFound();
        Middleware::requireAll($k[0]);
        return $k;
    };

    // ?format=xlsx (recommended): an Excel workbook with examples and the allowed values; otherwise
    // the plain .csv / .txt template.
    Route::get('templates/{kind}', function (string $kind) use ($kindOf) {
        $k = $kindOf($kind);
        if ((Ctx::q()['format'] ?? null) === 'xlsx') {
            return response(Import::templateXlsx($kind), 200, [
                'Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                'Content-Disposition' => "attachment; filename=\"$kind-template.xlsx\"",
            ]);
        }
        return response("\u{FEFF}" . Import::TEMPLATES[$kind], 200, [
            'Content-Type' => "{$k[3]}; charset=utf-8",
            'Content-Disposition' => "attachment; filename=\"{$k[2]}\"",
        ]);
    });

    Route::post('{kind}', function (string $kind) use ($kindOf) {
        $k = $kindOf($kind);
        $b = Ctx::body(Z::object([
            // Text (csv / tsv pasted from a spreadsheet / txt) or, for xlsx, the file as base64.
            'content' => Z::string()->min(1, 'REQUIRED')->max(8000000, 'TOO_LONG'),
            'format' => Z::enum(Import::FORMATS)->default('auto'),
            'dry_run' => Z::boolean()->default(true),
        ]));
        $out = Import::{$k[1]}(Ctx::actx(), $b['content'], $b['dry_run'], $b['format']);
        if (! $b['dry_run']) {
            Audit::log(Ctx::actx(), Audit::BULK_IMPORT, $kind, null, ['ok' => $out['ok'], 'failed' => $out['failed'], 'skipped' => $out['skipped'] ?? null]);
        }
        return Http::ok($out);
    });
});
