<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\V;
use Illuminate\Support\Facades\DB;

/** User lookups and the public user shape (port of repositories/userRepository.js). */
final class Users
{
    /** Columns safe to expose (password_hash / totp_secret_enc are deliberately absent). */
    public const PUBLIC_COLUMNS = [
        'u.id', 'u.full_name', 'u.phone', 'u.email', 'u.profile_image', 'u.status', 'u.account_type', 'u.device_name',
        'u.device_bound_at', 'u.last_login_at', 'u.must_change_password', 'u.created_at', 'u.updated_at', 'u.telegram_username',
        'u.telegram_linked_at', 'u.member_type', 'u.member_group', 'u.can_login', 'u.membership_status', 'u.membership_status_date',
        'u.membership_status_detail', 'u.spiritual_level', 'u.member_no',
    ];

    public static function findByIdentifier(string $identifier): ?object
    {
        $phone = V::normalizePhone($identifier);
        $q = DB::table('users as u')
            ->leftJoin('roles as r', 'r.id', '=', 'u.role_id')
            ->whereNull('u.deleted_at')
            ->select('u.*', 'r.is_hidden as role_hidden', 'r.level as role_level');
        if ($phone) {
            $q->where('u.phone', $phone);
        } else {
            $q->where('u.email', mb_strtolower(trim($identifier)));
        }
        return $q->first();
    }

    public static function findPublicById(int $id): ?object
    {
        return DB::table('users as u')->where('u.id', $id)->whereNull('u.deleted_at')->first(self::PUBLIC_COLUMNS);
    }

    public static function findCredentialsById(int $id): ?object
    {
        return DB::table('users')->where('id', $id)->whereNull('deleted_at')->first();
    }

    public static function phoneOrEmailTaken(?string $phone, ?string $email, ?int $exceptId = null): array
    {
        $errors = [];
        if ($phone) {
            $q = DB::table('users')->where('phone', $phone);
            if ($exceptId) $q->where('id', '<>', $exceptId);
            if ($q->exists()) $errors[] = ['field' => 'phone', 'code' => 'PHONE_TAKEN', 'message' => 'PHONE_TAKEN'];
        }
        if ($email) {
            $q = DB::table('users')->where('email', $email);
            if ($exceptId) $q->where('id', '<>', $exceptId);
            if ($q->exists()) $errors[] = ['field' => 'email', 'code' => 'EMAIL_TAKEN', 'message' => 'EMAIL_TAKEN'];
        }
        return $errors;
    }

    /** Is this device already the trusted device of a different active account? */
    public static function deviceOwnedByOther(string $deviceId, ?int $userId): bool
    {
        $q = DB::table('users')->where(['device_id' => $deviceId, 'account_type' => 'user'])->whereNull('deleted_at');
        if ($userId) $q->where('id', '<>', $userId);
        return $q->exists();
    }

    public static function toPublic(?object $row, ?AuthContext $auth = null): ?array
    {
        if (! $row) {
            return null;
        }
        $out = [
            'id' => $row->id,
            'full_name' => $row->full_name ?? null,
            'member_no' => $row->member_no ?? null,
            'member_id' => MemberIds::format($row->member_no ?? null, $row->member_group ?? null),
            'phone' => $row->phone ?? null,
            'email' => $row->email ?? null,
            'profile_image_url' => Storage::url($row->profile_image ?? null),
            'status' => $row->status ?? null,
            'account_type' => $row->account_type ?? null,
            'device_name' => $row->device_name ?? null,
            'last_login_at' => $row->last_login_at ?? null,
            'must_change_password' => (bool) ($row->must_change_password ?? false),
        ];
        $out += MemberProfile::classificationOf($row);
        $out['created_at'] = $row->created_at ?? null;
        $out['telegram'] = ['linked' => (bool) ($row->telegram_linked_at ?? null), 'username' => $row->telegram_username ?? null];
        $out['module_access'] = Settings::resolveModuleAccess((int) $row->id, $row->member_group ?? null);
        if ($auth?->isAdmin && $auth->id === (int) $row->id) {
            $out['role'] = $auth->isSystem ? null : [
                'id' => $auth->role['id'] ?? null,
                'slug' => $auth->role['slug'] ?? null,
                'name' => $auth->role['name'] ?? null,
                'level' => $auth->role['level'] ?? 0,
            ];
            $out['permissions'] = $auth->permissionList();
            $out['admin_departments'] = $auth->departments;
            $out['is_staff'] = true;
        }
        return $out;
    }
}
