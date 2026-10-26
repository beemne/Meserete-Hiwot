<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Arbitrary-depth category tree (port of categoryService.js). */
final class Categories
{
    public static function serialize(object $c): array
    {
        $out = [
            'id' => $c->id,
            'parent_id' => $c->parent_id,
            'name' => $c->name,
            'description' => $c->description,
            'image_url' => Storage::url($c->image),
            'icon' => $c->icon,
            'display_order' => $c->display_order,
            'is_active' => (bool) $c->is_active,
            'depth' => $c->depth,
            'is_today' => $c->study_on ? Dates::toDateOnly($c->study_on) === Dates::todayLocal() : false,
        ];
        if (property_exists($c, 'total_mezmur_count')) {
            $out['total_mezmur_count'] = (int) $c->total_mezmur_count;
        }
        if (property_exists($c, 'mezmur_count')) {
            $out['mezmur_count'] = (int) $c->mezmur_count;
        }
        return $out;
    }

    /**
     * Every category with two counts of PUBLISHED Mezmurs: mezmur_count (directly in it) and
     * total_mezmur_count (it and its subcategories). A Mezmur belongs to exactly one category, so
     * each is counted once; for members an inactive subcategory (and what is under it) is not counted.
     */
    private static function allWithCounts(bool $includeInactive): array
    {
        $m = DB::table('mezmurs')->where('status', 'published')->whereNull('deleted_at')->groupBy('category_id')->select('category_id', DB::raw('COUNT(*) as n'));
        $qb = DB::table('categories as c')
            ->leftJoinSub($m, 'm', 'm.category_id', '=', 'c.id')
            ->select('c.*', DB::raw('COALESCE(m.n, 0) as mezmur_count'))
            ->orderBy('c.display_order')->orderBy('c.name');
        if (! $includeInactive) $qb->where('c.is_active', true);
        $rows = $qb->get()->all();
        $byId = [];
        $children = [];
        foreach ($rows as $r) {
            $byId[$r->id] = $r;
            $children[$r->parent_id ?? 0][] = $r->id;
        }
        $total = function (int $id, array $seen = []) use (&$total, $byId, $children): int {
            if (isset($seen[$id])) return 0; // a broken (cyclic) tree never counts twice
            $seen[$id] = true;
            $sum = (int) $byId[$id]->mezmur_count;
            foreach ($children[$id] ?? [] as $k) $sum += $total($k, $seen);
            return $sum;
        };
        foreach ($rows as $r) $r->total_mezmur_count = $total((int) $r->id);
        return $rows;
    }

    /** Full tree; inactive branches are pruned for regular users. */
    public static function tree(bool $includeInactive = false): array
    {
        $rows = array_map(fn ($r) => self::serialize($r), self::allWithCounts($includeInactive));
        $byId = [];
        foreach ($rows as $r) {
            $byId[$r['id']] = $r + ['children' => []];
        }
        // Build bottom-up by reference.
        $refs = [];
        foreach ($byId as $id => &$node) {
            $refs[$id] = &$node;
        }
        unset($node);
        $roots = [];
        foreach ($refs as $id => &$node) {
            $pid = $node['parent_id'];
            if ($pid && isset($refs[$pid])) {
                $refs[$pid]['children'][] = &$node;
            } elseif (! $pid) {
                $roots[] = &$node;
            }
        }
        unset($node);
        return json_decode(json_encode($roots, JSON_UNESCAPED_UNICODE), true);
    }

    public static function ancestors(int $id): array
    {
        $chain = [];
        $cur = DB::table('categories')->where('id', $id)->first(['id', 'parent_id', 'name']);
        $seen = [];
        while ($cur && ! isset($seen[$cur->id])) {
            $seen[$cur->id] = true;
            array_unshift($chain, ['id' => $cur->id, 'name' => $cur->name]);
            $cur = $cur->parent_id ? DB::table('categories')->where('id', $cur->parent_id)->first(['id', 'parent_id', 'name']) : null;
        }
        return $chain;
    }

    /** The category and its subcategories (activeOnly: skipping inactive branches, as members see the tree). */
    public static function descendantIds(int $id, bool $activeOnly = false): array
    {
        $children = [];
        $q = DB::table('categories')->select('id', 'parent_id');
        if ($activeOnly) $q->where('is_active', true);
        foreach ($q->get() as $c) {
            $children[$c->parent_id ?? 0][] = $c->id;
        }
        $out = [];
        $stack = [$id];
        $seen = [];
        while ($stack) {
            $cur = array_pop($stack);
            if (isset($seen[$cur])) continue;
            $seen[$cur] = true;
            $out[] = $cur;
            foreach ($children[$cur] ?? [] as $k) $stack[] = $k;
        }
        return $out;
    }

    public static function detail(int $id, bool $includeInactive = false): array
    {
        $all = self::allWithCounts($includeInactive);
        $c = null;
        foreach ($all as $x) if ((int) $x->id === $id) $c = $x;
        $c ??= DB::table('categories')->where('id', $id)->first();
        if (! $c || (! $includeInactive && ! $c->is_active)) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        $children = array_values(array_map(fn ($x) => self::serialize($x), array_filter($all, fn ($x) => (int) $x->parent_id === $id)));
        return self::serialize($c) + ['breadcrumb' => self::ancestors($id), 'children' => $children];
    }

    private static function assertParent(?int $parentId): int
    {
        if (! $parentId) return 0;
        $parent = DB::table('categories')->where('id', $parentId)->first(['id', 'depth']);
        if (! $parent) throw ApiError::field('parent_id', 'PARENT_NOT_FOUND');
        return (int) $parent->depth + 1;
    }

