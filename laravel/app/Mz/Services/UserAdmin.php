<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\Passwords;
use App\Mz\Auth\Tokens;
use App\Mz\Notifications\Notifications;
use App\Mz\Notifications\Telegram;
use App\Mz\Support\ApiError;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/** Administration of regular member accounts (port of userAdminService.js). */
final class UserAdmin
{
    private const LIST_COLUMNS = [
        'u.id', 'u.account_type', 'u.full_name', 'u.phone', 'u.email', 'u.profile_image', 'u.status', 'u.device_name', 'u.device_bound_at',
        'u.last_login_at', 'u.created_at', 'u.telegram_username', 'u.telegram_linked_at', 'u.member_type', 'u.member_group',
        'u.can_login', 'u.membership_status', 'u.membership_status_date', 'u.membership_status_detail', 'u.spiritual_level', 'u.member_no',
    ];

    /** A temporary 6-digit PIN (the member sets their own at the first sign-in). */
    public static function generateTempPassword(): string
    {
        return (string) random_int(100000, 999999);
    }

    private static function row(int $id): object
    {
        // Administrators are members too (not the hidden system authority).
        $row = MemberIds::membersAndAdmins(DB::table('users'))->where('id', $id)->whereNull('deleted_at')->first();
        if (! $row) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        return $row;
    }

    /**
     * The person a write is about. An administrator's member account is changed through these
     * member tools only by someone who outranks them (same rule as the administrator screens).
     */
    private static function rowForWrite(array $actx, int $id): object
    {
        $row = self::row($id);
        if ($row->account_type === 'admin') {
            $actor = $actx['auth'];
            $level = (int) DB::table('roles')->where('id', $row->role_id)->value('level');
            if ($actor->id === (int) $row->id || ! $actor->outranks($level)) {
                throw ApiError::forbidden('ADMIN_NOT_MANAGEABLE', 'Cannot manage an administrator at or above your level');
            }
        }
        return $row;
    }

    private static function listItem(object $r): array
    {
        return Users::toPublic($r) + ['has_device' => (bool) ($r->device_bound_at ?? null)];
    }

