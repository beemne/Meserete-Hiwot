<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/** Bulk selection ({user_ids} | {filter} | {all}, minus exclude_ids) → user ids, server-side (port of userTargetingService.js). */
final class Targeting
{
    /** Regular (non-admin) user accounts matching a filter. */
    public static function query(array $filter = []): Builder
    {
        // Members and administrators (administrators are members too); never the hidden system authority.
        $qb = MemberIds::membersAndAdmins(DB::table('users as u'), 'u')->whereNull('u.deleted_at');
        if (in_array($filter['account_type'] ?? null, ['user', 'admin'], true)) $qb->where('u.account_type', $filter['account_type']);
        if (! empty($filter['status'])) $qb->where('u.status', $filter['status']);
        if (! empty($filter['q'])) {
            $like = '%' . $filter['q'] . '%';
            $no = MemberIds::noFromQuery($filter['q']);
            $qb->where(function ($w) use ($like, $no) {
                $w->where('u.full_name', 'like', $like)->orWhere('u.phone', 'like', $like)->orWhere('u.email', 'like', $like);
                if ($no !== null) $w->orWhere('u.member_no', $no);
            });
        }
        if (! empty($filter['member_group'])) $qb->where('u.member_group', $filter['member_group']);
        if (! empty($filter['membership_status'])) $qb->where('u.membership_status', $filter['membership_status']);
        if (! empty($filter['department_id'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('user_departments as ud')->whereColumn('ud.user_id', 'u.id')->where('ud.department_id', $filter['department_id']));
        }
        if (! empty($filter['class_id'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('edu_enrollments as en')->whereColumn('en.user_id', 'u.id')->where('en.class_id', $filter['class_id'])->where('en.status', 'active'));
        }
        if (! empty($filter['registered_from'])) $qb->where('u.created_at', '>=', $filter['registered_from'] . ' 00:00:00');
        if (! empty($filter['registered_to'])) $qb->where('u.created_at', '<=', $filter['registered_to'] . ' 23:59:59');
        if (! empty($filter['program_id'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('program_participants as pp')->whereColumn('pp.user_id', 'u.id')->where('pp.program_id', $filter['program_id'])->where('pp.status', '<>', 'cancelled'));
        }
        // Personal details (membership form) and account.
        $empStatus = $filter['employment_status'] ?? ($filter['member_type'] ?? null);
        if (! empty($empStatus)) $qb->where('u.member_type', $empStatus);
        if (! empty($filter['spiritual_level'])) $qb->where('u.spiritual_level', $filter['spiritual_level']);

        // Profession filtering: category, exact profession, custom Other text
        if (! empty($filter['profession_category'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('member_profiles as mpc')->whereColumn('mpc.user_id', 'u.id')->where('mpc.profession_category', $filter['profession_category']));
        }
        if (! empty($filter['profession_id'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('member_profiles as mpp')->whereColumn('mpp.user_id', 'u.id')->where('mpp.profession_id', (int) $filter['profession_id']));
        } elseif (! empty($filter['profession'])) {
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('member_profiles as mpp')->whereColumn('mpp.user_id', 'u.id')->where('mpp.profession', $filter['profession']));
        }
        if (! empty($filter['profession_other'])) {
            $likeOther = '%' . $filter['profession_other'] . '%';
            $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('member_profiles as mpo')->whereColumn('mpo.user_id', 'u.id')->where('mpo.profession_other', 'like', $likeOther));
        }

        foreach (['gender', 'marital_status'] as $k) {
            if (! empty($filter[$k])) {
                $qb->whereExists(fn ($s) => $s->select(DB::raw(1))->from('member_profiles as mp')->whereColumn('mp.user_id', 'u.id')->where("mp.$k", $filter[$k]));
            }
        }
        if (! empty($filter['age_min']) || ! empty($filter['age_max'])) {
            $today = new \DateTimeImmutable(Dates::todayLocal());
            $qb->whereExists(function ($s) use ($filter, $today) {
                $s->select(DB::raw(1))->from('member_profiles as mpa')->whereColumn('mpa.user_id', 'u.id')->whereNotNull('mpa.birth_date');
                // age ≥ min ⇔ born on or before today − min years; age ≤ max ⇔ born after today − (max + 1) years.
                if (! empty($filter['age_min'])) $s->where('mpa.birth_date', '<=', $today->modify('-' . (int) $filter['age_min'] . ' years')->format('Y-m-d'));
                if (! empty($filter['age_max'])) $s->where('mpa.birth_date', '>', $today->modify('-' . ((int) $filter['age_max'] + 1) . ' years')->format('Y-m-d'));
            });
        }
        if (array_key_exists('has_device', $filter) && $filter['has_device'] !== null) {
            $filter['has_device'] ? $qb->whereNotNull('u.device_id') : $qb->whereNull('u.device_id');
        }
        if (array_key_exists('telegram_linked', $filter) && $filter['telegram_linked'] !== null) {
            $filter['telegram_linked'] ? $qb->whereNotNull('u.telegram_linked_at') : $qb->whereNull('u.telegram_linked_at');
        }
        if (! empty($filter['active_within_days'])) {
            $qb->where('u.last_login_at', '>=', Dates::sql(Dates::now()->modify('-' . (int) $filter['active_within_days'] . ' days')));
        }
        if (array_key_exists('has_active_borrowing', $filter) && $filter['has_active_borrowing'] !== null) {
            $sub = fn ($s) => $s->select(DB::raw(1))->from('borrowings as b')->whereColumn('b.user_id', 'u.id')->whereIn('b.status', ['active', 'partially_returned']);
            $filter['has_active_borrowing'] ? $qb->whereExists($sub) : $qb->whereNotExists($sub);
        }
        return $qb;
    }

    /** @return int[] */
    public static function resolve(array $target, bool $allowAll = true): array
    {
        if (! empty($target['user_ids'])) {
            $ids = self::query(['status' => 'active'])->whereIn('u.id', $target['user_ids'])->pluck('u.id')->all();
        } elseif (isset($target['filter'])) {
            $ids = self::query(array_merge(['status' => 'active'], $target['filter']))->pluck('u.id')->all();
        } elseif (! empty($target['all'])) {
            if (! $allowAll) throw ApiError::forbidden('FORBIDDEN', 'Not allowed to target all users');
            $ids = self::query(['status' => 'active'])->pluck('u.id')->all();
        } else {
            $ids = [];
        }
        if (! empty($target['exclude_ids'])) {
            $ex = array_flip($target['exclude_ids']);
            $ids = array_values(array_filter($ids, fn ($id) => ! isset($ex[$id])));
        }
        return array_map('intval', $ids);
    }

    public static function type(array $target): string
    {
        if (! empty($target['all'])) return 'all';
        if (isset($target['filter'])) return 'filter';
        return count($target['user_ids'] ?? []) === 1 ? 'user' : 'selected';
    }
}
