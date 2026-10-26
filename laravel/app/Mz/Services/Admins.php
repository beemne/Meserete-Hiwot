<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Catalog;
use App\Mz\Auth\Passwords;
use App\Mz\Auth\Tokens;
use App\Mz\Notifications\Telegram;
use App\Mz\Support\ApiError;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Administrator accounts and roles under a strict hierarchy (port of adminService.js): an actor
 * manages only admins / roles strictly below its level, grants only permissions it holds, and never
 * sees hidden roles unless it is the system authority.
 */
final class Admins
{
    private static function visibleRoles(AuthContext $actor, Builder $qb): Builder
    {
        return $actor->isSystem ? $qb : $qb->where('r.is_hidden', false);
    }

    private static function permissionIds(?array $keys): array
    {
        if (! $keys) return [];
        $rows = DB::table('permissions')->whereIn('key', $keys)->select('id', 'key')->get();
        if ($rows->count() !== count(array_unique($keys))) throw ApiError::field('permissions', 'UNKNOWN_PERMISSION');
        return $rows->pluck('id')->all();
    }

    private static function assertGrantable(AuthContext $actor, ?array $keys): void
    {
        $bad = $actor->ungrantable($keys ?? []);
        if ($bad) throw ApiError::forbidden('PERMISSION_NOT_GRANTABLE', 'Cannot grant permissions you do not hold: ' . implode(', ', $bad));
    }

    private static function roleFor(AuthContext $actor, int $roleId): object
    {
        $role = self::visibleRoles($actor, DB::table('roles as r'))->where('r.id', $roleId)->first(['r.*']);
        if (! $role) throw ApiError::field('role_id', 'ROLE_NOT_FOUND');
        if (! $actor->outranks($role->level)) throw ApiError::forbidden('ROLE_NOT_ASSIGNABLE', 'Cannot assign a role at or above your own level');
        return $role;
    }

    private static function adminRow(AuthContext $actor, int $id): object
    {
        $row = self::visibleRoles($actor, DB::table('users as u')->join('roles as r', 'r.id', '=', 'u.role_id'))
            ->where(['u.id' => $id, 'u.account_type' => 'admin'])->whereNull('u.deleted_at')
            ->first(['u.*', 'r.name as role_name', 'r.level as role_level', 'r.slug as role_slug']);
        if (! $row) throw ApiError::notFound('ADMIN_NOT_FOUND', 'Administrator not found');
        return $row;
    }

    private static function serializeAdmin(AuthContext $actor, object $row): array
    {
        $direct = DB::table('user_permissions as up')->join('permissions as p', 'p.id', '=', 'up.permission_id')->where('up.user_id', $row->id)->pluck('p.key')->all();
        $rolePerms = DB::table('role_permissions as rp')->join('permissions as p', 'p.id', '=', 'rp.permission_id')->where('rp.role_id', $row->role_id)->pluck('p.key')->all();
        $revoked = self::revokedKeys((int) $row->id);
        sort($direct);
        sort($rolePerms);
        return Users::toPublic($row) + [
            'role' => ['id' => $row->role_id, 'name' => $row->role_name, 'level' => $row->role_level],
            'role_permissions' => $rolePerms,
            'extra_permissions' => $direct,
            'revoked_permissions' => $revoked,
            'effective_permissions' => array_values(array_diff(array_values(array_unique(array_merge($rolePerms, $direct))), $revoked)),
            'manageable' => $actor->outranks($row->role_level) && $actor->id !== (int) $row->id,
        ];
    }

    /** @return string[] permissions taken away from this one person even though a role grants them */
    public static function revokedKeys(int $userId): array
    {
        $keys = DB::table('user_permission_revocations as r')->join('permissions as p', 'p.id', '=', 'r.permission_id')->where('r.user_id', $userId)->pluck('p.key')->all();
        sort($keys);
        return $keys;
    }

