<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Banners and internal pages, with attachments (port of promotionService.js). */
final class Promotions
{
    private const AD_FIELDS = ['kind', 'title', 'short_description', 'starts_at', 'ends_at', 'display_order', 'is_active', 'page_id', 'program_id'];
    private const PAGE_FIELDS = ['title', 'summary', 'content', 'event_date', 'location', 'cta_label', 'cta_action', 'cta_target_id', 'cta_url', 'program_id', 'status'];

    /** What an internal page's button can open. */
    public const CTA_ACTIONS = ['none', 'open_program', 'register_program', 'open_mezmur', 'open_category', 'open_class', 'open_course', 'open_assignment', 'open_page', 'open_library', 'open_url'];
    private const CTA_TABLES = [
        'open_program' => 'programs', 'register_program' => 'programs', 'open_mezmur' => 'mezmurs', 'open_category' => 'categories',
        'open_class' => 'edu_classes', 'open_course' => 'edu_courses', 'open_assignment' => 'edu_assignments', 'open_page' => 'pages',
    ];

    private static function serializeAd(object $a): array
    {
        return [
            'id' => $a->id,
            'kind' => $a->kind,
            'title' => $a->title,
            'short_description' => $a->short_description,
            'image_url' => Storage::url($a->image),
            'starts_at' => $a->starts_at,
            'ends_at' => $a->ends_at,
            'display_order' => $a->display_order,
            'is_active' => (bool) $a->is_active,
            'target' => $a->page_id ? ['type' => 'page', 'id' => $a->page_id] : ($a->program_id ? ['type' => 'program', 'id' => $a->program_id] : null),
            'attachments' => $a->attachments ?? [],
        ];
    }

    private static function serializeAttachment(object $x): array
    {
        return ['id' => $x->id, 'kind' => $x->kind, 'title' => $x->title, 'url' => $x->kind === 'file' ? Storage::url($x->path) : $x->url, 'mime' => $x->mime, 'size' => $x->size];
    }

    private static function withAttachments(array $rows): array
    {
        if (! $rows) return $rows;
        $by = [];
        foreach (DB::table('ad_attachments')->whereIn('ad_id', array_map(fn ($r) => $r->id, $rows))->orderBy('display_order')->orderBy('id')->get() as $x) {
            $by[$x->ad_id][] = self::serializeAttachment($x);
        }
        foreach ($rows as $r) $r->attachments = $by[$r->id] ?? [];
        return $rows;
    }

    private static function loadAd(int $id): array
    {
        $a = DB::table('advertisements')->where('id', $id)->first();
        if (! $a) throw ApiError::notFound('AD_NOT_FOUND', 'Advertisement not found');
        return self::serializeAd(self::withAttachments([$a])[0]);
    }

    public static function addAdFile(array $actx, int $id, UploadedFile $file, ?string $title): array
    {
        self::loadAd($id);
        $saved = Storage::save('document', Storage::FOLDERS['AD_FILES'], $file);
        DB::table('ad_attachments')->insert(['ad_id' => $id, 'kind' => 'file', 'title' => $title ?: (mb_substr((string) $file->getClientOriginalName(), 0, 255) ?: null), 'path' => $saved['path'], 'mime' => $saved['mime'], 'size' => $saved['size']]);
        Audit::log($actx, Audit::AD_UPDATE, 'advertisement', $id, ['attachment' => 'file']);
        return self::loadAd($id);
    }

    public static function addAdLink(array $actx, int $id, array $in): array
    {
        self::loadAd($id);
        DB::table('ad_attachments')->insert(['ad_id' => $id, 'kind' => 'link', 'title' => $in['title'] ?? null, 'url' => $in['url']]);
        Audit::log($actx, Audit::AD_UPDATE, 'advertisement', $id, ['attachment' => 'link']);
        return self::loadAd($id);
    }

