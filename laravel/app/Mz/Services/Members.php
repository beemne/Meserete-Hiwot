<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use Illuminate\Support\Facades\DB;

/** Member identity for the QR card (port of memberService.js). */
final class Members
{
    /** The member's uuid, created on first use for accounts made before QR ids existed. */
    public static function ensureUuid(int $userId): string
    {
        $u = DB::table('users')->where('id', $userId)->first(['member_uuid']);
        if (! $u) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        if ($u->member_uuid) return $u->member_uuid;
        DB::table('users')->where('id', $userId)->whereNull('member_uuid')->update(['member_uuid' => Crypto::uuid()]);
        return DB::table('users')->where('id', $userId)->value('member_uuid');
    }

    /** QR payload — a URL so any scanner shows something meaningful; the app reads the uuid. */
    public static function qrPayload(string $uuid): string
    {
        return config('mz.public_base_url') . "/u/$uuid";
    }

    public static function departmentsOf(int $userId): array
    {
        return DB::table('user_departments as ud')->join('departments as d', 'd.id', '=', 'ud.department_id')
            ->where('ud.user_id', $userId)->where('d.is_active', true)
            ->select('d.id', 'd.name', 'd.name_en', 'ud.role')->orderBy('d.id')->get()
            ->map(function ($r) {
                $r->is_lead = $r->role === 'leader';
                return $r;
            })->all();
    }

    public static function enrollmentsOf(int $userId): array
    {
        return DB::table('edu_enrollments as e')->join('edu_classes as c', 'c.id', '=', 'e.class_id')
            ->where(['e.user_id' => $userId, 'e.status' => 'active'])
            ->select('c.id', 'c.name', 'c.term', 'e.program')->get()->all();
    }

    public static function card(int $userId): array
    {
        $u = DB::table('users as u')->leftJoin('roles as r', 'r.id', '=', 'u.role_id')
            ->where('u.id', $userId)->whereNull('u.deleted_at')
            ->first(['u.id', 'u.full_name', 'u.phone', 'u.profile_image', 'u.status', 'u.account_type', 'u.member_uuid', 'u.member_no', 'u.member_group', 'u.membership_status', 'r.name as role_name', 'r.is_hidden']);
        if (! $u) throw ApiError::notFound('MEMBER_NOT_FOUND', 'Member not found');
        $uuid = $u->member_uuid ?? self::ensureUuid($u->id);
        return [
            'id' => $u->id,
            'uuid' => $uuid,
            'full_name' => $u->full_name,
            'member_no' => $u->member_no ?? null,
            'member_id' => MemberIds::format($u->member_no, $u->member_group),
            'phone' => $u->phone,
            'avatar_url' => Storage::url($u->profile_image),
            'status' => $u->status,
            'member_group' => $u->member_group,
            'membership_status' => $u->membership_status,
            'role_name' => $u->is_hidden ? null : $u->role_name,
            'departments' => self::departmentsOf($u->id),
            'classes' => self::enrollmentsOf($u->id),
        ];
    }

    /** Who may look members up by QR: admins, and users who teach or take attendance. */
    public static function canScan(AuthContext $auth): bool
    {
        // Permission-based for every administrator (a revoked permission really stops the lookup).
        if ($auth->isAdmin) {
            foreach (['users.view', 'attendance.manage', 'attendance.override', 'borrowing.manage', 'education.manage'] as $k) {
                if ($auth->can($k)) return true;
            }
        }
        if (DB::table('edu_courses')->where('teacher_user_id', $auth->id)->exists()) return true;
        return DB::table('edu_class_staff')->where('user_id', $auth->id)->exists();
    }

    public static function lookup(AuthContext $auth, string $uuid): array
    {
        if (! self::canScan($auth)) throw ApiError::forbidden();
        $u = DB::table('users')->where('member_uuid', $uuid)->whereNull('deleted_at')->first(['id']);
        if (! $u) throw ApiError::notFound('MEMBER_NOT_FOUND', 'Member not found');
        $out = self::card($u->id);
        // Phone numbers only for administrators; teachers and takers see name, photo, classes.
        if (! ($auth->isAdmin && (! $auth->isMemberStaff || $auth->can('users.view')))) {
            unset($out['phone']);
        }
        return $out;
    }

    public static function idByUuid(string $uuid): int
    {
        $u = DB::table('users')->where('member_uuid', $uuid)->whereNull('deleted_at')->first(['id']);
        if (! $u) throw ApiError::notFound('MEMBER_NOT_FOUND', 'Member not found');
        return (int) $u->id;
    }
}