    /**
     * Replace the per-person revocations. Revoking or restoring a permission is like granting it:
     * the actor must hold it (the system authority holds everything).
     */
    public static function setRevoked(array $actx, int $userId, array $keys, ?string $reason = null): void
    {
        $actor = $actx['auth'];
        $before = self::revokedKeys($userId);
        $changed = array_merge(array_values(array_diff($keys, $before)), array_values(array_diff($before, $keys)));
        self::assertGrantable($actor, $changed);
        $pids = self::permissionIds($keys);
        DB::table('user_permission_revocations')->where('user_id', $userId)->delete();
        if ($pids) DB::table('user_permission_revocations')->insert(array_map(fn ($p) => ['user_id' => $userId, 'permission_id' => $p, 'revoked_by' => $actor->id], $pids));
        if ($changed) Audit::log($actx, Audit::ADMIN_PERMISSIONS_CHANGE, 'user', $userId, ['revoked_before' => $before, 'revoked_after' => array_values($keys), 'reason' => $reason], inTrx: true);
    }

    public static function listAdmins(AuthContext $actor, array $filter, array $page): array
    {
        $qb = self::visibleRoles($actor, DB::table('users as u')->join('roles as r', 'r.id', '=', 'u.role_id'))
            ->where('u.account_type', 'admin')->whereNull('u.deleted_at')
            ->select('u.id', 'u.full_name', 'u.phone', 'u.email', 'u.status', 'u.last_login_at', 'u.created_at', 'r.id as role_id', 'r.name as role_name', 'r.level as role_level')
            ->orderByDesc('r.level')->orderBy('u.full_name');
        if (! empty($filter['q'])) $qb->where(fn ($w) => $w->where('u.full_name', 'like', "%{$filter['q']}%")->orWhere('u.phone', 'like', "%{$filter['q']}%"));
        if (! empty($filter['role_id'])) $qb->where('u.role_id', $filter['role_id']);
        if (! empty($filter['status'])) $qb->where('u.status', $filter['status']);
        $res = Page::paginate($qb, $page);
        return [
            'items' => array_map(fn ($a) => [
                'id' => $a->id,
                'full_name' => $a->full_name,
                'phone' => $a->phone,
                'email' => $a->email,
                'status' => $a->status,
                'last_login_at' => $a->last_login_at,
                'created_at' => $a->created_at,
                'role' => ['id' => $a->role_id, 'name' => $a->role_name, 'level' => $a->role_level],
                'manageable' => $actor->outranks($a->role_level) && $actor->id !== (int) $a->id,
            ], $res['items']),
            'meta' => $res['meta'],
        ];
    }

    public static function getAdmin(AuthContext $actor, int $id): array
    {
        return self::serializeAdmin($actor, self::adminRow($actor, $id));
    }

    public static function createAdmin(array $actx, array $input): array
    {
        $actor = $actx['auth'];
        $role = self::roleFor($actor, $input['role_id']);
        self::assertGrantable($actor, $input['permissions'] ?? []);
        $taken = Users::phoneOrEmailTaken($input['phone'] ?? null, $input['email'] ?? null);
        if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Account already exists', $taken);
        $temp = ! empty($input['password']) ? null : UserAdmin::generateTempPassword();
        $hash = Passwords::hash($input['password'] ?? $temp);
        $id = DB::transaction(function () use ($actx, $actor, $input, $role, $hash) {
            $newId = DB::table('users')->insertGetId([
                'full_name' => $input['full_name'],
                'phone' => $input['phone'],
                'email' => $input['email'] ?? null,
                'password_hash' => $hash,
                'account_type' => 'admin',
                'role_id' => $role->id,
                'created_by' => $actor->id,
                'must_change_password' => true,
                'password_changed_at' => DB::raw('NOW()'),
                'member_group' => $input['member_group'] ?? 'youth_adult',
            ]);
            DB::table('user_preferences')->insert(['user_id' => $newId]);
            MemberIds::assign($newId);
            $pids = self::permissionIds($input['permissions'] ?? []);
            if ($pids) DB::table('user_permissions')->insert(array_map(fn ($p) => ['user_id' => $newId, 'permission_id' => $p, 'granted_by' => $actor->id], $pids));
            Audit::log($actx, Audit::ADMIN_CREATE, 'admin', $newId, ['role' => $role->slug, 'permissions' => $input['permissions'] ?? []], inTrx: true);
            return $newId;
        });
        return ['admin' => self::getAdmin($actor, $id), 'temporary_password' => $temp];
    }

