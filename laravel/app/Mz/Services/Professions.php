<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;

/**
 * Categorized and searchable profession catalogue.
 */
final class Professions
{
    /**
     * List all professions.
     * Members and registration see only active professions.
     * Administrators can view both active and inactive.
     */
    public static function list(?bool $activeOnly = true, ?string $category = null): array
    {
        $qb = DB::table('professions')->orderBy('sort_order')->orderBy('name');
        if ($activeOnly) {
            $qb->where('is_active', true);
        }
        if ($category) {
            $qb->where('category', $category);
        }
        $items = $qb->get()->all();

        // Also group by category for client convenience
        $grouped = [];
        foreach ($items as $item) {
            $grouped[$item->category][] = $item;
        }

        return [
            'items' => $items,
            'grouped' => $grouped,
            'categories' => array_keys($grouped),
        ];
    }

    /**
     * List all unique profession categories.
     */
    public static function categories(): array
    {
        return DB::table('professions')->distinct()->orderBy('category')->pluck('category')->all();
    }

    /**
     * Assert the caller is authorized to manage professions.
     */
    public static function assertCanManage(AuthContext $auth): void
    {
        if (! $auth->isSystem && ! $auth->can('users.manage') && ! $auth->can('settings.manage') && ! ($auth->isAdmin && $auth->level >= 50)) {
            throw ApiError::forbidden('PROFESSION_MANAGE_UNAUTHORIZED', 'Only authorized administrators can manage professions.');
        }
    }

    /**
     * Create a new profession.
     */
    public static function create(array $actx, array $data): array
    {
        self::assertCanManage($actx['auth']);

        $category = trim((string) ($data['category'] ?? ''));
        $name = trim((string) ($data['name'] ?? ''));
        if (empty($category)) throw ApiError::field('category', 'REQUIRED');
        if (empty($name)) throw ApiError::field('name', 'REQUIRED');

        $exists = DB::table('professions')->where(['category' => $category, 'name' => $name])->exists();
        if ($exists) {
            throw ApiError::conflict('PROFESSION_EXISTS', 'A profession with this name in this category already exists.');
        }

        $sortOrder = (int) ($data['sort_order'] ?? (DB::table('professions')->max('sort_order') + 1));
        $id = DB::table('professions')->insertGetId([
            'category' => $category,
            'name' => $name,
            'is_active' => (bool) ($data['is_active'] ?? true),
            'sort_order' => $sortOrder,
            'created_at' => DB::raw('NOW()'),
            'updated_at' => DB::raw('NOW()'),
        ]);

        Audit::log($actx, Audit::SETTINGS_UPDATE, 'profession', $id, ['action' => 'create', 'category' => $category, 'name' => $name]);
        return (array) DB::table('professions')->where('id', $id)->first();
    }

    /**
     * Update an existing profession.
     */
    public static function update(array $actx, int $id, array $data): array
    {
        self::assertCanManage($actx['auth']);

        $current = DB::table('professions')->where('id', $id)->first();
        if (! $current) throw ApiError::notFound('PROFESSION_NOT_FOUND', 'Profession not found');

        $patch = [];
        if (array_key_exists('category', $data)) {
            $cat = trim((string) $data['category']);
            if (empty($cat)) throw ApiError::field('category', 'REQUIRED');
            $patch['category'] = $cat;
        }
        if (array_key_exists('name', $data)) {
            $nm = trim((string) $data['name']);
            if (empty($nm)) throw ApiError::field('name', 'REQUIRED');
            $patch['name'] = $nm;
        }
        if (array_key_exists('is_active', $data)) {
            $patch['is_active'] = (bool) $data['is_active'];
        }
        if (array_key_exists('sort_order', $data)) {
            $patch['sort_order'] = (int) $data['sort_order'];
        }

        if ($patch) {
            $patch['updated_at'] = DB::raw('NOW()');
            DB::table('professions')->where('id', $id)->update($patch);
            Audit::log($actx, Audit::SETTINGS_UPDATE, 'profession', $id, ['action' => 'update', 'patch' => $patch]);
        }

        return (array) DB::table('professions')->where('id', $id)->first();
    }

    /**
     * Deactivate a profession (soft deactivation preserves existing records).
     */
    public static function deactivate(array $actx, int $id): array
    {
        return self::update($actx, $id, ['is_active' => false]);
    }

    /**
     * Reactivate a profession.
     */
    public static function reactivate(array $actx, int $id): array
    {
        return self::update($actx, $id, ['is_active' => true]);
    }

    /**
     * Delete or soft-deactivate a profession.
     * If existing user records reference it, deactivates instead of deleting to protect data integrity.
     */
    public static function delete(array $actx, int $id): array
    {
        self::assertCanManage($actx['auth']);

        $current = DB::table('professions')->where('id', $id)->first();
        if (! $current) throw ApiError::notFound('PROFESSION_NOT_FOUND', 'Profession not found');

        $inUse = DB::table('member_profiles')->where('profession_id', $id)->exists();
        if ($inUse) {
            // Soft-deactivate to preserve existing users' records
            DB::table('professions')->where('id', $id)->update(['is_active' => false, 'updated_at' => DB::raw('NOW()')]);
            Audit::log($actx, Audit::SETTINGS_UPDATE, 'profession', $id, ['action' => 'deactivate_in_use']);
            return ['id' => $id, 'deleted' => false, 'deactivated' => true, 'message' => 'Profession is assigned to existing members and has been deactivated.'];
        }

        DB::table('professions')->where('id', $id)->delete();
        Audit::log($actx, Audit::SETTINGS_UPDATE, 'profession', $id, ['action' => 'delete']);
        return ['id' => $id, 'deleted' => true, 'deactivated' => false];
    }
}
