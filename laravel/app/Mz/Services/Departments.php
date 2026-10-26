<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Support\ApiError;
use App\Mz\Support\Ethiopian;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

/** The 7 departments, their members and leaders' monthly participation (port of departmentService.js). */
final class Departments
{
    private static function serialize(object $d): array
    {
        $out = [
            'id' => $d->id,
            'name' => $d->name,
            'name_en' => $d->name_en ?? null,
            'description' => $d->description,
            'is_active' => (bool) $d->is_active,
            'leader' => $d->leader_id ? ['id' => $d->leader_id, 'full_name' => $d->leader_name] : null,
        ];
        if (property_exists($d, 'member_count')) {
            $out['member_count'] = (int) $d->member_count;
        }
        return $out;
    }

    private static function base()
    {
        return DB::table('departments as d')
            ->leftJoin('user_departments as ld', fn ($j) => $j->on('ld.department_id', '=', 'd.id')->where('ld.role', '=', 'leader'))
            ->leftJoin('users as l', 'l.id', '=', 'ld.user_id')
            ->select('d.*', 'l.id as leader_id', 'l.full_name as leader_name', DB::raw('(SELECT COUNT(*) FROM user_departments ud WHERE ud.department_id = d.id) as member_count'))
            ->orderBy('d.sort_order')->orderBy('d.id');
    }

    public static function list(bool $includeInactive = false): array
    {
        $q = self::base();
        if (! $includeInactive) $q->where('d.is_active', true);
        return $q->get()->map(fn ($d) => self::serialize($d))->all();
    }

    public static function get(int $id): array
    {
        $d = self::base()->where('d.id', $id)->first();
        if (! $d) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
        return self::serialize($d);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $patch = array_intersect_key($input, array_flip(['description', 'name_en']));
        $exists = DB::table('departments')->where('id', $id)->exists();
        if (! $exists) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
        if ($patch) DB::table('departments')->where('id', $id)->update($patch);
        Audit::log($actx, Audit::DEPARTMENT_UPDATE, 'department', $id, ['fields' => array_keys($patch)]);
        return self::get($id);
    }