    public static function updateAdmin(array $actx, int $id, array $input): array
    {
        $actor = $actx['auth'];
        if ($id === $actor->id && (! empty($input['role_id']) || isset($input['permissions']) || isset($input['revoked_permissions']) || ! empty($input['status']))) {
            throw ApiError::forbidden('CANNOT_MODIFY_SELF', 'You cannot change your own role, permissions or status');
        }
        // Administrators are members too: anyone may set their OWN member group.
        if ($id === $actor->id && ! array_diff(array_keys($input), ['member_group'])) {
            if (! empty($input['member_group'])) {
                DB::table('users')->where('id', $id)->update(['member_group' => $input['member_group']]);
                Audit::log($actx, Audit::ADMIN_UPDATE, 'admin', $id, ['fields' => ['member_group'], 'member_group' => $input['member_group']]);
            }
            return self::getAdmin($actor, $id);
        }
        DB::transaction(function () use ($actx, $actor, $id, $input) {
            $target = self::adminRow($actor, $id);
            if (! $actor->outranks($target->role_level)) throw ApiError::forbidden('ADMIN_NOT_MANAGEABLE', 'Cannot manage an administrator at or above your level');
            $taken = Users::phoneOrEmailTaken($input['phone'] ?? null, $input['email'] ?? null, $id);
            if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Phone or email already in use', $taken);
            $patch = array_intersect_key($input, array_flip(['full_name', 'phone', 'email', 'status', 'member_group']));
            if (! empty($input['role_id']) && $input['role_id'] !== (int) $target->role_id) {
                $role = self::roleFor($actor, $input['role_id']);
                $patch['role_id'] = $role->id;
                Audit::log($actx, Audit::ADMIN_ROLE_CHANGE, 'admin', $id, ['from' => $target->role_slug, 'to' => $role->slug], inTrx: true);
            }
            if ($patch) DB::table('users')->where('id', $id)->update($patch);
            if (($input['status'] ?? null) === 'disabled') {
                DB::table('users')->where('id', $id)->update(['token_version' => DB::raw('token_version + 1')]);
                Tokens::revokeAllForUser($id);
            }
            if (isset($input['permissions'])) {
                self::assertGrantable($actor, $input['permissions']);
                $before = DB::table('user_permissions as up')->join('permissions as p', 'p.id', '=', 'up.permission_id')->where('up.user_id', $id)->pluck('p.key')->all();
                self::assertGrantable($actor, array_values(array_diff($before, $input['permissions'])));
                $pids = self::permissionIds($input['permissions']);
                DB::table('user_permissions')->where('user_id', $id)->delete();
                if ($pids) DB::table('user_permissions')->insert(array_map(fn ($p) => ['user_id' => $id, 'permission_id' => $p, 'granted_by' => $actor->id], $pids));
                Audit::log($actx, Audit::ADMIN_PERMISSIONS_CHANGE, 'admin', $id, ['before' => $before, 'after' => $input['permissions']], inTrx: true);
            }
            if (isset($input['revoked_permissions'])) {
                self::setRevoked($actx, $id, $input['revoked_permissions'], $input['reason'] ?? null);
            }
            Audit::log($actx, Audit::ADMIN_UPDATE, 'admin', $id, ['fields' => array_keys($patch)], inTrx: true);
        });
        return self::getAdmin($actor, $id);
    }

