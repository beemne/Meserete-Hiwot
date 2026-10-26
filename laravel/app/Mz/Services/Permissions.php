<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Db\UtcDateTime;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use DateTimeImmutable;
use Illuminate\Support\Facades\DB;

/**
 * Absence permission requests per program occurrence: deadline before the start, monthly /
 * quarterly quotas. Approval records the attendance as 'excused' (port of permissionService.js).
 */
final class Permissions
{
    private const COUNTED = ['pending', 'approved'];

    public static function periodsOf(mixed $startsAt): array
    {
        $d = DateTimeImmutable::createFromInterface(Dates::of($startsAt))->setTimezone(Dates::tz());
        return ['month' => $d->format('Y-m'), 'quarter' => $d->format('Y') . '-Q' . (intdiv((int) $d->format('n') - 1, 3) + 1)];
    }

    private static function deadlineOf(object $program, array $policy): UtcDateTime
    {
        return new UtcDateTime('@' . (Dates::of($program->starts_at)->getTimestamp() - (int) $policy['deadline_hours'] * 3600));
    }

    /** The program narrowed to one occurrence (no date: the next one that has not ended, else the last). */
    public static function atOccurrence(object $program, ?string $date): object
    {
        if ($date) {
            $o = Schedule::on($program, $date);
            if (! $o) throw ApiError::field('date', 'NOT_AN_OCCURRENCE');
        } else {
            $o = Schedule::next($program);
            if (! $o) {
                $all = Schedule::between($program, '1900-01-01', '2999-12-31');
                $o = end($all) ?: null;
            }
        }
        $p = clone $program;
        $p->starts_at = $o['starts_at'];
        $p->ends_at = $o['ends_at'];
        $p->occurrence_date = $o['date'];
        return $p;
    }

    private static function usage(int $userId, array $periods, ?object $exclude): array
    {
        $count = function (string $col, string $val) use ($userId, $exclude) {
            $q = DB::table('permission_requests')->where(['user_id' => $userId, $col => $val])->whereIn('status', self::COUNTED);
            if ($exclude) $q->whereNot(fn ($w) => $w->where(['program_id' => $exclude->id, 'occurrence_date' => $exclude->occurrence_date]));
            return $q->count();
        };
        return ['month' => $count('period_month', $periods['month']), 'quarter' => $count('period_quarter', $periods['quarter'])];
    }

    private static function isInvited(object $program, int $userId): bool
    {
        if ($program->audience === 'all') return true;
        return DB::table('program_participants')->where(['program_id' => $program->id, 'user_id' => $userId])->whereIn('status', ['invited', 'registered'])->exists();
    }

    private static function blockReason(object $program, array $policy, ?object $existing, array $used, bool $invited): ?string
    {
        if (! $policy['enabled']) return 'PERMISSION_DISABLED';
        if ($program->status !== 'published' || ! $program->requires_attendance) return 'PERMISSION_NOT_APPLICABLE';
        if (! $invited) return 'PERMISSION_NOT_APPLICABLE';
        if ($existing && $existing->status !== 'cancelled') return $existing->status === 'rejected' ? 'PERMISSION_REJECTED' : 'PERMISSION_EXISTS';
        if (Dates::now() > self::deadlineOf($program, $policy)) return 'PERMISSION_DEADLINE_PASSED';
        if ($policy['monthly_limit'] !== null && $used['month'] >= $policy['monthly_limit']) return 'PERMISSION_MONTHLY_LIMIT';
        if ($policy['quarterly_limit'] !== null && $used['quarter'] >= $policy['quarterly_limit']) return 'PERMISSION_QUARTERLY_LIMIT';
        return null;
    }

    private static function state(object $program, int $userId, array $policy): array
    {
        $periods = self::periodsOf($program->starts_at);
        $existing = DB::table('permission_requests')->where(['program_id' => $program->id, 'occurrence_date' => $program->occurrence_date, 'user_id' => $userId])->first();
        $used = self::usage($userId, $periods, $program);
        $invited = self::isInvited($program, $userId);
        return ['periods' => $periods, 'existing' => $existing, 'used' => $used, 'invited' => $invited, 'blocked' => self::blockReason($program, $policy, $existing, $used, $invited)];
    }

