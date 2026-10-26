<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;

/**
 * Department administrators: MEMBER accounts with admin roles per department (port of
 * departmentAdminService.js). No self-promotion; roles only from an actor who outranks them and
 * holds their permissions; children excluded; every change audited.
 */
final class DepartmentAdmins
{
    private static function department(int $id): object
    {
        $d = DB::table('departments')->where(['id' => $id, 'is_active' => true])->first(['id', 'name', 'name_en']);
        if (! $d) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
        return $d;
    }

    private static function rolePermissions(array $roleIds): array
    {
        if (! $roleIds) return [];
        return DB::table('role_permissions as rp')->join('permissions as p', 'p.id', '=', 'rp.permission_id')->whereIn('rp.role_id', $roleIds)->distinct()->pluck('p.key')->all();
    }

    public static function list(int $departmentId): array
    {
        self::department($departmentId);
        $rows = DB::table('department_admins as da')->join('users as u', 'u.id', '=', 'da.user_id')->join('roles as r', 'r.id', '=', 'da.role_id')
            ->where('da.department_id', $departmentId)->whereNull('u.deleted_at')->orderBy('u.full_name')
            ->select('u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'u.profile_image', 'u.status', 'r.id as role_id', 'r.name as role_name', 'r.is_active as role_active', 'da.created_at')->get();
        $by = [];
        foreach ($rows as $r) {
            $by[$r->user_id] ??= ['user_id' => $r->user_id, 'full_name' => $r->full_name, 'member_id' => MemberIds::format($r->member_no, $r->member_group), 'phone' => $r->phone, 'status' => $r->status, 'roles' => []];
            $by[$r->user_id]['roles'][] = ['id' => $r->role_id, 'name' => $r->role_name, 'is_active' => (bool) $r->role_active];
        }
        return array_values($by);
    }

    public static function all(): array
    {
        return DB::table('department_admins as da')->join('users as u', 'u.id', '=', 'da.user_id')->join('roles as r', 'r.id', '=', 'da.role_id')->join('departments as d', 'd.id', '=', 'da.department_id')
            ->whereNull('u.deleted_at')->orderBy('d.sort_order')->orderBy('u.full_name')
            ->select('d.id as department_id', 'd.name as department_name', 'd.name_en as department_name_en', 'u.id as user_id', 'u.full_name', 'r.id as role_id', 'r.name as role_name')->get()->all();
    }

    public static function ofUser(int $userId): array
    {
        $roles = DB::table('department_admins as da')->join('roles as r', 'r.id', '=', 'da.role_id')->join('departments as d', 'd.id', '=', 'da.department_id')
            ->where('da.user_id', $userId)->select('d.id as department_id', 'd.name as department_name', 'd.name_en as department_name_en', 'r.id as role_id', 'r.name as role_name')->get()->all();
        $extra = DB::table('user_permissions as up')->join('permissions as p', 'p.id', '=', 'up.permission_id')->where('up.user_id', $userId)->pluck('p.key')->all();
        sort($extra);
        $fromRoles = self::rolePermissions(array_map(fn ($r) => $r->role_id, $roles));
        sort($fromRoles);
        return ['roles' => $roles, 'extra_permissions' => $extra, 'role_permissions' => $fromRoles, 'revoked_permissions' => Admins::revokedKeys($userId)];
    }

    /** Replace a member's roles in one department (empty list = no longer an administrator there). */
    public static function setRoles(array $actx, int $departmentId, int $userId, array $roleIds, ?string $reason): array
    {
        /** @var AuthContext $actor */
        $actor = $actx['auth'];
        if ($userId === $actor->id) throw ApiError::forbidden('CANNOT_MODIFY_SELF', 'You cannot change your own administrator roles');
        return DB::transaction(function () use ($actx, $actor, $departmentId, $userId, $roleIds, $reason) {
            self::department($departmentId);
            $user = DB::table('users')->where(['id' => $userId, 'account_type' => 'user'])->whereNull('deleted_at')->first(['id', 'status', 'member_group']);
            if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'Member not found');
            if ($roleIds && $user->member_group === 'children') throw ApiError::conflict('CHILDREN_NO_DEPARTMENT', 'Children cannot be department administrators');
            $roles = $roleIds ? DB::table('roles')->whereIn('id', $roleIds)->where('is_hidden', false)->select('id', 'name', 'level', 'is_active')->get()->all() : [];
            if (count($roles) !== count(array_unique($roleIds))) throw ApiError::field('role_ids', 'ROLE_NOT_FOUND');
            foreach ($roles as $r) {
                if (! $r->is_active) throw ApiError::conflict('ROLE_INACTIVE', 'This role is deactivated');
                if (! $actor->outranks($r->level)) throw ApiError::forbidden('ROLE_NOT_ASSIGNABLE', 'Cannot assign a role at or above your own level');
            }
            $before = DB::table('department_admins')->where(['user_id' => $userId, 'department_id' => $departmentId])->pluck('role_id')->all();
            $changed = array_merge(array_values(array_diff($roleIds, $before)), array_values(array_diff($before, $roleIds)));
            $bad = $actor->ungrantable(self::rolePermissions($changed));
            if ($bad) throw ApiError::forbidden('PERMISSION_NOT_GRANTABLE', 'Cannot grant permissions you do not hold: ' . implode(', ', $bad));
            DB::table('department_admins')->where(['user_id' => $userId, 'department_id' => $departmentId])->delete();
            if ($roleIds) {
                DB::table('department_admins')->insert(array_map(fn ($rid) => ['user_id' => $userId, 'department_id' => $departmentId, 'role_id' => $rid, 'assigned_by' => $actor->id], $roleIds));
            }
            Audit::log($actx, Audit::DEPARTMENT_ADMIN, 'user', $userId, ['department_id' => $departmentId, 'before' => $before, 'after' => $roleIds, 'reason' => $reason], inTrx: true);
            $added = array_values(array_diff($roleIds, $before));
            if ($added || (! $roleIds && $before)) {
                $dept = DB::table('departments')->where('id', $departmentId)->value('name');
                $key = $roleIds ? 'department.admin_assigned' : 'department.admin_removed';
                \App\Mz\Notifications\Notifications::createForUsers([$userId], [
                    'type' => 'department', 'title' => \App\Mz\Support\T::t("$key.title"),
                    'body' => \App\Mz\Support\T::t("$key.body", ['department' => $dept, 'roles' => implode(', ', array_map(fn ($r) => $r->name, $roles))]),
                    'entityType' => 'department', 'entityId' => $departmentId, 'email' => true,
                    'dedupeKey' => fn ($uid) => "dept-admin:$departmentId:$uid:" . \App\Mz\Projects\Pm::stamp(),
                ]);
            }
            return self::ofUser($userId);
        });
    }