    /**
     * Promote an existing member to administrator (admins.manage, and only to a role below the
     * actor's own level — the system authority / high admin). The person keeps everything a member
     * has (member ID, payments, attendance, borrowing, chat…); only the account type and role change.
     * They sign in again and must set an administrator password (8+ characters) the first time.
     */
    public static function promote(array $actx, int $userId, int $roleId, array $permissions = []): array
    {
        $actor = $actx['auth'];
        if ($userId === $actor->id) throw ApiError::forbidden('CANNOT_MODIFY_SELF', 'You cannot change your own role');
        $role = self::roleFor($actor, $roleId);
        self::assertGrantable($actor, $permissions);
        DB::transaction(function () use ($actx, $actor, $userId, $role, $permissions) {
            $u = DB::table('users')->where('id', $userId)->whereNull('deleted_at')->lockForUpdate()->first(['id', 'account_type', 'status']);
            if (! $u) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
            if ($u->account_type !== 'user') throw ApiError::conflict('ALREADY_ADMIN', 'This person is already an administrator');
            if ($u->status !== 'active') throw ApiError::conflict('USER_NOT_ACTIVE', 'Only an active member can be promoted');
            DB::table('users')->where('id', $userId)->update([
                'account_type' => 'admin', 'role_id' => $role->id, 'can_login' => true,
                'must_change_password' => true, 'token_version' => DB::raw('token_version + 1'),
            ]);
            Tokens::revokeAllForUser($userId);
            $pids = self::permissionIds($permissions);
            DB::table('user_permissions')->where('user_id', $userId)->delete();
            if ($pids) DB::table('user_permissions')->insert(array_map(fn ($p) => ['user_id' => $userId, 'permission_id' => $p, 'granted_by' => $actor->id], $pids));
            Audit::log($actx, Audit::ADMIN_PROMOTE, 'user', $userId, ['role' => $role->slug, 'permissions' => $permissions], inTrx: true);
        });
        \App\Mz\Notifications\Notifications::createForUsers([$userId], [
            'type' => 'system', 'title' => T::t('admin.promoted.title'), 'body' => T::t('admin.promoted.body', ['role' => $role->name]),
            'entityType' => 'user', 'entityId' => $userId, 'email' => true, 'dedupeKey' => fn ($uid) => "admin:promoted:$uid:" . time(),
        ]);
        \App\Mz\Notifications\Notifications::kick();
        return self::getAdmin($actor, $userId);
    }

    /** Return an administrator to a plain member account (same rules as managing that administrator). */
    public static function demote(array $actx, int $id, ?string $reason = null): array
    {
        $actor = $actx['auth'];
        if ($id === $actor->id) throw ApiError::forbidden('CANNOT_MODIFY_SELF', 'You cannot change your own role');
        DB::transaction(function () use ($actx, $actor, $id, $reason) {
            $target = self::adminRow($actor, $id);
            if (! $actor->outranks($target->role_level)) throw ApiError::forbidden('ADMIN_NOT_MANAGEABLE', 'Cannot manage an administrator at or above your level');
            DB::table('users')->where('id', $id)->update(['account_type' => 'user', 'role_id' => null, 'token_version' => DB::raw('token_version + 1')]);
            DB::table('user_permissions')->where('user_id', $id)->delete();
            DB::table('user_permission_revocations')->where('user_id', $id)->delete();
            Tokens::revokeAllForUser($id);
            Audit::log($actx, Audit::ADMIN_DEMOTE, 'user', $id, ['role' => $target->role_slug, 'reason' => $reason], inTrx: true);
        });
        return Users::toPublic(DB::table('users')->where('id', $id)->first());
    }