    public static function members(int $departmentId, ?string $q, array $page): array
    {
        self::get($departmentId);
        $qb = DB::table('user_departments as ud')
            ->join('users as u', 'u.id', '=', 'ud.user_id')
            ->where('ud.department_id', $departmentId)
            ->whereNull('u.deleted_at')
            ->select('ud.id', 'ud.role', 'ud.created_at', 'u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'u.profile_image')
            ->orderByRaw("ud.role = 'leader' DESC")
            ->orderBy('u.full_name');
        MemberIds::search($qb, $q);
        $res = Page::paginate($qb, $page);
        $res['items'] = MemberIds::decorate($res['items']);
        return $res;
    }

    private static function assertAssignable(array $userIds): void
    {
        $rows = MemberIds::membersAndAdmins(DB::table('users'))->whereIn('id', $userIds)->whereNull('deleted_at')->select('id', 'member_group')->get();
        if ($rows->count() !== count(array_unique($userIds))) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        if ($rows->contains(fn ($r) => $r->member_group === 'children')) throw ApiError::conflict('CHILDREN_NO_DEPARTMENT', 'Children are not assigned to departments');
    }

    /** Assign members (multi-select) and/or set the leader (the old one stays as a member). */
    public static function assign(array $actx, int $departmentId, array $memberIds = [], ?int $leaderId = null): array
    {
        self::get($departmentId);
        $all = array_values(array_unique(array_merge($memberIds, $leaderId ? [$leaderId] : [])));
        if (! $all) return self::get($departmentId);
        DB::transaction(function () use ($actx, $departmentId, $memberIds, $leaderId, $all) {
            DB::table('departments')->where('id', $departmentId)->lockForUpdate()->first(['id']);
            self::assertAssignable($all);
            foreach ($memberIds as $uid) {
                DB::table('user_departments')->insertOrIgnore(['user_id' => $uid, 'department_id' => $departmentId, 'role' => 'member', 'assigned_by' => $actx['auth']->id]);
            }
            if ($leaderId) {
                DB::table('user_departments')->where(['department_id' => $departmentId, 'role' => 'leader'])->where('user_id', '<>', $leaderId)->update(['role' => 'member']);
                DB::table('user_departments')->upsert([['user_id' => $leaderId, 'department_id' => $departmentId, 'role' => 'leader', 'assigned_by' => $actx['auth']->id]], ['user_id', 'department_id'], ['role', 'assigned_by']);
            }
            Audit::log($actx, Audit::DEPARTMENT_ASSIGN, 'department', $departmentId, ['members' => $memberIds, 'leader' => $leaderId], inTrx: true);
        });
        // The people added to the department (and its new leader) are told.
        $dept = DB::table('departments')->where('id', $departmentId)->value('name');
        $stamp = \App\Mz\Projects\Pm::stamp();
        $members = array_values(array_diff(array_map('intval', $memberIds), $leaderId ? [$leaderId] : [], [$actx['auth']->id]));
        \App\Mz\Notifications\Notifications::createForUsers($members, [
            'type' => 'department', 'title' => \App\Mz\Support\T::t('department.member.title'), 'body' => \App\Mz\Support\T::t('department.member.body', ['department' => $dept]),
            'entityType' => 'department', 'entityId' => $departmentId, 'dedupeKey' => fn ($uid) => "dept:$departmentId:member:$uid",
        ]);
        if ($leaderId && $leaderId !== $actx['auth']->id) {
            \App\Mz\Notifications\Notifications::createForUsers([$leaderId], [
                'type' => 'department', 'title' => \App\Mz\Support\T::t('department.leader.title'), 'body' => \App\Mz\Support\T::t('department.leader.body', ['department' => $dept]),
                'entityType' => 'department', 'entityId' => $departmentId, 'email' => true, 'dedupeKey' => fn ($uid) => "dept:$departmentId:leader:$uid:$stamp",
            ]);
        }
        return self::get($departmentId);
    }

    public static function setRole(array $actx, int $departmentId, int $userId, string $role): array
    {
        if ($role === 'leader') return self::assign($actx, $departmentId, [], $userId);
        $exists = DB::table('user_departments')->where(['department_id' => $departmentId, 'user_id' => $userId])->exists();
        if (! $exists) throw ApiError::notFound('ASSIGNMENT_NOT_FOUND', 'Assignment not found');
        DB::table('user_departments')->where(['department_id' => $departmentId, 'user_id' => $userId])->update(['role' => 'member']);
        Audit::log($actx, Audit::DEPARTMENT_ASSIGN, 'department', $departmentId, ['user_id' => $userId, 'role' => $role]);
        return self::get($departmentId);
    }

    public static function unassign(array $actx, int $userId, int $departmentId): void
    {
        $n = DB::table('user_departments')->where(['user_id' => $userId, 'department_id' => $departmentId])->delete();
        if (! $n) throw ApiError::notFound('ASSIGNMENT_NOT_FOUND', 'Assignment not found');
        Audit::log($actx, Audit::DEPARTMENT_ASSIGN, 'user', $userId, ['department_id' => $departmentId, 'removed' => true]);
    }

    /** A member's departments with their role. */
    public static function departmentsOf(int $userId): array
    {
        return DB::table('user_departments as ud')->join('departments as d', 'd.id', '=', 'ud.department_id')
            ->where('ud.user_id', $userId)->where('d.is_active', true)
            ->select('d.id', 'd.name', 'd.name_en', 'ud.role')
            ->orderBy('d.sort_order')->orderBy('d.id')->get()->all();
    }

    // ------------------------------------------------------------------ monthly participation
    private static function assertLeader(int $userId, int $departmentId): void
    {
        if (! DB::table('user_departments')->where(['user_id' => $userId, 'department_id' => $departmentId, 'role' => 'leader'])->exists()) {
            throw ApiError::forbidden('NOT_DEPARTMENT_LEADER', 'Only the department leader records participation');
        }
    }

    public static function ledBy(int $userId): array
    {
        return DB::table('user_departments as ud')->join('departments as d', 'd.id', '=', 'ud.department_id')
            ->where(['ud.user_id' => $userId, 'ud.role' => 'leader', 'd.is_active' => true])
            ->select('d.id', 'd.name', 'd.name_en')->orderBy('d.sort_order')->orderBy('d.id')->get()->all();
    }

    public static function participationPolicy(): array
    {
        $p = Settings::get('participation.policy') ?? [];
        return ['max_score' => Num::clean((float) ($p['max_score'] ?? 10))];
    }

    public static function participationSheet(int $departmentId, string $period, ?int $leaderId = null): array
    {
        if ($leaderId) self::assertLeader($leaderId, $departmentId);
        $dept = self::get($departmentId);
        $rows = DB::table('user_departments as ud')
            ->join('users as u', 'u.id', '=', 'ud.user_id')
            ->leftJoin('department_participation as p', fn ($j) => $j->on('p.user_id', '=', 'u.id')->on('p.department_id', '=', 'ud.department_id')->where('p.period', '=', $period))
            ->leftJoin('users as r', 'r.id', '=', 'p.recorded_by')
            ->where('ud.department_id', $departmentId)
            ->whereNull('u.deleted_at')
            ->orderByRaw("ud.role = 'leader' desc")
            ->orderBy('u.full_name')
            ->select('u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.profile_image', 'ud.role', 'p.score', 'p.note', 'p.updated_at', 'r.full_name as recorded_by_name')
            ->get()->all();
        $members = array_map(function ($r) {
            $r->score = $r->score === null ? null : Num::n($r->score);
            return $r;
        }, MemberIds::decorate($rows));
        return ['department' => $dept, 'period' => $period, 'policy' => self::participationPolicy(), 'members' => $members];
    }

    public static function saveParticipation(array $actx, int $departmentId, string $period, array $entries): array
    {
        self::assertLeader($actx['auth']->id, $departmentId);
        if (strcmp($period, Ethiopian::currentPeriod()) > 0) throw ApiError::field('period', 'FUTURE_PERIOD');
        $max = self::participationPolicy()['max_score'];
        foreach ($entries as $e) {
            if (($e['score'] ?? null) !== null && $e['score'] > $max) {
                throw ApiError::validation([['field' => 'entries', 'code' => 'SCORE_ABOVE_MAX', 'message' => "SCORE_ABOVE_MAX:$max"]]);
            }
        }
        $memberIds = array_flip(DB::table('user_departments')->where('department_id', $departmentId)->pluck('user_id')->all());
        foreach ($entries as $e) {
            if (! isset($memberIds[$e['user_id']])) throw ApiError::field('entries', 'NOT_A_MEMBER');
        }
        $changes = [];
        DB::transaction(function () use ($actx, $departmentId, $period, $entries, &$changes) {
            foreach ($entries as $e) {
                $key = ['department_id' => $departmentId, 'user_id' => $e['user_id'], 'period' => $period];
                $cur = DB::table('department_participation')->where($key)->first(['id', 'score']);
                $old = $cur ? Num::n($cur->score) : null;
                $next = ($e['score'] ?? null) === null ? null : Num::round1($e['score']);
                $hasNote = array_key_exists('note', $e);
                $same = ($old === null && $next === null) || ($old !== null && $next !== null && (float) $old === (float) $next);
                if ($same && ! ($cur && $hasNote)) continue;
                if ($next === null) {
                    if ($cur) DB::table('department_participation')->where('id', $cur->id)->delete();
                } elseif ($cur) {
                    DB::table('department_participation')->where('id', $cur->id)->update(['score' => $next, 'note' => $e['note'] ?? null, 'recorded_by' => $actx['auth']->id]);
                } else {
                    DB::table('department_participation')->insert($key + ['score' => $next, 'note' => $e['note'] ?? null, 'recorded_by' => $actx['auth']->id]);
                }
                if (! $same) {
                    DB::table('department_participation_history')->insert($key + ['old_score' => $old, 'new_score' => $next ?? 0, 'note' => $next === null ? 'removed' : ($e['note'] ?? null), 'changed_by' => $actx['auth']->id]);
                    $changes[] = ['user_id' => $e['user_id'], 'old' => $old, 'new' => $next];
                }
            }
            Audit::log($actx, Audit::PARTICIPATION, 'department', $departmentId, ['period' => $period, 'changes' => $changes], inTrx: true);
        });
        Choir::scheduleEligibility(array_column($changes, 'user_id'));
        return self::participationSheet($departmentId, $period);
    }

    public static function participationHistory(int $userId): array
    {
        return DB::table('department_participation_history as h')
            ->leftJoin('users as u', 'u.id', '=', 'h.changed_by')
            ->join('departments as d', 'd.id', '=', 'h.department_id')
            ->where('h.user_id', $userId)
            ->orderByDesc('h.created_at')
            ->select('h.department_id', 'd.name as department_name', 'd.name_en as department_name_en', 'h.period', 'h.old_score', 'h.new_score', 'h.note', 'u.full_name as changed_by_name', 'h.created_at')
            ->get()->all();
    }

    /** The AVERAGE of the recorded monthly scores in [from, to]; months without a score are "missing". */
    public static function participationAverage(int $userId, string $from, string $to): array
    {
        $max = self::participationPolicy()['max_score'];
        $depts = DB::table('user_departments as ud')->join('departments as d', 'd.id', '=', 'ud.department_id')->where('ud.user_id', $userId)->select('ud.department_id', 'd.name', 'd.name_en')->get()->all();
        $recorded = DB::table('department_participation as p')->leftJoin('users as r', 'r.id', '=', 'p.recorded_by')
            ->where('p.user_id', $userId)->whereBetween('p.period', [$from, $to])->orderBy('p.period')
            ->select('p.department_id', 'p.period', 'p.score', 'p.note', 'p.updated_at', 'r.full_name as recorded_by_name')->get()->all();
        $names = [];
        foreach ($depts as $d) $names[$d->department_id] = $d;
        $months = array_map(fn ($r) => [
            'department_id' => $r->department_id,
            'department' => $names[$r->department_id]->name ?? null,
            'department_en' => $names[$r->department_id]->name_en ?? null,
            'period' => $r->period,
            'score' => Num::n($r->score),
            'note' => $r->note,
            'recorded_by' => $r->recorded_by_name,
            'recorded_at' => $r->updated_at,
        ], $recorded);
        $missing = [];
        foreach ($depts as $d) {
            foreach (Ethiopian::monthsBetween($from, $to) as $p) {
                $has = false;
                foreach ($months as $m) {
                    if ($m['department_id'] === $d->department_id && $m['period'] === $p) { $has = true; break; }
                }
                if (! $has) $missing[] = ['department_id' => $d->department_id, 'department' => $d->name, 'department_en' => $d->name_en, 'period' => $p];
            }
        }
        $average = $months ? Num::round1(array_sum(array_column($months, 'score')) / count($months)) : null;
        return [
            'max_score' => $max,
            'average' => $average,
            'percent' => $average === null ? null : Num::clean(floor(($average / $max) * 1000 + 0.5) / 10),
            'months' => $months,
            'missing' => $missing,
            'in_department' => count($depts) > 0,
        ];
    }
}