    public static function setExtraPermissions(array $actx, int $userId, array $permissions, ?string $reason, ?array $revoked = null): array
    {
        $actor = $actx['auth'];
        if ($userId === $actor->id) throw ApiError::forbidden('CANNOT_MODIFY_SELF', 'You cannot change your own permissions');
        return DB::transaction(function () use ($actx, $actor, $userId, $permissions, $reason, $revoked) {
            if ($revoked !== null) Admins::setRevoked($actx, $userId, $revoked, $reason);
            $user = DB::table('users')->where(['id' => $userId, 'account_type' => 'user'])->whereNull('deleted_at')->first(['id', 'member_group']);
            if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'Member not found');
            if ($permissions && $user->member_group === 'children') throw ApiError::conflict('CHILDREN_NO_DEPARTMENT', 'Children cannot be department administrators');
            $before = DB::table('user_permissions as up')->join('permissions as p', 'p.id', '=', 'up.permission_id')->where('up.user_id', $userId)->pluck('p.key')->all();
            $changed = array_merge(array_values(array_diff($permissions, $before)), array_values(array_diff($before, $permissions)));
            $bad = $actor->ungrantable($changed);
            if ($bad) throw ApiError::forbidden('PERMISSION_NOT_GRANTABLE', 'Cannot grant permissions you do not hold: ' . implode(', ', $bad));
            $ids = $permissions ? DB::table('permissions')->whereIn('key', $permissions)->pluck('id')->all() : [];
            DB::table('user_permissions')->where('user_id', $userId)->delete();
            if ($ids) DB::table('user_permissions')->insert(array_map(fn ($pid) => ['user_id' => $userId, 'permission_id' => $pid, 'granted_by' => $actor->id], $ids));
            Audit::log($actx, Audit::ADMIN_PERMISSIONS_CHANGE, 'user', $userId, ['before' => $before, 'after' => $permissions, 'reason' => $reason], inTrx: true);
            return self::ofUser($userId);
        });
    }

    public static function administers(?AuthContext $auth, int $departmentId): bool
    {
        if (! $auth?->isAdmin) return false;
        if (! $auth->isMemberStaff) return true;
        foreach ($auth->departments as $d) {
            if ((int) $d['id'] === $departmentId) return true;
        }
        return false;
    }
}