    public static function resetAdminPassword(array $actx, int $id): array
    {
        $target = self::adminRow($actx['auth'], $id);
        if (! $actx['auth']->outranks($target->role_level)) throw ApiError::forbidden('ADMIN_NOT_MANAGEABLE', 'Cannot manage an administrator at or above your level');
        $temp = UserAdmin::generateTempPassword();
        $hash = Passwords::hash($temp);
        DB::transaction(function () use ($actx, $id, $hash) {
            DB::table('users')->where('id', $id)->update(['password_hash' => $hash, 'must_change_password' => true, 'token_version' => DB::raw('token_version + 1')]);
            Tokens::revokeAllForUser($id);
            Audit::log($actx, Audit::USER_PASSWORD_RESET, 'admin', $id, inTrx: true);
        });
        return ['temporary_password' => $temp, 'sent_via_telegram' => Telegram::sendToUser($id, T::t('telegram.temp.password', ['password' => $temp]))];
    }

    // ------------------------------------------------------------------ roles
    public static function listRoles(AuthContext $actor): array
    {
        $roles = self::visibleRoles($actor, DB::table('roles as r'))->orderByDesc('r.level')->select('r.*')->get()->all();
        $perms = DB::table('role_permissions as rp')->join('permissions as p', 'p.id', '=', 'rp.permission_id')->whereIn('rp.role_id', array_map(fn ($r) => $r->id, $roles) ?: [0])->select('rp.role_id', 'p.key')->get();
        $counts = [];
        foreach (DB::table('users')->whereNotNull('role_id')->whereNull('deleted_at')->groupBy('role_id')->select('role_id', DB::raw('COUNT(*) as n'))->get() as $r) $counts[$r->role_id] = (int) $r->n;
        foreach (DB::table('department_admins')->groupBy('role_id')->select('role_id', DB::raw('COUNT(DISTINCT user_id) as n'))->get() as $r) $counts[$r->role_id] = ($counts[$r->role_id] ?? 0) + (int) $r->n;
        return array_map(function ($r) use ($perms, $counts, $actor) {
            $keys = $perms->where('role_id', $r->id)->pluck('key')->all();
            sort($keys);
            return [
                'id' => $r->id,
                'slug' => $r->slug,
                'name' => $r->name,
                'description' => $r->description,
                'level' => $r->level,
                'is_system' => (bool) $r->is_system,
                'is_active' => (bool) $r->is_active,
                'department_id' => $r->department_id ?? null,
                'permissions' => array_values($keys),
                'assignable' => $actor->outranks($r->level) && (bool) $r->is_active,
                'in_use' => $counts[$r->id] ?? 0,
            ];
        }, $roles);
    }

    private static function findRole(AuthContext $actor, int $id): ?array
    {
        foreach (self::listRoles($actor) as $r) {
            if ($r['id'] === $id) return $r;
        }
        return null;
    }

    public static function createRole(array $actx, array $input): ?array
    {
        $actor = $actx['auth'];
        if (! $actor->outranks($input['level'])) throw ApiError::forbidden('ROLE_LEVEL_TOO_HIGH', 'Role level must be below your own');
        self::assertGrantable($actor, $input['permissions'] ?? []);
        $id = DB::transaction(function () use ($actx, $input) {
            if (DB::table('roles')->where('slug', $input['slug'])->exists()) throw ApiError::conflict('ROLE_EXISTS', 'Role already exists');
            $newId = DB::table('roles')->insertGetId(['slug' => $input['slug'], 'name' => $input['name'], 'description' => $input['description'] ?? null, 'level' => $input['level'], 'is_hidden' => false, 'is_system' => false, 'is_active' => $input['is_active'] ?? true, 'department_id' => $input['department_id'] ?? null]);
            $pids = self::permissionIds($input['permissions'] ?? []);
            if ($pids) DB::table('role_permissions')->insert(array_map(fn ($p) => ['role_id' => $newId, 'permission_id' => $p], $pids));
            Audit::log($actx, Audit::ROLE_CREATE, 'role', $newId, ['slug' => $input['slug'], 'level' => $input['level'], 'permissions' => $input['permissions'] ?? []], inTrx: true);
            return $newId;
        });
        return self::findRole($actor, $id);
    }