    public static function assertNoCycle(int $id, ?int $newParentId): void
    {
        if (! $newParentId) return;
        if ($newParentId === $id) throw ApiError::field('parent_id', 'CATEGORY_SELF_PARENT');
        foreach (self::ancestors($newParentId) as $a) {
            if ($a['id'] === $id) throw ApiError::field('parent_id', 'CATEGORY_CYCLE');
        }
    }

    private static function recomputeDepths(int $rootId): void
    {
        $root = DB::table('categories')->where('id', $rootId)->first(['id', 'depth']);
        $queue = [['id' => $root->id, 'depth' => $root->depth]];
        while ($queue) {
            $cur = array_shift($queue);
            $kids = DB::table('categories')->where('parent_id', $cur['id'])->pluck('id')->all();
            if ($kids) {
                DB::table('categories')->whereIn('id', $kids)->update(['depth' => $cur['depth'] + 1]);
                foreach ($kids as $k) $queue[] = ['id' => $k, 'depth' => $cur['depth'] + 1];
            }
        }
    }

    public static function create(array $actx, array $input): array
    {
        $id = DB::transaction(function () use ($actx, $input) {
            $depth = self::assertParent($input['parent_id'] ?? null);
            $newId = DB::table('categories')->insertGetId([
                'parent_id' => ($input['parent_id'] ?? null) ?: null,
                'name' => $input['name'],
                'description' => $input['description'] ?? null,
                'icon' => $input['icon'] ?? null,
                'display_order' => $input['display_order'] ?? 0,
                'is_active' => $input['is_active'] ?? true,
                'depth' => $depth,
                'created_by' => $actx['auth']->id,
                'updated_by' => $actx['auth']->id,
            ]);
            Audit::log($actx, Audit::CATEGORY_CREATE, 'category', $newId, ['name' => $input['name']], inTrx: true);
            return $newId;
        });
        return self::detail($id, true);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        DB::transaction(function () use ($actx, $id, $input) {
            $c = DB::table('categories')->where('id', $id)->lockForUpdate()->first();
            if (! $c) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
            $patch = ['updated_by' => $actx['auth']->id];
            foreach (['name', 'description', 'icon', 'display_order', 'is_active'] as $k) {
                if (array_key_exists($k, $input)) $patch[$k] = $input[$k];
            }
            $moved = false;
            if (array_key_exists('parent_id', $input) && $input['parent_id'] !== $c->parent_id) {
                self::assertNoCycle($id, $input['parent_id']);
                $patch['parent_id'] = $input['parent_id'];
                $patch['depth'] = self::assertParent($input['parent_id']);
                $moved = true;
            }
            DB::table('categories')->where('id', $id)->update($patch);
            if ($moved) self::recomputeDepths($id);
            $meta = ['fields' => array_keys($patch)];
            if ($moved) {
                $meta['from_parent'] = $c->parent_id;
                $meta['to_parent'] = $input['parent_id'];
            }
            Audit::log($actx, $moved ? Audit::CATEGORY_MOVE : Audit::CATEGORY_UPDATE, 'category', $id, $meta, inTrx: true);
        });
        return self::detail($id, true);
    }

    public static function reorder(array $actx, array $items): void
    {
        DB::transaction(function () use ($actx, $items) {
            foreach ($items as $it) {
                DB::table('categories')->where('id', $it['id'])->update(['display_order' => $it['display_order'], 'updated_by' => $actx['auth']->id]);
            }
            Audit::log($actx, Audit::CATEGORY_REORDER, 'category', null, ['count' => count($items)], inTrx: true);
        });
    }

    public static function remove(array $actx, int $id): void
    {
        DB::transaction(function () use ($actx, $id) {
            $c = DB::table('categories')->where('id', $id)->lockForUpdate()->first();
            if (! $c) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
            $child = DB::table('categories')->where('parent_id', $id)->exists();
            $mez = DB::table('mezmurs')->where('category_id', $id)->whereNull('deleted_at')->exists();
            if ($child || $mez) {
                throw ApiError::conflict('CATEGORY_NOT_EMPTY', 'Category has subcategories or Mezmurs — move them or deactivate the category instead');
            }
            DB::table('categories')->where('id', $id)->delete();
            Audit::log($actx, Audit::CATEGORY_DELETE, 'category', $id, ['name' => $c->name], inTrx: true);
            if ($c->image) Storage::remove($c->image);
        });
    }

    public static function setImage(array $actx, int $id, UploadedFile $file): array
    {
        $c = DB::table('categories')->where('id', $id)->first(['id', 'image']);
        if (! $c) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        $saved = Storage::save('image', Storage::FOLDERS['CATEGORY_IMAGES'], $file);
        DB::table('categories')->where('id', $id)->update(['image' => $saved['path'], 'updated_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::CATEGORY_UPDATE, 'category', $id, ['image' => 'replaced']);
        Storage::remove($c->image);
        return self::detail($id, true);
    }

    public static function removeImage(array $actx, int $id): void
    {
        $c = DB::table('categories')->where('id', $id)->first(['id', 'image']);
        if (! $c) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        DB::table('categories')->where('id', $id)->update(['image' => null, 'updated_by' => $actx['auth']->id]);
        Storage::remove($c->image);
    }

    public static function setToday(array $actx, int $id, bool $today): void
    {
        $n = DB::table('categories')->where('id', $id)->update(['study_on' => $today ? Dates::todayLocal() : null, 'updated_by' => $actx['auth']->id]);
        if (! $n) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
        Audit::log($actx, Audit::CATEGORY_UPDATE, 'category', $id, ['today' => $today]);
    }

    public static function todayList(): array
    {
        $today = Dates::todayLocal();
        return array_values(array_map(fn ($c) => self::serialize($c), array_filter(self::allWithCounts(false), fn ($c) => $c->study_on && Dates::toDateOnly($c->study_on) === $today)));
    }
}
