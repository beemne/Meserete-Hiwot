<?php

namespace App\Mz\Auth;

use Illuminate\Support\Facades\DB;

/**
 * The signed-in account: role, effective permissions and departments (port of permissions/resolver.js).
 *
 * Two kinds of administrators:
 *  - admin accounts (account_type 'admin'): one role (users.role_id) + direct grants;
 *  - department administrators: MEMBER accounts given roles per department (department_admins) +
 *    direct grants. Deactivated roles grant nothing. The hidden system authority holds everything.
 *  - a permission revoked for one person (user_permission_revocations) is removed whatever grants it.
 */
final class AuthContext
{
    public int $id;
    public ?string $fullName;
    public string $status;
    public string $accountType;
    public int $tokenVersion;
    public ?string $deviceId;
    public ?string $tokenDeviceId = null;
    public ?string $tokenId = null;
    /** The session (refresh-token family) of the access token, when it carries one. */
    public ?string $tokenSessionId = null;
    public ?int $tokenExpires = null;
    public bool $mustChangePassword = false;
    public bool $isAdmin = false;
    public bool $isSystem = false;
    public bool $isMemberStaff = false;
    /** @var array{id:?int,slug:?string,name:?string,level:int}|null */
    public ?array $role = null;
    public int $level = 0;
    /** @var array<array{id:int,name:string,name_en:?string,roles:array}> */
    public array $departments = [];
    /** @var array<string,true> */
    public array $permissions = [];

    public function isSuperAdmin(): bool
    {
        if ($this->isSystem) {
            return true;
        }
        $slug = $this->role['slug'] ?? null;
        if (in_array($slug, ['superadmin', 'super_admin', 'system_authority', 'high_admin'], true)) {
            return true;
        }
        return $this->isAdmin && ($this->level >= 90 || ($this->role['level'] ?? 0) >= 90);
    }

    public function can(string $key): bool
    {
        if (isset($this->permissions[$key])) {
            return true;
        }
        if ($this->isSuperAdmin()) {
            return true;
        }
        return false;
    }

    public function canAny(array $keys): bool
    {
        if ($this->isSuperAdmin()) {
            return true;
        }
        foreach ($keys as $k) {
            if ($this->can($k)) {
                return true;
            }
        }
        return false;
    }

    public function canAll(array $keys): bool
    {
        if ($this->isSuperAdmin()) {
            return true;
        }
        foreach ($keys as $k) {
            if (! $this->can($k)) {
                return false;
            }
        }
        return true;
    }

