<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;

/**
 * Member types (groups). ሕጻናት / ወጣቶች እና አዋቂዎች / ባለትዳሮች are built in (their keys carry rules:
 * children pay nothing and have no departments); administrators add others — distance members,
 * a choir group… — which every program, attendance roster, filter and member form then offers.
 * A program aimed at some groups expects only their members; nobody else is ever counted absent.
 */
final class MemberGroups
{
    public const BUILT_IN = ['children', 'youth_adult', 'married', 'distance_members'];

    private static ?array $cache = null;

    /** @return array<string, object> key => row, in display order */
    private static function rows(): array
    {
        if (self::$cache === null) {
            self::$cache = [];
            foreach (DB::table('member_groups')->orderBy('sort_order')->orderBy('name')->get() as $g) self::$cache[$g->key] = $g;
            if (! isset(self::$cache['distance_members'])) {
                try {
                    DB::table('member_groups')->insertOrIgnore([
                        'key' => 'distance_members',
                        'name' => 'የሩቅ አባላት',
                        'name_en' => 'Distance Members',
                        'sort_order' => 4,
                        'built_in' => 1,
                        'is_active' => 1,
                    ]);
                    self::$cache = [];
                    foreach (DB::table('member_groups')->orderBy('sort_order')->orderBy('name')->get() as $g) self::$cache[$g->key] = $g;
                } catch (\Throwable) {}
            }
        }
        return self::$cache;
    }

    public static function forget(): void
    {
        self::$cache = null;
    }

    /** Keys of the groups (active only, or every one incl. switched-off ones). */
    public static function keys(bool $activeOnly = false): array
    {
        $out = [];
        foreach (self::rows() as $k => $g) {
            if (! $activeOnly || $g->is_active) $out[] = $k;
        }
        return $out ?: self::BUILT_IN;
    }

    public static function exists(?string $key, bool $activeOnly = false): bool
    {
        return $key !== null && in_array($key, self::keys($activeOnly), true);
    }

    public static function name(?string $key, string $lang = 'am'): ?string
    {
        $g = self::rows()[$key ?? ''] ?? null;
        if (! $g) return $key;
        return $lang === 'en' ? ($g->name_en ?: $g->name) : $g->name;
    }

    public static function serialize(object $g, ?int $members = null): array
    {
        $out = [
            'key' => $g->key, 'name' => $g->name, 'name_en' => $g->name_en, 'description' => $g->description,
            'sort_order' => (int) $g->sort_order, 'is_active' => (bool) $g->is_active, 'built_in' => (bool) $g->built_in,
        ];
        if ($members !== null) $out['member_count'] = $members;
        return $out;
    }

    public static function list(bool $includeInactive = false, bool $withCounts = false): array
    {
        $counts = [];
        if ($withCounts) {
            foreach (DB::table('users')->whereNull('deleted_at')->whereIn('account_type', ['user', 'admin'])->groupBy('member_group')->selectRaw('member_group, COUNT(*) as c')->get() as $r) {
                $counts[$r->member_group] = (int) $r->c;
            }
        }
        $out = [];
        foreach (self::rows() as $g) {
            if (! $includeInactive && ! $g->is_active) continue;
            $out[] = self::serialize($g, $withCounts ? ($counts[$g->key] ?? 0) : null);
        }
        return $out;
    }

    /** A readable, unique key from the name ("Distance members" → distance_members); "g_<n>" for Amharic-only names. */
    private static function keyFor(string $name, ?string $nameEn): string
    {
        $base = strtolower(trim(preg_replace('/[^A-Za-z0-9]+/', '_', (string) ($nameEn ?: $name)), '_'));
        $base = substr($base, 0, 32) ?: 'g';
        if ($base === 'g' || is_numeric($base[0])) $base = 'g_' . $base;
        $key = $base;
        for ($i = 2; DB::table('member_groups')->where('key', $key)->exists(); $i++) $key = substr($base, 0, 32) . "_$i";
        return $key;
    }

    public static function create(array $actx, array $in): array
    {
        $key = self::keyFor($in['name'], $in['name_en'] ?? null);
        DB::table('member_groups')->insert([
            'key' => $key, 'name' => $in['name'], 'name_en' => $in['name_en'] ?? null, 'description' => $in['description'] ?? null,
            'sort_order' => $in['sort_order'] ?? ((int) DB::table('member_groups')->max('sort_order') + 1),
            'is_active' => $in['is_active'] ?? true, 'built_in' => false, 'created_by' => $actx['auth']->id,
        ]);
        self::forget();
        Audit::log($actx, Audit::SETTINGS_UPDATE, 'member_group', null, ['key' => $key, 'created' => $in['name']]);
        return self::serialize(DB::table('member_groups')->where('key', $key)->first(), 0);
    }

    public static function update(array $actx, string $key, array $in): array
    {
        $g = DB::table('member_groups')->where('key', $key)->first();
        if (! $g) throw ApiError::notFound('MEMBER_GROUP_NOT_FOUND', 'Member type not found');
        // Built-in types can be renamed and reordered but never switched off (their rules depend on them).
        if ($g->built_in && array_key_exists('is_active', $in) && ! $in['is_active']) throw ApiError::conflict('MEMBER_GROUP_BUILT_IN', 'Built-in member types cannot be switched off');
        $patch = array_intersect_key($in, array_flip(['name', 'name_en', 'description', 'sort_order', 'is_active']));
        if ($patch) DB::table('member_groups')->where('key', $key)->update($patch);
        self::forget();
        Audit::log($actx, Audit::SETTINGS_UPDATE, 'member_group', null, ['key' => $key, 'fields' => array_keys($patch)]);
        return self::serialize(DB::table('member_groups')->where('key', $key)->first());
    }

    /** Only an unused, administrator-created type can be deleted (otherwise switch it off). */
    public static function remove(array $actx, string $key): void
    {
        $g = DB::table('member_groups')->where('key', $key)->first();
        if (! $g) throw ApiError::notFound('MEMBER_GROUP_NOT_FOUND', 'Member type not found');
        if ($g->built_in) throw ApiError::conflict('MEMBER_GROUP_BUILT_IN', 'Built-in member types cannot be deleted');
        $used = DB::table('users')->where('member_group', $key)->exists()
            || DB::table('programs')->whereRaw('FIND_IN_SET(?, member_groups)', [$key])->exists();
        if ($used) throw ApiError::conflict('MEMBER_GROUP_IN_USE', 'Members or programs use this member type; switch it off instead');
        DB::table('member_groups')->where('key', $key)->delete();
        self::forget();
        Audit::log($actx, Audit::SETTINGS_UPDATE, 'member_group', null, ['key' => $key, 'deleted' => true]);
    }
}