    /** Summary in a program's detail for the signed-in user (next occurrence). */
    public static function forProgram(object $program, int $userId, ?string $date = null): array
    {
        $policy = Settings::permissionPolicy();
        $p = self::atOccurrence($program, $date);
        $s = self::state($p, $userId, $policy);
        $deadline = self::deadlineOf($p, $policy);
        $active = $s['existing'] && $s['existing']->status !== 'cancelled' ? $s['existing'] : null;
        return [
            'enabled' => $policy['enabled'],
            'occurrence_date' => $p->occurrence_date,
            'status' => $active?->status,
            'reason' => $active?->reason,
            'review_note' => $active?->review_note,
            'deadline_at' => $deadline,
            'can_request' => $s['blocked'] === null,
            'blocked_reason' => $s['blocked'],
            // Once approved the member no longer cancels it (an administrator can undo a mistaken approval).
            'can_cancel' => (bool) ($active && $active->status === 'pending' && Dates::now() <= $deadline),
            'month_used' => $s['used']['month'],
            'monthly_limit' => $policy['monthly_limit'],
            'quarter_used' => $s['used']['quarter'],
            'quarterly_limit' => $policy['quarterly_limit'],
        ];
    }

    private static function loadProgram(int $id): object
    {
        $p = DB::table('programs')->where('id', $id)->first(['id', 'title', 'status', 'starts_at', 'ends_at', 'recurrence', 'monthly_rule', 'recurrence_until', 'ethiopian_days', 'requires_attendance', 'audience']);
        if (! $p || $p->status === 'draft') throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        Schedule::loadOverrides($p);
        return $p;
    }

    public static function request(AuthContext $auth, int $programId, ?string $reason, ?string $date): void
    {
        $notified = false;
        DB::transaction(function () use ($auth, $programId, $reason, $date, &$notified) {
            DB::table('users')->where('id', $auth->id)->lockForUpdate()->first(['id']);
            $program = self::atOccurrence(self::loadProgram($programId), $date);
            $policy = Settings::permissionPolicy();
            $s = self::state($program, $auth->id, $policy);
            if ($s['blocked']) {
                $status = in_array($s['blocked'], ['PERMISSION_NOT_APPLICABLE', 'PERMISSION_DISABLED'], true) ? 403 : 409;
                throw new ApiError($status, $s['blocked'], $s['blocked']);
            }
            $row = ['reason' => $reason, 'status' => 'pending', 'period_month' => $s['periods']['month'], 'period_quarter' => $s['periods']['quarter'], 'reviewed_by' => null, 'reviewed_at' => null, 'review_note' => null];
            if ($s['existing']) {
                $requestId = $s['existing']->id;
                DB::table('permission_requests')->where('id', $requestId)->update($row);
            } else {
                $requestId = DB::table('permission_requests')->insertGetId($row + ['program_id' => $programId, 'occurrence_date' => $program->occurrence_date, 'user_id' => $auth->id]);
            }
            $admins = self::adminIdsWithPermission('attendance.manage');
            if ($admins) {
                $user = DB::table('users')->where('id', $auth->id)->first(['full_name']);
                $now = (int) round(microtime(true) * 1000);
                $notified = Notifications::createForUsers($admins, [
                    'type' => 'attendance',
                    'title' => T::t('permission.requested.title'),
                    'body' => T::t('permission.requested.body', ['name' => $user->full_name, 'title' => $program->title]),
                    'entityType' => 'permission_request',
                    'entityId' => $requestId,
                    'dedupeKey' => fn ($uid) => "permreq:$requestId:$now:$uid",
                ]) > 0;
            }
        });
        if ($notified) Notifications::kick();
    }

