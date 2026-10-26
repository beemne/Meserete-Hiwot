<?php

namespace App\Mz\Auth;

use Illuminate\Support\Facades\DB;

/**
 * Who holds a permission (same rules as AuthContext::load, in bulk): an admin account's active
 * role, a member's active department-admin roles, or a direct grant — minus per-person
 * revocations. Only active, non-deleted accounts. The hidden system authority is left out unless
 * asked for (it is never a visible recipient).
 */
final class Holders
{
    /** @return int[] */
    public static function of(string $key, bool $includeSystem = false): array
    {
        $pid = DB::table('permissions')->where('key', $key)->value('id');
        if (! $pid) return [];
        $fromRole = DB::table('users as u')->join('role_permissions as rp', 'rp.role_id', '=', 'u.role_id')->join('roles as r', 'r.id', '=', 'u.role_id')
            ->where('u.account_type', 'admin')->where('r.is_active', true)->where('r.is_hidden', false)->where('rp.permission_id', $pid)->pluck('u.id')->all();
        $fromDept = DB::table('department_admins as da')->join('role_permissions as rp', 'rp.role_id', '=', 'da.role_id')->join('roles as r', 'r.id', '=', 'da.role_id')
            ->join('users as u', 'u.id', '=', 'da.user_id')->where('u.account_type', 'user')->where('r.is_active', true)->where('rp.permission_id', $pid)->pluck('u.id')->all();
        $direct = DB::table('user_permissions')->where('permission_id', $pid)->pluck('user_id')->all();
        $ids = array_unique(array_map('intval', array_merge($fromRole, $fromDept, $direct)));
        if ($includeSystem) {
            $ids = array_merge($ids, array_map('intval', DB::table('users as u')->join('roles as r', 'r.id', '=', 'u.role_id')->where('r.is_hidden', true)->pluck('u.id')->all()));
        }
        if (! $ids) return [];
        $revoked = array_map('intval', DB::table('user_permission_revocations')->where('permission_id', $pid)->pluck('user_id')->all());
        $active = DB::table('users')->whereIn('id', $ids)->where('status', 'active')->whereNull('deleted_at')->pluck('id')->all();
        return array_values(array_diff(array_map('intval', $active), $revoked));
    }
}