    public static function removeAdAttachment(array $actx, int $id, int $attachmentId): array
    {
        $x = DB::table('ad_attachments')->where(['id' => $attachmentId, 'ad_id' => $id])->first();
        if (! $x) throw ApiError::notFound('ATTACHMENT_NOT_FOUND', 'Attachment not found');
        DB::table('ad_attachments')->where('id', $attachmentId)->delete();
        if ($x->path) Storage::remove($x->path);
        Audit::log($actx, Audit::AD_UPDATE, 'advertisement', $id, ['attachment' => 'removed']);
        return self::loadAd($id);
    }

    public static function activeAds(): array
    {
        $now = Dates::sql(Dates::now());
        $rows = DB::table('advertisements as a')->leftJoin('pages as p', 'p.id', '=', 'a.page_id')
            ->where('a.is_active', true)
            ->where(fn ($w) => $w->whereNull('a.starts_at')->orWhere('a.starts_at', '<=', $now))
            ->where(fn ($w) => $w->whereNull('a.ends_at')->orWhere('a.ends_at', '>=', $now))
            ->where(fn ($w) => $w->whereNull('a.page_id')->orWhere('p.status', 'published'))
            ->orderBy('a.display_order')->orderByDesc('a.id')->limit(10)->select('a.*')->get()->all();
        return array_map(fn ($a) => self::serializeAd($a), self::withAttachments($rows));
    }