    /** Active administrators holding the permission through their role or a direct grant. */
    public static function adminIdsWithPermission(string $permission): array
    {
        return DB::table('users as u')->where(['u.account_type' => 'admin', 'u.status' => 'active'])->whereNull('u.deleted_at')
            ->where(fn ($w) => $w
                ->whereExists(fn ($s) => $s->select(DB::raw(1))->from('role_permissions as rp')->join('permissions as p', 'p.id', '=', 'rp.permission_id')->whereColumn('rp.role_id', 'u.role_id')->where('p.key', $permission))
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('user_permissions as up')->join('permissions as p', 'p.id', '=', 'up.permission_id')->whereColumn('up.user_id', 'u.id')->where('p.key', $permission)))
            ->pluck('u.id')->all();
    }

    public static function pendingSummary(): array
    {
        $c = DB::table('permission_requests')->where('status', 'pending')->count();
        $latest = self::adminList(['status' => 'pending'], ['page' => 1, 'limit' => 5, 'offset' => 0]);
        return ['pending' => $c, 'latest' => $latest['items']];
    }

    private static function clearExcused(int $programId, string $date, int $userId): void
    {
        DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $date, 'user_id' => $userId, 'status' => 'excused'])->delete();
    }

    public static function cancel(AuthContext $auth, int $programId, ?string $date): void
    {
        DB::transaction(function () use ($auth, $programId, $date) {
            $program = self::atOccurrence(self::loadProgram($programId), $date);
            $policy = Settings::permissionPolicy();
            $r = DB::table('permission_requests')->where(['program_id' => $programId, 'occurrence_date' => $program->occurrence_date, 'user_id' => $auth->id])->lockForUpdate()->first();
            if (! $r || ! in_array($r->status, ['pending', 'approved'], true)) throw ApiError::notFound('PERMISSION_NOT_FOUND', 'Permission request not found');
            if ($r->status === 'approved') throw ApiError::conflict('PERMISSION_ALREADY_APPROVED', 'An approved permission is no longer cancelled by the member');
            if (Dates::now() > self::deadlineOf($program, $policy)) throw ApiError::conflict('PERMISSION_DEADLINE_PASSED', 'PERMISSION_DEADLINE_PASSED');
            DB::table('permission_requests')->where('id', $r->id)->update(['status' => 'cancelled']);
            if ($r->status === 'approved') self::clearExcused($programId, $program->occurrence_date, $auth->id);
        });
    }

    public static function adminList(array $filter, array $page): array
    {
        $qb = DB::table('permission_requests as r')->join('users as u', 'u.id', '=', 'r.user_id')->join('programs as p', 'p.id', '=', 'r.program_id')
            ->leftJoin('users as cx', 'cx.id', '=', 'r.cancelled_by')
            ->select('r.id', 'r.status', 'r.reason', 'r.review_note', 'r.created_at', 'r.reviewed_at', 'r.period_month', 'r.period_quarter', 'r.occurrence_date',
                'r.cancelled_at', 'r.cancel_reason', 'cx.full_name as cancelled_by_name',
                'u.id as user_id', 'u.full_name', 'u.phone', 'p.id as program_id', 'p.title as program_title', 'p.starts_at', 'p.ends_at', 'p.recurrence', 'p.monthly_rule', 'p.recurrence_until', 'p.ethiopian_days',
                DB::raw("(SELECT COUNT(*) FROM permission_requests x WHERE x.user_id = r.user_id AND x.period_month = r.period_month AND x.status IN ('pending','approved')) as month_used"),
                DB::raw("(SELECT COUNT(*) FROM permission_requests x WHERE x.user_id = r.user_id AND x.period_quarter = r.period_quarter AND x.status IN ('pending','approved')) as quarter_used"))
            ->orderByDesc('r.created_at');
        if (! empty($filter['status'])) $qb->where('r.status', $filter['status']);
        if (! empty($filter['program_id'])) $qb->where('r.program_id', $filter['program_id']);
        if (! empty($filter['q'])) $qb->where(fn ($w) => $w->where('u.full_name', 'like', "%{$filter['q']}%")->orWhere('u.phone', 'like', "%{$filter['q']}%"));
        $out = Page::paginate($qb, $page);
        $out['items'] = array_map(function ($row) {
            $date = Dates::toDateOnly($row->occurrence_date);
            $prog = (object) ['id' => $row->program_id, 'starts_at' => $row->starts_at, 'ends_at' => $row->ends_at, 'recurrence' => $row->recurrence, 'monthly_rule' => $row->monthly_rule, 'recurrence_until' => $row->recurrence_until, 'ethiopian_days' => $row->ethiopian_days];
            $occ = Schedule::on($prog, $date);
            $r = (array) $row;
            unset($r['recurrence'], $r['monthly_rule'], $r['recurrence_until'], $r['ends_at']);
            $r['occurrence_date'] = $date;
            $r['starts_at'] = $occ['starts_at'] ?? $row->starts_at;
            $r['month_used'] = (int) $row->month_used;
            $r['quarter_used'] = (int) $row->quarter_used;
            return $r;
        }, $out['items']);
        return $out;
    }

    public static function review(array $actx, int $id, string $status, ?string $note): ?object
    {
        $notify = false;
        $result = DB::transaction(function () use ($actx, $id, $status, $note, &$notify) {
            $r = DB::table('permission_requests')->where('id', $id)->lockForUpdate()->first();
            if (! $r || $r->status === 'cancelled') throw ApiError::notFound('PERMISSION_NOT_FOUND', 'Permission request not found');
            $program = self::loadProgram($r->program_id);
            $date = Dates::toDateOnly($r->occurrence_date);
            DB::table('permission_requests')->where('id', $id)->update(['status' => $status, 'review_note' => $note, 'reviewed_by' => $actx['auth']->id, 'reviewed_at' => Dates::sql(Dates::now())]);
            if ($status === 'approved') {
                $att = DB::table('attendance')->where(['program_id' => $r->program_id, 'occurrence_date' => $date, 'user_id' => $r->user_id])->first(['id', 'status']);
                if (! $att) {
                    DB::table('attendance')->insert(['program_id' => $r->program_id, 'occurrence_date' => $date, 'user_id' => $r->user_id, 'status' => 'excused', 'notes' => 'permission', 'recorded_by' => $actx['auth']->id, 'updated_by' => $actx['auth']->id]);
                } elseif ($att->status === 'absent') {
                    DB::table('attendance')->where('id', $att->id)->update(['status' => 'excused', 'notes' => 'permission', 'updated_by' => $actx['auth']->id]);
                }
            } else {
                self::clearExcused($r->program_id, $date, $r->user_id);
            }
            Audit::log($actx, Audit::PERMISSION_REVIEW, 'permission_request', $id, ['status' => $status, 'previous' => $r->status, 'user_id' => $r->user_id, 'program_id' => $r->program_id, 'date' => $date], inTrx: true);
            Choir::scheduleEligibility([(int) $r->user_id]);
            if ($status !== $r->status) {
                $now = (int) round(microtime(true) * 1000);
                $notify = Notifications::createForUsers([$r->user_id], [
                    'type' => 'attendance',
                    'title' => T::t("permission.$status.title"),
                    'body' => T::t("permission.$status.body", ['title' => $program->title]),
                    'entityType' => 'program',
                    'entityId' => $r->program_id,
                    'email' => true,
                    'dedupeKey' => fn ($uid) => "permission:$id:$status:$now:$uid",
                ]) > 0;
            }
            return DB::table('permission_requests')->where('id', $id)->first();
        });
        if ($notify) Notifications::kick();
        return $result;
    }

    /**
     * Undo an approval given by mistake: the request becomes 'cancelled' (who, when and why are
     * kept), the 'excused' mark the approval created is removed — a mark an attendance taker set by
     * hand is left alone — and the member is told. The quota it used is freed. Repeating the call on
     * a cancelled request changes nothing.
     */
    public static function cancelApproved(array $actx, int $id, string $reason): ?object
    {
        $notify = false;
        $result = DB::transaction(function () use ($actx, $id, $reason, &$notify) {
            $r = DB::table('permission_requests')->where('id', $id)->lockForUpdate()->first();
            if (! $r) throw ApiError::notFound('PERMISSION_NOT_FOUND', 'Permission request not found');
            if ($r->status === 'cancelled') return $r;
            if ($r->status !== 'approved') throw ApiError::conflict('PERMISSION_NOT_APPROVED', 'Only an approved permission can be cancelled');
            $date = Dates::toDateOnly($r->occurrence_date);
            $by = $actx['auth']->id;
            DB::table('permission_requests')->where('id', $id)->update(['status' => 'cancelled', 'cancelled_by' => $by, 'cancelled_at' => Dates::sql(Dates::now()), 'cancel_reason' => $reason]);
            $att = DB::table('attendance')->where(['program_id' => $r->program_id, 'occurrence_date' => $date, 'user_id' => $r->user_id])->lockForUpdate()->first(['id', 'status', 'notes']);
            $removed = $att && $att->status === 'excused' && $att->notes === 'permission';
            if ($removed) DB::table('attendance')->where('id', $att->id)->delete();
            Audit::log($actx, Audit::PERMISSION_CANCEL, 'permission_request', $id, ['previous' => 'approved', 'user_id' => $r->user_id, 'program_id' => $r->program_id, 'date' => $date, 'excused_mark_removed' => $removed, 'reason' => $reason], inTrx: true);
            Choir::scheduleEligibility([(int) $r->user_id]);
            $program = DB::table('programs')->where('id', $r->program_id)->first(['title']);
            $notify = Notifications::createForUsers([$r->user_id], [
                'type' => 'attendance',
                'title' => T::t('permission.cancelled.title'),
                'body' => T::t('permission.cancelled.body', ['title' => $program?->title ?? '', 'reason' => $reason]),
                'entityType' => 'program',
                'entityId' => $r->program_id,
                'email' => true,
                'dedupeKey' => fn ($uid) => "permission:$id:cancelled:$uid",
            ]) > 0;
            return DB::table('permission_requests')->where('id', $id)->first();
        });
        if ($notify) Notifications::kick();
        return $result;
    }
}