    public static function list(array $filter, array $page): array
    {
        $qb = Targeting::query($filter)->select(self::LIST_COLUMNS);
        if (array_key_exists('can_login', $filter)) $qb->where('u.can_login', $filter['can_login']);
        $byName = ($filter['sort'] ?? null) === 'name';
        $qb->orderBy($byName ? 'u.full_name' : 'u.created_at', $byName ? 'asc' : 'desc');
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($r) => self::listItem($r), $res['items']), 'meta' => $res['meta']];
    }

    public static function detail(int $id): array
    {
        $row = self::row($id);
        return self::listItem($row) + ['profile' => MemberProfile::get($id), 'departments' => Departments::departmentsOf($id)];
    }

    public static function create(array $actx, array $input): array
    {
        $cls = MemberProfile::classification($input);
        $canLogin = $cls['can_login'] ?? true;
        if ($canLogin && empty($input['phone'])) throw ApiError::field('phone', 'REQUIRED');
        $taken = Users::phoneOrEmailTaken($input['phone'] ?? null, $input['email'] ?? null);
        if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Account already exists', $taken);
        $temp = (! empty($input['password']) || ! $canLogin) ? null : self::generateTempPassword();
        $hash = Passwords::hash($input['password'] ?? $temp ?? bin2hex(random_bytes(24)));
        $id = DB::transaction(function () use ($actx, $input, $cls, $temp, $hash) {
            $newId = DB::table('users')->insertGetId(array_merge([
                'full_name' => $input['full_name'],
                'phone' => $input['phone'] ?? null,
                'email' => $input['email'] ?? null,
                'password_hash' => $hash,
                'account_type' => 'user',
                'created_by' => $actx['auth']->id,
                'must_change_password' => (bool) $temp,
                'password_changed_at' => DB::raw('NOW()'),
            ], $cls));
            DB::table('user_preferences')->insert(['user_id' => $newId]);
            MemberIds::assign($newId);
            MemberProfile::save($newId, $input['profile'] ?? null);
            Audit::log($actx, Audit::USER_CREATE, 'user', $newId, inTrx: true);
            return $newId;
        });
        return ['user' => self::detail($id), 'temporary_password' => $temp];
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $current = self::rowForWrite($actx, $id);
        $taken = Users::phoneOrEmailTaken($input['phone'] ?? null, $input['email'] ?? null, $id);
        if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Phone or email already in use', $taken);
        $patch = MemberProfile::classification($input, $current);
        foreach (['full_name', 'phone', 'email'] as $k) {
            if (array_key_exists($k, $input)) $patch[$k] = $input[$k];
        }
        $canLogin = $patch['can_login'] ?? (bool) $current->can_login;
        if ($canLogin && ! ($patch['phone'] ?? $current->phone)) throw ApiError::field('phone', 'REQUIRED');
        $temp = null;
        DB::transaction(function () use ($actx, $id, $input, $current, &$patch, &$temp) {
            if (($patch['can_login'] ?? null) === true && ! $current->can_login) {
                $temp = self::generateTempPassword();
                $patch['password_hash'] = Passwords::hash($temp);
                $patch['must_change_password'] = true;
            }
            // Field-by-field history (old → new) before anything is overwritten.
            $diff = ProfileChanges::diffForUpdate($current, $input);
            if ($patch) DB::table('users')->where('id', $id)->update($patch);
            if (($patch['can_login'] ?? null) === false && $current->can_login) self::invalidateSessions($id);
            MemberProfile::save($id, $input['profile'] ?? null);
            ProfileChanges::recordHistory($id, $diff, 'admin', $actx['auth']->id);
            if (($patch['member_group'] ?? null) === 'children') DB::table('user_departments')->where('user_id', $id)->delete();
            $fields = array_values(array_filter(array_keys($patch), fn ($k) => $k !== 'password_hash'));
            if (isset($input['profile'])) $fields[] = 'profile';
            Audit::log($actx, Audit::USER_UPDATE, 'user', $id, ['fields' => $fields], inTrx: true);
        });
        Choir::scheduleEligibility([$id]);
        $out = self::detail($id);
        return $temp ? $out + ['temporary_password' => $temp] : $out;
    }

    private static function invalidateSessions(int $id): void
    {
        DB::table('users')->where('id', $id)->update(['token_version' => DB::raw('token_version + 1')]);
        Tokens::revokeAllForUser($id);
    }

    public static function setStatus(array $actx, int $id, string $status): array
    {
        self::rowForWrite($actx, $id);
        $before = DB::table('users')->where('id', $id)->value('status');
        DB::transaction(function () use ($actx, $id, $status) {
            DB::table('users')->where('id', $id)->update(['status' => $status]);
            if ($status === 'disabled') self::invalidateSessions($id);
            Audit::log($actx, $status === 'disabled' ? Audit::USER_DISABLE : Audit::USER_ENABLE, 'user', $id, inTrx: true);
        });
        // Approving / rejecting a registration, or disabling / re-enabling an account: the member is told (also by email).
        $event = match (true) {
            $before === 'pending' && $status === 'active' => 'approved',
            $before === 'pending' && $status === 'disabled' => 'rejected',
            $before !== 'disabled' && $status === 'disabled' => 'disabled',
            $before === 'disabled' && $status === 'active' => 'enabled',
            default => null,
        };
        if ($event) {
            Notifications::createForUsers([$id], [
                'type' => 'system', 'title' => T::t("account.$event.title"), 'body' => T::t("account.$event.body"),
                'entityType' => 'user', 'entityId' => $id, 'email' => true, 'sentBy' => $actx['auth']->id,
                'dedupeKey' => fn ($uid) => "account:$id:$event:" . \App\Mz\Projects\Pm::stamp(),
            ]);
        }
        return self::detail($id);
    }

    public static function softDelete(array $actx, int $id): void
    {
        self::rowForWrite($actx, $id);
        // Deleting a registration that was never approved is a rejection: the person is told by email.
        if (DB::table('users')->where('id', $id)->value('status') === 'pending') {
            Notifications::createForUsers([$id], [
                'type' => 'system', 'title' => T::t('account.rejected.title'), 'body' => T::t('account.rejected.body'),
                'entityType' => 'user', 'entityId' => $id, 'email' => true, 'dedupeKey' => fn ($uid) => "account:$id:rejected:deleted",
            ]);
        }
        DB::transaction(function () use ($actx, $id) {
            DB::table('users')->where('id', $id)->update(['status' => 'disabled', 'deleted_at' => DB::raw('NOW()'), 'device_id' => null]);
            self::invalidateSessions($id);
            DB::table('fcm_tokens')->where('user_id', $id)->update(['invalidated_at' => DB::raw('NOW()')]);
            Audit::log($actx, Audit::USER_DELETE, 'user', $id, inTrx: true);
        });
    }

    /** Release the trusted device; every token of the old device stops working. */
    public static function resetDevice(array $actx, int $id, ?string $reason = null): array
    {
        self::rowForWrite($actx, $id);
        DB::transaction(function () use ($actx, $id, $reason) {
            $u = DB::table('users')->where('id', $id)->whereIn('account_type', ['user', 'admin'])->whereNull('deleted_at')->lockForUpdate()->first();
            if (! $u) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
            DB::table('device_history')->insert(['user_id' => $id, 'device_id' => $u->device_id, 'device_name' => $u->device_name, 'event' => 'reset', 'actor_id' => $actx['auth']->id, 'ip' => $actx['ip'] ?? null]);
            DB::table('users')->where('id', $id)->update(['device_id' => null, 'device_name' => null, 'device_bound_at' => null]);
            self::invalidateSessions($id);
            DB::table('fcm_tokens')->where('user_id', $id)->update(['invalidated_at' => DB::raw('NOW()')]);
            Audit::log($actx, Audit::DEVICE_RESET, 'user', $id, ['previous_device' => $u->device_name, 'reason' => $reason ?: null], inTrx: true);
            Notifications::createForUsers([$id], ['type' => 'system', 'title' => T::t('device.reset.title'), 'body' => T::t('device.reset.body')]);
        });
        Notifications::kick();
        return self::detail($id);
    }

    public static function forceLogout(array $actx, int $id): void
    {
        self::rowForWrite($actx, $id);
        DB::transaction(function () use ($actx, $id) {
            $u = self::row($id);
            self::invalidateSessions($id);
            DB::table('device_history')->insert(['user_id' => $id, 'device_id' => $u->device_id, 'device_name' => $u->device_name, 'event' => 'force_logout', 'actor_id' => $actx['auth']->id, 'ip' => $actx['ip'] ?? null]);
            Audit::log($actx, Audit::FORCE_LOGOUT, 'user', $id, inTrx: true);
        });
    }

    public static function resetPassword(array $actx, int $id): array
    {
        self::rowForWrite($actx, $id);
        $temp = self::generateTempPassword();
        $hash = Passwords::hash($temp);
        DB::transaction(function () use ($actx, $id, $hash) {
            DB::table('users')->where('id', $id)->update(['password_hash' => $hash, 'must_change_password' => true, 'failed_login_count' => 0, 'locked_until' => null]);
            self::invalidateSessions($id);
            Audit::log($actx, Audit::USER_PASSWORD_RESET, 'user', $id, inTrx: true);
        });
        $sent = Telegram::sendToUser($id, T::t('telegram.temp.password', ['password' => $temp]));
        return ['temporary_password' => $temp, 'sent_via_telegram' => $sent];
    }

    public static function deviceHistory(int $id, array $page): array
    {
        self::row($id);
        $qb = DB::table('device_history as d')
            ->leftJoin('users as a', 'a.id', '=', 'd.actor_id')
            ->leftJoin('roles as r', 'r.id', '=', 'a.role_id')
            ->where('d.user_id', $id)
            ->orderByDesc('d.created_at')
            ->select('d.id', 'd.device_name', 'd.event', 'd.created_at', 'd.ip', Actor::hiddenName('a', 'r', 'actor_name'));
        $current = DB::table('users')->where('id', $id)->first(['device_name', 'device_bound_at', 'last_login_at']);
        return ['current' => $current] + Page::paginate($qb, $page);
    }
}