    public static function listAds(array $filter, array $page): array
    {
        $qb = DB::table('advertisements')->orderBy('display_order')->orderByDesc('id');
        if (! empty($filter['q'])) $qb->where('title', 'like', "%{$filter['q']}%");
        if (isset($filter['active'])) $qb->where('is_active', $filter['active']);
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($a) => self::serializeAd($a), self::withAttachments($res['items'])), 'meta' => $res['meta']];
    }

    private static function assertAdLinks(array $input): void
    {
        if (! empty($input['page_id']) && ! DB::table('pages')->where('id', $input['page_id'])->exists()) throw ApiError::field('page_id', 'PAGE_NOT_FOUND');
        if (! empty($input['program_id']) && ! DB::table('programs')->where('id', $input['program_id'])->exists()) throw ApiError::field('program_id', 'PROGRAM_NOT_FOUND');
        if (! empty($input['starts_at']) && ! empty($input['ends_at']) && Dates::of($input['ends_at']) < Dates::of($input['starts_at'])) throw ApiError::field('ends_at', 'END_BEFORE_START');
    }

    public static function createAd(array $actx, array $input): array
    {
        $id = DB::transaction(function () use ($actx, $input) {
            self::assertAdLinks($input);
            $row = array_intersect_key($input, array_flip(self::AD_FIELDS));
            $newId = DB::table('advertisements')->insertGetId($row + ['created_by' => $actx['auth']->id, 'updated_by' => $actx['auth']->id]);
            Audit::log($actx, Audit::AD_CREATE, 'advertisement', $newId, ['title' => $input['title']], inTrx: true);
            return $newId;
        });
        return self::loadAd($id);
    }

    public static function updateAd(array $actx, int $id, array $input): array
    {
        DB::transaction(function () use ($actx, $id, $input) {
            $a = DB::table('advertisements')->where('id', $id)->lockForUpdate()->first();
            if (! $a) throw ApiError::notFound('AD_NOT_FOUND', 'Advertisement not found');
            self::assertAdLinks(array_merge((array) $a, $input));
            $patch = array_intersect_key($input, array_flip(self::AD_FIELDS));
            DB::table('advertisements')->where('id', $id)->update($patch + ['updated_by' => $actx['auth']->id]);
            Audit::log($actx, Audit::AD_UPDATE, 'advertisement', $id, ['fields' => array_keys($patch)], inTrx: true);
        });
        return self::loadAd($id);
    }

    public static function deleteAd(array $actx, int $id): void
    {
        $a = DB::table('advertisements')->where('id', $id)->first();
        if (! $a) throw ApiError::notFound('AD_NOT_FOUND', 'Advertisement not found');
        $files = DB::table('ad_attachments')->where('ad_id', $id)->whereNotNull('path')->pluck('path')->all();
        DB::transaction(function () use ($actx, $id, $a) {
            DB::table('advertisements')->where('id', $id)->delete();
            Audit::log($actx, Audit::AD_DELETE, 'advertisement', $id, ['title' => $a->title], inTrx: true);
        });
        Storage::remove($a->image);
        foreach ($files as $f) Storage::remove($f);
    }

    public static function setAdImage(array $actx, int $id, UploadedFile $file): array
    {
        $a = DB::table('advertisements')->where('id', $id)->first(['id', 'image']);
        if (! $a) throw ApiError::notFound('AD_NOT_FOUND', 'Advertisement not found');
        $saved = Storage::save('image', Storage::FOLDERS['AD_IMAGES'], $file);
        DB::table('advertisements')->where('id', $id)->update(['image' => $saved['path'], 'updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::AD_UPDATE, 'advertisement', $id, ['image' => 'replaced']);
        Storage::remove($a->image);
        return self::loadAd($id);
    }

    public static function reorderAds(array $actx, array $items): void
    {
        DB::transaction(function () use ($actx, $items) {
            foreach ($items as $it) DB::table('advertisements')->where('id', $it['id'])->update(['display_order' => $it['display_order']]);
            Audit::log($actx, Audit::AD_UPDATE, 'advertisement', null, ['reorder' => count($items)], inTrx: true);
        });
    }

    // ------------------------------------------------------------------ pages
    private static function serializePage(object $p): array
    {
        $images = DB::table('page_images')->where('page_id', $p->id)->orderBy('display_order')->select('id', 'path', 'caption', 'display_order')->get();
        $program = null;
        if ($p->program_id) {
            $program = DB::table('programs')->where('id', $p->program_id)->where('status', '<>', 'draft')->first(['id', 'title', 'starts_at', 'location', 'status']);
        }
        return [
            'id' => $p->id,
            'title' => $p->title,
            'summary' => $p->summary,
            'cover_url' => Storage::url($p->cover_image),
            'content' => $p->content,
            'event_date' => $p->event_date,
            'location' => $p->location,
            'cta' => $p->cta_action !== 'none' ? self::cta($p) : null,
            'program' => $program,
            'images' => $images->map(fn ($i) => ['id' => $i->id, 'url' => Storage::url($i->path), 'caption' => $i->caption, 'display_order' => $i->display_order])->all(),
            'status' => $p->status,
            'updated_at' => $p->updated_at,
        ];
    }

    /** The button: where it leads (+ the class of a course / assignment, which the app opens). */
    private static function cta(object $p): array
    {
        $target = $p->cta_target_id ?? (in_array($p->cta_action, ['open_program', 'register_program'], true) ? $p->program_id : null);
        $out = ['label' => $p->cta_label, 'action' => $p->cta_action, 'target_id' => $target, 'url' => $p->cta_url ?? null, 'target_title' => null];
        if ($target) {
            $row = match ($p->cta_action) {
                'open_course' => DB::table('edu_courses')->where('id', $target)->first(['name as title', 'class_id']),
                'open_assignment' => DB::table('edu_assignments as a')->join('edu_courses as c', 'c.id', '=', 'a.course_id')->where('a.id', $target)->first(['a.title', 'c.class_id', 'a.course_id']),
                'open_class' => DB::table('edu_classes')->where('id', $target)->first(['name as title']),
                'open_category' => DB::table('categories')->where('id', $target)->first(['name as title']),
                'open_mezmur' => DB::table('mezmurs')->where('id', $target)->first(['title']),
                'open_page' => DB::table('pages')->where('id', $target)->first(['title']),
                default => DB::table('programs')->where('id', $target)->first(['title']),
            };
            if ($row) {
                $out['target_title'] = $row->title;
                if (isset($row->class_id)) $out['class_id'] = $row->class_id;
                if (isset($row->course_id)) $out['course_id'] = $row->course_id;
            }
        }
        return $out;
    }

    /** Search what a page button can open: [{id, title, subtitle}] (max 30). */
    public static function linkTargets(string $type, ?string $q): array
    {
        $like = $q ? "%$q%" : null;
        $qb = match ($type) {
            'program' => DB::table('programs')->where('status', '<>', 'draft')->select('id', 'title', DB::raw('NULL as subtitle'))->orderByDesc('starts_at'),
            'mezmur' => DB::table('mezmurs as m')->leftJoin('categories as c', 'c.id', '=', 'm.category_id')->whereNull('m.deleted_at')->select('m.id', 'm.title', 'c.name as subtitle')->orderBy('m.title'),
            'category' => DB::table('categories')->where('is_active', true)->select('id', 'name as title', DB::raw('NULL as subtitle'))->orderBy('name'),
            'class' => DB::table('edu_classes')->where('status', 'active')->select('id', 'name as title', 'term as subtitle')->orderBy('name'),
            'course' => DB::table('edu_courses as co')->join('edu_classes as c', 'c.id', '=', 'co.class_id')->select('co.id', 'co.name as title', 'c.name as subtitle')->orderBy('co.name'),
            'assignment' => DB::table('edu_assignments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')->join('edu_classes as c', 'c.id', '=', 'co.class_id')
                ->select('a.id', 'a.title', DB::raw("CONCAT(co.name, ' · ', c.name) as subtitle"))->orderByDesc('a.id'),
            default => DB::table('pages')->select('id', 'title', 'status as subtitle')->orderByDesc('updated_at'),
        };
        if ($like) {
            $col = ['mezmur' => 'm.title', 'category' => 'name', 'class' => 'name', 'course' => 'co.name', 'assignment' => 'a.title'][$type] ?? 'title';
            $qb->where($col, 'like', $like);
        }
        return $qb->limit(30)->get()->all();
    }

    public static function getPage(int $id, ?AuthContext $auth, bool $admin = false): array
    {
        $p = DB::table('pages')->where('id', $id)->first();
        if (! $p || (! $admin && $p->status !== 'published')) throw ApiError::notFound('PAGE_NOT_FOUND', 'Page not found');
        if (! $admin && $auth?->accountType === 'user') Activity::track($auth->id, Activity::PAGE_VIEW, 'page', $id);
        return self::serializePage($p);
    }

    public static function listPages(array $filter, array $page): array
    {
        $qb = DB::table('pages')->orderByDesc('updated_at')->select('id', 'title', 'summary', 'cover_image', 'status', 'event_date', 'program_id', 'updated_at');
        if (! empty($filter['q'])) $qb->where('title', 'like', "%{$filter['q']}%");
        if (! empty($filter['status'])) $qb->where('status', $filter['status']);
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(function ($p) {
            $p->cover_url = Storage::url($p->cover_image);
            unset($p->cover_image);
            return $p;
        }, $res['items']), 'meta' => $res['meta']];
    }

    private static function assertPageLinks(array $input): void
    {
        if (! empty($input['program_id']) && ! DB::table('programs')->where('id', $input['program_id'])->exists()) throw ApiError::field('program_id', 'PROGRAM_NOT_FOUND');
        if (($input['cta_action'] ?? null) === 'open_url' && empty($input['cta_url'])) throw ApiError::field('cta_url', 'REQUIRED');
        $table = self::CTA_TABLES[$input['cta_action'] ?? ''] ?? null;
        $target = $input['cta_target_id'] ?? ($table === 'programs' ? ($input['program_id'] ?? null) : null);
        if ($table && (! $target || ! DB::table($table)->where('id', $target)->exists())) throw ApiError::field('cta_target_id', 'CTA_TARGET_NOT_FOUND');
    }

    public static function createPage(array $actx, array $input): array
    {
        $id = DB::transaction(function () use ($actx, $input) {
            self::assertPageLinks($input);
            $row = array_intersect_key($input, array_flip(self::PAGE_FIELDS));
            $newId = DB::table('pages')->insertGetId($row + ['created_by' => $actx['auth']->id, 'updated_by' => $actx['auth']->id]);
            Audit::log($actx, Audit::PAGE_CREATE, 'page', $newId, ['title' => $input['title']], inTrx: true);
            return $newId;
        });
        return self::getPage($id, $actx['auth'], true);
    }

    public static function updatePage(array $actx, int $id, array $input): array
    {
        DB::transaction(function () use ($actx, $id, $input) {
            $p = DB::table('pages')->where('id', $id)->lockForUpdate()->first();
            if (! $p) throw ApiError::notFound('PAGE_NOT_FOUND', 'Page not found');
            self::assertPageLinks(array_merge((array) $p, $input));
            $patch = array_intersect_key($input, array_flip(self::PAGE_FIELDS));
            DB::table('pages')->where('id', $id)->update($patch + ['updated_by' => $actx['auth']->id]);
            Audit::log($actx, Audit::PAGE_UPDATE, 'page', $id, ['fields' => array_keys($patch)], inTrx: true);
        });
        return self::getPage($id, $actx['auth'], true);
    }

    public static function deletePage(array $actx, int $id): void
    {
        $p = DB::table('pages')->where('id', $id)->first();
        if (! $p) throw ApiError::notFound('PAGE_NOT_FOUND', 'Page not found');
        $images = DB::table('page_images')->where('page_id', $id)->pluck('path')->all();
        DB::transaction(function () use ($actx, $id, $p) {
            DB::table('advertisements')->where('page_id', $id)->update(['page_id' => null]);
            DB::table('pages')->where('id', $id)->delete();
            Audit::log($actx, Audit::PAGE_DELETE, 'page', $id, ['title' => $p->title], inTrx: true);
        });
        foreach (array_merge([$p->cover_image], $images) as $path) Storage::remove($path);
    }

    public static function setPageCover(array $actx, int $id, UploadedFile $file): array
    {
        $p = DB::table('pages')->where('id', $id)->first(['id', 'cover_image']);
        if (! $p) throw ApiError::notFound('PAGE_NOT_FOUND', 'Page not found');
        $saved = Storage::save('image', Storage::FOLDERS['PAGE_IMAGES'], $file);
        DB::table('pages')->where('id', $id)->update(['cover_image' => $saved['path'], 'updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::PAGE_UPDATE, 'page', $id, ['cover' => 'replaced']);
        Storage::remove($p->cover_image);
        return self::getPage($id, $actx['auth'], true);
    }

    public static function addPageImage(array $actx, int $id, UploadedFile $file, ?string $caption): array
    {
        if (! DB::table('pages')->where('id', $id)->exists()) throw ApiError::notFound('PAGE_NOT_FOUND', 'Page not found');
        $c = DB::table('page_images')->where('page_id', $id)->count();
        if ($c >= 20) throw ApiError::conflict('TOO_MANY_IMAGES', 'A page can have at most 20 images');
        $saved = Storage::save('image', Storage::FOLDERS['PAGE_IMAGES'], $file);
        DB::table('page_images')->insert(['page_id' => $id, 'path' => $saved['path'], 'caption' => $caption ? mb_substr($caption, 0, 255) : null, 'display_order' => $c]);
        Audit::log($actx, Audit::PAGE_UPDATE, 'page', $id, ['image' => 'added']);
        return self::getPage($id, $actx['auth'], true);
    }

    public static function removePageImage(array $actx, int $id, int $imageId): void
    {
        $img = DB::table('page_images')->where(['id' => $imageId, 'page_id' => $id])->first();
        if (! $img) throw ApiError::notFound();
        DB::table('page_images')->where('id', $imageId)->delete();
        Audit::log($actx, Audit::PAGE_UPDATE, 'page', $id, ['image' => 'removed']);
        Storage::remove($img->path);
    }
}
