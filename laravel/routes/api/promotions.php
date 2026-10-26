<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Services\Promotions;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Advertisement banners and internal pages (port of promotions.routes.js).
Route::prefix('advertisements')->group(function () {
    $adSchema = fn () => Z::object([
        'kind' => Z::enum(['advertisement', 'event', 'announcement', 'campaign', 'info'])->optional(),
        'title' => V::text(1, 255),
        'short_description' => V::optionalText(500),
        'starts_at' => V::dateTime()->nullable()->optional(),
        'ends_at' => V::dateTime()->nullable()->optional(),
        'display_order' => Z::number()->int()->min(0)->max(100000)->optional(),
        'is_active' => Z::boolean()->optional(),
        'page_id' => V::id()->nullable()->optional(),
        'program_id' => V::id()->nullable()->optional(),
    ]);
    Route::get('/', fn () => Http::ok(Promotions::activeAds()));
    Route::middleware(['mz', 'mz:all,ads.manage'])->group(function () use ($adSchema) {
        Route::get('admin/list', function () {
            $q = Ctx::q();
            $active = array_key_exists('active', $q) ? Z::parse(V::bool(), $q['active']) : null;
            return Http::page(Promotions::listAds(['q' => $q['q'] ?? null, 'active' => $active], Page::params($q)));
        });
        Route::post('/', fn () => Http::created(Promotions::createAd(Ctx::actx(), Ctx::body($adSchema()))));
        Route::post('reorder', function () {
            $b = Ctx::body(Z::object(['items' => Z::array(Z::object(['id' => V::id(), 'display_order' => Z::number()->int()->min(0)]))->min(1)->max(200)]));
            Promotions::reorderAds(Ctx::actx(), $b['items']);
            return Http::ok(null);
        });
        Route::patch('{id}', function () use ($adSchema) {
            $id = Ctx::id();
            return Http::ok(Promotions::updateAd(Ctx::actx(), $id, Ctx::body($adSchema()->partial()->strict())));
        });
        Route::delete('{id}', function () {
            Promotions::deleteAd(Ctx::actx(), Ctx::id());
            return Http::ok(null);
        });
        Route::post('{id}/attachments', function () {
            $id = Ctx::id();
            $file = Upload::single('document');
            $title = Ctx::input()['title'] ?? null;
            return Http::ok(Promotions::addAdFile(Ctx::actx(), $id, $file, is_string($title) ? mb_substr(trim($title), 0, 255) : null));
        });
        Route::post('{id}/links', function () {
            $id = Ctx::id();
            $b = Ctx::body(Z::object([
                'title' => V::optionalText(255),
                'url' => Z::string()->trim()->max(1000)->url('INVALID_URL')->regex('#^https?://#i', 'INVALID_URL'),
            ]));
            return Http::ok(Promotions::addAdLink(Ctx::actx(), $id, $b));
        });
        Route::delete('{id}/attachments/{attachmentId}', fn () => Http::ok(Promotions::removeAdAttachment(Ctx::actx(), Ctx::id(), Ctx::id('attachmentId'))));
        Route::post('{id}/image', function () {
            $id = Ctx::id();
            return Http::ok(Promotions::setAdImage(Ctx::actx(), $id, Upload::single('image')));
        });
    });
});

Route::prefix('pages')->group(function () {
    $pageSchema = fn () => Z::object([
        'title' => V::text(1, 255),
        'summary' => V::optionalText(500),
        'content' => V::text(1, 100000),
        'event_date' => V::dateTime()->nullable()->optional(),
        'location' => V::optionalText(255),
        'cta_label' => V::optionalText(80),
        'cta_action' => Z::enum(Promotions::CTA_ACTIONS)->optional(),
        'cta_target_id' => V::id()->nullable()->optional(),
        // open_url: an https link opened in the browser.
        'cta_url' => Z::string()->trim()->max(500)->regex('#^https://[^\s<>"]+$#i', 'INVALID_URL')->nullable()->optional(),
        'program_id' => V::id()->nullable()->optional(),
        'status' => Z::enum(['draft', 'published'])->optional(),
    ]);
    $manage = ['mz', 'mz:all,pages.manage'];
    Route::get('admin/list', function () {
        $q = Ctx::q();
        return Http::page(Promotions::listPages(['q' => $q['q'] ?? null, 'status' => $q['status'] ?? null], Page::params($q)));
    })->middleware($manage);
    Route::get('admin/{id}', fn () => Http::ok(Promotions::getPage(Ctx::id(), Ctx::auth(), true)))->middleware($manage);
    // Pickers of the page editor's button: what it can open (search by title).
    Route::get('link-targets', function () {
        $q = Ctx::query(Z::object([
            'type' => Z::enum(['program', 'mezmur', 'category', 'class', 'course', 'assignment', 'page']),
            'q' => Z::string()->trim()->max(100)->optional(),
        ]));
        return Http::ok(Promotions::linkTargets($q['type'], $q['q'] ?? null));
    })->middleware($manage);
    Route::get('{id}', fn () => Http::ok(Promotions::getPage(Ctx::id(), Ctx::authOrNull())))->middleware('mz:optional');
    Route::post('/', fn () => Http::created(Promotions::createPage(Ctx::actx(), Ctx::body($pageSchema()))))->middleware($manage);
    Route::patch('{id}', function () use ($pageSchema) {
        $id = Ctx::id();
        return Http::ok(Promotions::updatePage(Ctx::actx(), $id, Ctx::body($pageSchema()->partial()->strict())));
    })->middleware($manage);
    Route::delete('{id}', function () {
        Promotions::deletePage(Ctx::actx(), Ctx::id());
        return Http::ok(null);
    })->middleware($manage);
    Route::post('{id}/cover', function () {
        $id = Ctx::id();
        return Http::ok(Promotions::setPageCover(Ctx::actx(), $id, Upload::single('image')));
    })->middleware($manage);
    Route::post('{id}/images', function () {
        $id = Ctx::id();
        $file = Upload::single('image');
        $caption = Ctx::input()['caption'] ?? null;
        return Http::ok(Promotions::addPageImage(Ctx::actx(), $id, $file, is_string($caption) ? $caption : null));
    })->middleware($manage);
    Route::delete('{id}/images/{imageId}', function () {
        Promotions::removePageImage(Ctx::actx(), Ctx::id(), Ctx::id('imageId'));
        return Http::ok(null);
    })->middleware($manage);
});