    public static function load(int $userId): ?self
    {
        $row = DB::table('users as u')
            ->leftJoin('roles as r', 'r.id', '=', 'u.role_id')
            ->where('u.id', $userId)
            ->whereNull('u.deleted_at')
            ->first([
                'u.id', 'u.full_name', 'u.status', 'u.account_type', 'u.token_version', 'u.device_id', 'u.must_change_password',
                'r.id as role_id', 'r.slug as role_slug', 'r.name as role_name', 'r.level as role_level', 'r.is_hidden as role_hidden', 'r.is_active as role_active',
            ]);
        if (! $row) {
            return null;
        }
        $isAccountAdmin = $row->account_type === 'admin' && $row->role_id !== null;
        $isSystem = $isAccountAdmin && (bool) $row->role_hidden;

        $permissions = [];
        $role = null;
        $departments = [];
        $direct = fn () => DB::table('permissions as p2')->join('user_permissions as up', 'up.permission_id', '=', 'p2.id')->where('up.user_id', $row->id)->pluck('p2.key')->all();
        if ($isSystem) {
            $permissions = Catalog::allKeys();
        } elseif ($isAccountAdmin) {
            $fromRole = DB::table('permissions as p')
                ->join('role_permissions as rp', 'rp.permission_id', '=', 'p.id')
                ->join('roles as rl', 'rl.id', '=', 'rp.role_id')
                ->where('rp.role_id', $row->role_id)
                ->where('rl.is_active', true)
                ->pluck('p.key')->all();
            $permissions = array_merge($fromRole, $direct());
            $role = ['id' => $row->role_id, 'slug' => $row->role_slug, 'name' => $row->role_name, 'level' => (int) $row->role_level];
        } elseif ($row->account_type === 'user') {
            $assigned = DB::table('department_admins as da')
                ->join('roles as rl', 'rl.id', '=', 'da.role_id')
                ->join('departments as d', 'd.id', '=', 'da.department_id')
                ->where('da.user_id', $row->id)
                ->where('rl.is_active', true)
                ->where('d.is_active', true)
                ->select('da.department_id', 'd.name as department_name', 'd.name_en as department_name_en', 'rl.id as role_id', 'rl.slug', 'rl.name', 'rl.level')
                ->get()->all();
            $roleIds = array_values(array_unique(array_map(fn ($a) => $a->role_id, $assigned)));
            $fromRoles = DB::table('permissions as p')
                ->join('role_permissions as rp', 'rp.permission_id', '=', 'p.id')
                ->whereIn('rp.role_id', $roleIds ?: [0])
                ->pluck('p.key')->all();
            $permissions = array_merge($fromRoles, $direct());
            if ($assigned) {
                $sorted = $assigned;
                usort($sorted, fn ($a, $b) => $b->level <=> $a->level);
                $top = $sorted[0];
                $role = ['id' => $top->role_id, 'slug' => $top->slug, 'name' => $top->name, 'level' => (int) $top->level];
            }
            $byDept = [];
            foreach ($assigned as $a) {
                $byDept[$a->department_id] ??= ['id' => $a->department_id, 'name' => $a->department_name, 'name_en' => $a->department_name_en, 'roles' => []];
                $byDept[$a->department_id]['roles'][] = ['id' => $a->role_id, 'name' => $a->name];
            }
            $departments = array_values($byDept);
        }
        if (! $isSystem && $permissions) {
            // A permission reversed for this one person wins over what their roles grant.
            $revoked = DB::table('user_permission_revocations as upr')->join('permissions as p3', 'p3.id', '=', 'upr.permission_id')->where('upr.user_id', $row->id)->pluck('p3.key')->all();
            if ($revoked) $permissions = array_values(array_diff($permissions, $revoked));
        }
        $c = new self();
        $c->permissions = array_fill_keys($permissions, true);
        $isAdmin = $isAccountAdmin || ($row->account_type === 'user' && count($c->permissions) > 0);
        $c->id = (int) $row->id;
        $c->fullName = $row->full_name;
        $c->status = $row->status;
        $c->accountType = $row->account_type;
        $c->tokenVersion = (int) $row->token_version;
        $c->deviceId = $row->device_id;
        $c->mustChangePassword = (bool) $row->must_change_password;
        $c->isAdmin = $isAdmin;
        $c->isSystem = $isSystem;
        $c->isMemberStaff = $isAdmin && ! $isAccountAdmin;
        $c->role = $isAdmin ? ($role ?? ['id' => null, 'slug' => null, 'name' => null, 'level' => 0]) : null;
        $c->level = $isAdmin ? (int) ($role['level'] ?? 0) : 0;
        $c->departments = $departments;
        return $c;
    }

    /** Sorted permission keys. */
    public function permissionList(): array
    {
        if ($this->isSuperAdmin()) {
            return Catalog::allKeys();
        }
        $k = array_keys($this->permissions);
        sort($k);
        return $k;
    }

    /** An actor may manage a target admin / role only when its level is strictly higher. */
    public function outranks(?int $targetLevel): bool
    {
        if ($this->isSystem) {
            return true;
        }
        return $this->isAdmin && $this->level > ($targetLevel ?? 0);
    }

    /** Keys this actor may NOT grant (it may only grant what it holds). */
    public function ungrantable(array $keys): array
    {
        if ($this->isSystem) {
            return [];
        }
        return array_values(array_filter($keys, fn ($k) => ! $this->can($k)));
    }
}