    public static function updateRole(array $actx, int $id, array $input): ?array
    {
        $actor = $actx['auth'];
        DB::transaction(function () use ($actx, $actor, $id, $input) {
            $role = self::visibleRoles($actor, DB::table('roles as r'))->where('r.id', $id)->first(['r.*']);
            if (! $role) throw ApiError::notFound('ROLE_NOT_FOUND', 'Role not found');
            if (! $actor->outranks($role->level)) throw ApiError::forbidden('ROLE_NOT_MANAGEABLE', 'Cannot edit a role at or above your level');
            if (isset($input['level']) && ! $actor->outranks($input['level'])) throw ApiError::forbidden('ROLE_LEVEL_TOO_HIGH', 'Role level must be below your own');
            if ($role->is_system && ($input['is_active'] ?? null) === false) throw ApiError::conflict('ROLE_IS_SYSTEM', 'Built-in roles cannot be deactivated');
            $patch = array_intersect_key($input, array_flip(['name', 'description', 'level', 'is_active', 'department_id']));
            if ($patch) DB::table('roles')->where('id', $id)->update($patch);
            if (isset($input['permissions'])) {
                self::assertGrantable($actor, $input['permissions']);
                $before = DB::table('role_permissions as rp')->join('permissions as p', 'p.id', '=', 'rp.permission_id')->where('rp.role_id', $id)->pluck('p.key')->all();
                self::assertGrantable($actor, array_values(array_diff($before, $input['permissions'])));
                $pids = self::permissionIds($input['permissions']);
                DB::table('role_permissions')->where('role_id', $id)->delete();
                if ($pids) DB::table('role_permissions')->insert(array_map(fn ($p) => ['role_id' => $id, 'permission_id' => $p], $pids));
                Audit::log($actx, Audit::ADMIN_PERMISSIONS_CHANGE, 'role', $id, ['before' => $before, 'after' => $input['permissions'], 'reason' => $input['reason'] ?? null], inTrx: true);
            }
            $previous = [];
            foreach (array_keys($patch) as $k) $previous[$k] = $role->{$k};
            Audit::log($actx, Audit::ROLE_UPDATE, 'role', $id, ['fields' => array_keys($patch), 'previous' => (object) $previous, 'next' => (object) $patch, 'reason' => $input['reason'] ?? null], inTrx: true);
        });
        return self::findRole($actor, $id);
    }

    public static function deleteRole(array $actx, int $id): void
    {
        $actor = $actx['auth'];
        DB::transaction(function () use ($actx, $actor, $id) {
            $role = self::visibleRoles($actor, DB::table('roles as r'))->where('r.id', $id)->first(['r.*']);
            if (! $role) throw ApiError::notFound('ROLE_NOT_FOUND', 'Role not found');
            if ($role->is_system) throw ApiError::conflict('ROLE_IS_SYSTEM', 'Built-in roles cannot be deleted');
            if (! $actor->outranks($role->level)) throw ApiError::forbidden('ROLE_NOT_MANAGEABLE', 'Cannot delete a role at or above your level');
            if (DB::table('users')->where('role_id', $id)->whereNull('deleted_at')->exists()) throw ApiError::conflict('ROLE_IN_USE', 'Role is assigned to administrators');
            if (DB::table('department_admins')->where('role_id', $id)->exists()) throw ApiError::conflict('ROLE_IN_USE', 'Role is assigned to department administrators');
            DB::table('roles')->where('id', $id)->delete();
            Audit::log($actx, Audit::ROLE_DELETE, 'role', $id, ['slug' => $role->slug], inTrx: true);
        });
    }

    public static function permissionCatalog(AuthContext $actor): array
    {
        return array_map(fn ($p) => ['key' => $p[0], 'group_key' => $p[1], 'description' => $p[2], 'grantable' => $actor->isSystem || $actor->can($p[0])], Catalog::DEFINITIONS);
    }
}
