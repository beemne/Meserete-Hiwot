<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/** Projects and project teams (one project belongs to one department). */
final class ProjectService
{
    private const FIELDS = ['title', 'description', 'leader_id', 'start_date', 'deadline', 'status', 'priority', 'progress_mode', 'notes', 'allow_late_tasks', 'currency', 'proposed_budget'];

    public static function serialize(object $p, AuthContext $auth, ?array $access = null, bool $full = false): array
    {
        $access ??= Access::project($auth, $p);
        $now = Dates::now();
        $counts = DB::table('project_tasks')->where('project_id', $p->id)->whereNull('deleted_at')
            ->selectRaw("COUNT(*) as total, SUM(status = 'completed') as completed, SUM(status = 'cancelled') as cancelled,
                SUM(status IN ('not_started','pending','in_progress','blocked') AND deadline IS NOT NULL AND deadline < ?) as overdue,
                SUM(status = 'pending') as pending, SUM(status = 'blocked') as blocked, SUM(status = 'in_progress') as in_progress, SUM(status = 'not_started') as not_started", [Dates::sql($now)])
            ->first();
        $spent = (float) DB::table('project_expenses')->where('project_id', $p->id)->whereIn('status', ['approved', 'recorded'])->sum('amount');
        $approved = $p->approved_budget !== null ? Pm::money($p->approved_budget) : null;
        $dept = DB::table('departments')->where('id', $p->department_id)->first(['id', 'name', 'name_en']);
        $leader = $p->leader_id ? Pm::users([$p->leader_id])[(int) $p->leader_id] ?? null : null;
        $open = in_array($p->status, ['planning', 'not_started', 'in_progress', 'on_hold'], true);
        $out = [
            'id' => (int) $p->id,
            'department' => $dept,
            'title' => $p->title,
            'description' => $p->description,
            'leader' => $leader,
            'start_date' => Dates::toDateOnly($p->start_date),
            'deadline' => $p->deadline,
            'overdue' => $open && $p->deadline && Dates::of($p->deadline) < $now,
            'seconds_remaining' => $p->deadline ? Dates::of($p->deadline)->getTimestamp() - $now->getTimestamp() : null,
            'status' => $p->status,
            'priority' => $p->priority,
            'progress' => (int) $p->progress,
            'progress_mode' => $p->progress_mode,
            'notes' => $p->notes,
            'allow_late_tasks' => (bool) $p->allow_late_tasks,
            'tasks' => [
                'total' => (int) $counts->total, 'completed' => (int) $counts->completed, 'cancelled' => (int) $counts->cancelled, 'overdue' => (int) $counts->overdue,
                'pending' => (int) $counts->pending, 'blocked' => (int) $counts->blocked, 'in_progress' => (int) $counts->in_progress, 'not_started' => (int) $counts->not_started,
            ],
            'open_issues' => DB::table('project_issues')->where('project_id', $p->id)->whereNotIn('status', ['resolved', 'closed'])->count(),
            'budget' => [
                'currency' => $p->currency,
                'proposed' => $p->proposed_budget !== null ? Pm::money($p->proposed_budget) : null,
                'approved' => $approved,
                'spent' => Pm::money($spent),
                'remaining' => $approved !== null ? Pm::money($approved - $spent) : null,
                'utilization' => $approved ? round($spent / $approved * 100, 1) : null,
            ],
            'created_by' => $p->created_by ? (Pm::users([$p->created_by])[(int) $p->created_by] ?? null) : null,
            'created_at' => $p->created_at,
            'updated_at' => $p->updated_at,
            'completed_at' => $p->completed_at,
            'can' => [
                'manage' => $access['project_manage'],
                'manage_department' => $access['manage'],
                'report_issue' => $access['report_issue'],
                'suggest' => $access['report_issue'],
                'budget' => $access['budget'],
                'approve' => $access['approve'],
                'reports' => $access['reports'],
            ],
        ];
        if ($full) {
            $team = DB::table('project_members as m')->join('users as u', 'u.id', '=', 'm.user_id')->where('m.project_id', $p->id)->orderByRaw("m.role = 'leader' DESC")->orderBy('u.full_name')
                ->get(['u.id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.profile_image', 'm.role']);
            $out['team'] = $team->map(fn ($u) => Pm::user($u) + ['role' => $u->role])->all();
        }
        return $out;
    }

    private static function filtered(AuthContext $auth, array $f): Builder
    {
        $qb = DB::table('projects as p')->whereNull('p.deleted_at')->select('p.*');
        if (! empty($f['department_id'])) {
            Access::requireDepartment($auth, (int) $f['department_id']);
            $qb->where('p.department_id', $f['department_id']);
        } else {
            $depts = Access::visibleDepartmentIds($auth);
            // …plus projects of other departments where this person is on the team or responsible.
            $qb->where(fn ($w) => $w->whereIn('p.department_id', $depts ?: [0])
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('project_members as pm')->whereColumn('pm.project_id', 'p.id')->where('pm.user_id', $auth->id))
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('project_tasks as t')->join('project_task_assignees as ta', 'ta.task_id', '=', 't.id')->whereColumn('t.project_id', 'p.id')->where('ta.user_id', $auth->id)));
        }
        if (! empty($f['status'])) $qb->whereIn('p.status', (array) $f['status']);
        if (! empty($f['active'])) $qb->whereIn('p.status', ['planning', 'not_started', 'in_progress', 'on_hold']);
        if (! empty($f['priority'])) $qb->whereIn('p.priority', (array) $f['priority']);
        if (! empty($f['overdue'])) $qb->whereIn('p.status', ['planning', 'not_started', 'in_progress', 'on_hold'])->whereNotNull('p.deadline')->where('p.deadline', '<', Dates::sql(Dates::now()));
        if (! empty($f['leader_id'])) $qb->where('p.leader_id', $f['leader_id']);
        if (! empty($f['mine'])) {
            $qb->where(fn ($w) => $w->where('p.leader_id', $auth->id)
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('project_members as pm2')->whereColumn('pm2.project_id', 'p.id')->where('pm2.user_id', $auth->id)));
        }
        if (! empty($f['q'])) $qb->where('p.title', 'like', '%' . $f['q'] . '%');
        return $qb;
    }

    public static function list(AuthContext $auth, array $f, array $page): array
    {
        $qb = self::filtered($auth, $f)
            ->orderByRaw("FIELD(p.status, 'in_progress', 'not_started', 'planning', 'on_hold', 'completed', 'cancelled')")
            ->orderByRaw('p.deadline IS NULL')->orderBy('p.deadline')->orderByDesc('p.id');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($p) => self::serialize($p, $auth), $res['items']);
        return $res;
    }

    public static function detail(AuthContext $auth, int $id): array
    {
        [$p, $a] = Access::loadProject($auth, $id);
        return self::serialize($p, $auth, $a, true);
    }

    /** People who can be put on the department's projects and tasks (pickers). */
    public static function people(AuthContext $auth, int $departmentId): array
    {
        Access::requireDepartment($auth, $departmentId);
        $members = DB::table('user_departments')->where('department_id', $departmentId)->pluck('role', 'user_id')->all();
        $admins = array_flip(array_map('intval', DB::table('department_admins')->where('department_id', $departmentId)->pluck('user_id')->all()));
        $ids = array_unique(array_merge(array_map('intval', array_keys($members)), array_keys($admins)));
        $rows = DB::table('users')->whereIn('id', $ids ?: [0])->where('status', 'active')->whereNull('deleted_at')->orderBy('full_name')->get(['id', 'full_name', 'member_no', 'member_group', 'profile_image']);
        return $rows->map(fn ($u) => Pm::user($u) + [
            'role' => ($members[$u->id] ?? null) === 'leader' ? 'leader' : (isset($admins[(int) $u->id]) ? 'admin' : 'member'),
        ])->all();
    }

    /** Project Management home: departments the user can open, with counts and what they may do. */
    public static function overview(AuthContext $auth): array
    {
        $now = Dates::sql(Dates::now());
        $out = [];
        foreach (Access::departments($auth) as ['department' => $d, 'access' => $a]) {
            $stats = DB::table('projects')->where('department_id', $d->id)->whereNull('deleted_at')
                ->selectRaw("COUNT(*) as total, SUM(status IN ('planning','not_started','in_progress','on_hold')) as active, SUM(status = 'completed') as completed,
                    SUM(status IN ('planning','not_started','in_progress','on_hold') AND deadline IS NOT NULL AND deadline < ?) as overdue", [$now])->first();
            $out[] = [
                'department' => $d,
                'projects' => ['total' => (int) $stats->total, 'active' => (int) $stats->active, 'completed' => (int) $stats->completed, 'overdue' => (int) $stats->overdue],
                'open_issues' => DB::table('project_issues')->where('department_id', $d->id)->whereNotIn('status', ['resolved', 'closed'])->count(),
                'can' => ['manage' => $a['manage'], 'reports' => $a['reports'], 'approve' => $a['approve'], 'suggest' => $a['in_department'] || $a['manage']],
            ];
        }
        $my = DB::table('project_task_assignees as a')->join('project_tasks as t', 't.id', '=', 'a.task_id')->where('a.user_id', $auth->id)->whereNull('t.deleted_at')
            ->selectRaw("SUM(t.status IN ('not_started','pending','in_progress','blocked')) as open, SUM(t.status IN ('not_started','pending','in_progress','blocked') AND t.deadline IS NOT NULL AND t.deadline < ?) as overdue", [$now])->first();
        return [
            'departments' => $out,
            'my_tasks' => ['open' => (int) ($my->open ?? 0), 'overdue' => (int) ($my->overdue ?? 0)],
            'pending_approvals' => $auth->isSystem || $auth->can('projects.expenses.approve')
                ? DB::table('project_expenses')->where('status', 'pending')->count() + DB::table('project_budget_adjustments')->where('status', 'pending')->count()
                : 0,
        ];
    }

    private static function assertDates(?string $start, ?string $deadline): void
    {
        if ($start && $deadline && Dates::localDateOf(Dates::of($deadline)) < $start) throw ApiError::field('deadline', 'DEADLINE_BEFORE_START');
    }

    public static function create(array $actx, array $in): array
    {
        $auth = $actx['auth'];
        $deptId = (int) $in['department_id'];
        Access::requireDepartment($auth, $deptId, 'manage');
        $leader = $in['leader_id'] ?? null;
        if ($leader) Access::assertAssignable($deptId, [$leader]);
        $team = array_values(array_unique(array_map('intval', $in['team'] ?? [])));
        if ($team) Access::assertAssignable($deptId, $team);
        $deadline = isset($in['deadline']) ? Dates::sql(Dates::of($in['deadline'])) : null;
        self::assertDates($in['start_date'] ?? null, $deadline);
        $id = DB::transaction(function () use ($actx, $auth, $in, $deptId, $leader, $team, $deadline) {
            $id = DB::table('projects')->insertGetId([
                'department_id' => $deptId,
                'title' => $in['title'],
                'description' => $in['description'] ?? null,
                'leader_id' => $leader,
                'start_date' => $in['start_date'] ?? null,
                'deadline' => $deadline,
                'status' => $in['status'] ?? 'planning',
                'priority' => $in['priority'] ?? 'medium',
                'progress_mode' => $in['progress_mode'] ?? 'tasks',
                'progress' => ($in['progress_mode'] ?? 'tasks') === 'manual' ? (int) ($in['progress'] ?? 0) : 0,
                'notes' => $in['notes'] ?? null,
                'allow_late_tasks' => (bool) ($in['allow_late_tasks'] ?? false),
                'currency' => $in['currency'] ?? 'ETB',
                'proposed_budget' => $in['proposed_budget'] ?? null,
                'created_by' => $auth->id,
                'updated_by' => $auth->id,
            ]);
            $members = $team;
            if ($leader && ! in_array((int) $leader, $members, true)) $members[] = (int) $leader;
            foreach ($members as $uid) {
                DB::table('project_members')->insert(['project_id' => $id, 'user_id' => $uid, 'role' => (int) $uid === (int) $leader ? 'leader' : 'member', 'added_by' => $auth->id]);
            }
            Pm::log($actx, 'project.create', $id, ['after' => ['title' => $in['title'], 'status' => $in['status'] ?? 'planning', 'leader_id' => $leader, 'deadline' => $deadline, 'team' => $members]]);
            return $id;
        });
        $p = DB::table('projects')->where('id', $id)->first();
        Pm::notify(array_merge($team, $leader ? [$leader] : []), $auth->id, 'project.team.title', 'project.team.body', ['project' => $p->title], 'project', $id, "team:$id:join");
        return self::detail($auth, $id);
    }

    public static function update(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        [$p, $a] = Access::loadProject($auth, $id, 'project_manage');
        // Who leads the project and its status are department-level decisions.
        if ((array_key_exists('leader_id', $in) && (int) $in['leader_id'] !== (int) $p->leader_id) && ! $a['manage']) {
            throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only the department leader or administrators change the project leader');
        }
        $patch = array_intersect_key($in, array_flip(self::FIELDS));
        if (array_key_exists('deadline', $patch)) $patch['deadline'] = $patch['deadline'] ? Dates::sql(Dates::of($patch['deadline'])) : null;
        if (! empty($patch['leader_id'])) Access::assertAssignable((int) $p->department_id, [$patch['leader_id']]);
        self::assertDates(array_key_exists('start_date', $patch) ? $patch['start_date'] : Dates::toDateOnly($p->start_date), array_key_exists('deadline', $patch) ? $patch['deadline'] : $p->deadline);
        if (($in['progress_mode'] ?? $p->progress_mode) === 'manual' && array_key_exists('progress', $in)) $patch['progress'] = (int) $in['progress'];
        if (isset($patch['status']) && $patch['status'] === 'completed' && $p->status !== 'completed') $patch['completed_at'] = DB::raw('NOW()');
        if (isset($patch['status']) && $patch['status'] !== 'completed') $patch['completed_at'] = null;
        $before = [];
        foreach (array_keys($patch) as $k) $before[$k] = $p->{$k} ?? null;
        DB::transaction(function () use ($actx, $auth, $id, $p, $patch, $before, $in) {
            if (! $patch) return;
            $patch['updated_by'] = $auth->id;
            DB::table('projects')->where('id', $id)->update($patch);
            if (! empty($patch['leader_id'])) {
                DB::table('project_members')->where(['project_id' => $id, 'role' => 'leader'])->where('user_id', '!=', $patch['leader_id'])->update(['role' => 'member']);
                DB::table('project_members')->upsert([['project_id' => $id, 'user_id' => $patch['leader_id'], 'role' => 'leader', 'added_by' => $auth->id]], ['project_id', 'user_id'], ['role']);
            }
            $after = $patch;
            unset($after['updated_by']);
            if (isset($after['completed_at'])) $after['completed_at'] = $after['completed_at'] === null ? null : 'now';
            $action = isset($patch['status']) && $patch['status'] !== $p->status ? 'project.status' : 'project.update';
            Pm::log($actx, $action, $id, ['before' => $before, 'after' => $after, 'reason' => $in['reason'] ?? null]);
            if (isset($patch['progress_mode'])) self::recalculate($id);
        });
        if (isset($patch['status']) && $patch['status'] !== $p->status) {
            $team = DB::table('project_members')->where('project_id', $id)->pluck('user_id')->all();
            Pm::notify(array_merge($team, Access::managersOf((int) $p->department_id)), $auth->id, 'project.project_status.title', 'project.project_status.body',
                ['project' => $p->title, 'status' => \App\Mz\Support\T::t("project.status.{$patch['status']}")], 'project', $id, "pstatus:$id:" . Pm::stamp());
            try {
                Bot::postProject($p, 'project', $auth->id, \App\Mz\Support\T::t('bot.project', ['project' => $p->title, 'status' => \App\Mz\Support\T::t("project.status.{$patch['status']}"), 'actor' => $auth->fullName]));
            } catch (\Throwable) {
            }
        }
        return self::detail($auth, $id);
    }

    public static function delete(array $actx, int $id): void
    {
        [$p] = Access::loadProject($actx['auth'], $id, 'manage');
        DB::transaction(function () use ($actx, $id, $p) {
            DB::table('projects')->where('id', $id)->update(['deleted_at' => DB::raw('NOW()'), 'updated_by' => $actx['auth']->id]);
            $taskIds = DB::table('project_tasks')->where('project_id', $id)->pluck('id')->all();
            foreach ($taskIds as $tid) \App\Mz\Jobs\ScheduledNotifications::cancel('project_task', (int) $tid);
            Pm::log($actx, 'project.delete', $id, ['before' => ['title' => $p->title, 'status' => $p->status]]);
        });
    }

    /** Replace the team: [{user_id, role}] (the project leader always stays). */
    public static function setTeam(array $actx, int $id, array $members): array
    {
        $auth = $actx['auth'];
        [$p] = Access::loadProject($auth, $id, 'project_manage');
        $ids = array_values(array_unique(array_map(fn ($m) => (int) $m['user_id'], $members)));
        Access::assertAssignable((int) $p->department_id, $ids);
        $before = DB::table('project_members')->where('project_id', $id)->pluck('role', 'user_id')->all();
        DB::transaction(function () use ($actx, $auth, $id, $p, $members, $before) {
            DB::table('project_members')->where('project_id', $id)->delete();
            $rows = [];
            foreach ($members as $m) $rows[(int) $m['user_id']] = ['project_id' => $id, 'user_id' => (int) $m['user_id'], 'role' => 'member', 'added_by' => $auth->id];
            if ($p->leader_id) $rows[(int) $p->leader_id] = ['project_id' => $id, 'user_id' => (int) $p->leader_id, 'role' => 'leader', 'added_by' => $auth->id];
            if ($rows) DB::table('project_members')->insert(array_values($rows));
            Pm::log($actx, 'project.team', $id, ['before' => array_map('intval', array_keys($before)), 'after' => array_keys($rows)]);
        });
        $added = array_values(array_diff($ids, array_map('intval', array_keys($before))));
        Pm::notify($added, $auth->id, 'project.team.title', 'project.team.body', ['project' => $p->title], 'project', $id, "team:$id:" . Pm::stamp());
        return self::detail($auth, $id);
    }

    /**
     * Progress from the tasks (cancelled tasks do not count): 'tasks' = share of completed tasks,
     * 'weighted' = share of completed task weight; 'manual' keeps what the leader entered.
     */
    public static function recalculate(int $projectId): void
    {
        $p = DB::table('projects')->where('id', $projectId)->first(['progress_mode']);
        if (! $p || $p->progress_mode === 'manual') return;
        $r = DB::table('project_tasks')->where('project_id', $projectId)->whereNull('deleted_at')->where('status', '!=', 'cancelled')
            ->selectRaw("COUNT(*) as n, SUM(status = 'completed') as done, SUM(weight) as w, SUM(IF(status = 'completed', weight, 0)) as wdone")->first();
        $progress = $p->progress_mode === 'weighted'
            ? ((int) $r->w > 0 ? (int) floor((int) $r->wdone * 100 / (int) $r->w) : 0)
            : ((int) $r->n > 0 ? (int) floor((int) $r->done * 100 / (int) $r->n) : 0);
        DB::table('projects')->where('id', $projectId)->update(['progress' => $progress]);
    }

    /** Activity history of a project (the audit records). */
    public static function activity(AuthContext $auth, int $id, array $page): array
    {
        Access::loadProject($auth, $id);
        $qb = DB::table('audit_logs as l')->leftJoin('users as u', 'u.id', '=', 'l.actor_id')
            ->where(['l.entity_type' => 'project', 'l.entity_id' => $id])->where('l.is_hidden', false)
            ->orderByDesc('l.id')->select('l.id', 'l.action', 'l.metadata', 'l.created_at', 'u.id as actor_id', 'u.full_name as actor_name');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($r) => [
            'id' => (int) $r->id, 'action' => $r->action, 'details' => is_string($r->metadata) ? json_decode($r->metadata, true) : $r->metadata,
            'actor' => $r->actor_id ? ['id' => (int) $r->actor_id, 'full_name' => $r->actor_name] : null, 'created_at' => $r->created_at,
        ], $res['items']);
        return $res;
    }

    /**
     * One activity record with the real data behind it: who (role, department), the project, the
     * task / problem it concerns (current state), the before → after values (people as names), the
     * related people and what it caused (notifications, Task Bot messages).
     */
    public static function activityDetail(AuthContext $auth, int $id, int $logId): array
    {
        [$p] = Access::loadProject($auth, $id);
        $l = DB::table('audit_logs')->where(['id' => $logId, 'entity_type' => 'project', 'entity_id' => $id])->where('is_hidden', false)->first();
        if (! $l) throw \App\Mz\Support\ApiError::notFound('ACTIVITY_NOT_FOUND', 'Activity not found');
        $meta = is_string($l->metadata) ? (json_decode($l->metadata, true) ?: []) : (array) $l->metadata;
        $userIds = [];
        $collect = function ($v) use (&$userIds) {
            if (is_array($v) && $v && array_is_list($v) && count(array_filter($v, 'is_int')) === count($v)) foreach ($v as $u) $userIds[] = (int) $u;
        };
        foreach (['before', 'after', 'added', 'removed'] as $k) {
            if (! isset($meta[$k])) continue;
            $collect($meta[$k]);
            if (is_array($meta[$k])) foreach (['assignees', 'leader_id', 'assignee_id', 'members'] as $f) {
                if (isset($meta[$k][$f])) is_array($meta[$k][$f]) ? $collect($meta[$k][$f]) : $userIds[] = (int) $meta[$k][$f];
            }
        }
        $actor = $l->actor_id ? DB::table('users as u')->leftJoin('roles as r', 'r.id', '=', 'u.role_id')->where('u.id', $l->actor_id)
            ->first(['u.id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.account_type', 'r.name as role_name', 'r.is_hidden']) : null;
        $actorDepts = $actor ? DB::table('user_departments as ud')->join('departments as d', 'd.id', '=', 'ud.department_id')->where('ud.user_id', $actor->id)
            ->get(['d.id', 'd.name', 'ud.role'])->map(fn ($d) => ['id' => (int) $d->id, 'name' => $d->name, 'role' => $d->role])->all() : [];
        $actorAdminOf = $actor ? DB::table('department_admins as da')->join('departments as d', 'd.id', '=', 'da.department_id')->join('roles as r', 'r.id', '=', 'da.role_id')
            ->where('da.user_id', $actor->id)->get(['d.name as department', 'r.name as role'])->map(fn ($r) => (array) $r)->all() : [];
        $task = null;
        if (! empty($meta['task_id'])) {
            $t = DB::table('project_tasks')->where('id', $meta['task_id'])->first();
            if ($t) {
                $assignees = Access::assigneeIds((int) $t->id);
                $userIds = array_merge($userIds, $assignees);
                $program = $t->program_id ? DB::table('programs')->where('id', $t->program_id)->first(['id', 'title', 'starts_at']) : null;
                $task = [
                    'id' => (int) $t->id, 'title' => $t->title, 'status' => $t->status, 'status_reason' => $t->status_reason, 'pending_reason' => $t->pending_reason,
                    'priority' => $t->priority, 'progress' => (int) $t->progress, 'deadline' => $t->deadline, 'completed_at' => $t->completed_at,
                    'completion_note' => $t->completion_note, 'deleted' => (bool) $t->deleted_at, 'assignees' => array_values(Pm::users($assignees)),
                    'program' => $program ? ['id' => (int) $program->id, 'title' => $program->title, 'starts_at' => $program->starts_at] : null,
                ];
            }
        }
        $issue = null;
        if (! empty($meta['issue_id'])) {
            $i = DB::table('project_issues')->where('id', $meta['issue_id'])->first();
            if ($i) {
                $userIds = array_merge($userIds, array_filter([(int) $i->reporter_id, (int) $i->assignee_id]));
                $issue = ['id' => (int) $i->id, 'title' => $i->title, 'description' => $i->description, 'status' => $i->status, 'priority' => $i->priority,
                    'resolution' => $i->resolution, 'resolved_at' => $i->resolved_at, 'reporter' => Pm::users([(int) $i->reporter_id])[(int) $i->reporter_id] ?? null,
                    'assignee' => $i->assignee_id ? (Pm::users([(int) $i->assignee_id])[(int) $i->assignee_id] ?? null) : null];
            }
        }
        // What the event caused: notifications about the same task / project and Task Bot posts within two minutes.
        $from = Dates::of($l->created_at);
        $until = Dates::sql($from->modify('+2 minutes'));
        $since = Dates::sql($from->modify('-5 seconds'));
        $entity = $task ? ['project_task', $task['id']] : ['project', $id];
        $sent = DB::table('notifications as n')->join('users as u', 'u.id', '=', 'n.user_id')
            ->where(['n.entity_type' => $entity[0], 'n.entity_id' => $entity[1]])->whereBetween('n.created_at', [$since, $until])
            ->get(['u.id', 'u.full_name', 'n.title', 'n.delivery_status', 'n.email_status', 'n.read_at']);
        $bot = DB::table('chat_messages')->where('kind', 'task_bot')->where('department_id', $p->department_id)->whereBetween('created_at', [$since, $until])
            ->where(fn ($w) => $task ? $w->where('task_id', $task['id']) : $w->whereNull('task_id'))->orderBy('id')->get(['id', 'body', 'created_at']);
        $people = Pm::users($userIds);
        $names = function ($v) use ($people) {
            if (is_array($v) && $v && array_is_list($v) && count(array_filter($v, 'is_int')) === count($v)) return array_map(fn ($u) => $people[$u]['full_name'] ?? "#$u", $v);
            return $v;
        };
        $readable = fn ($side) => is_array($side) ? (array_is_list($side) ? $names($side) : array_map($names, $side)) : $side;
        $dept = DB::table('departments')->where('id', $p->department_id)->first(['id', 'name']);
        return [
            'id' => (int) $l->id,
            'action' => $l->action,
            'created_at' => $l->created_at,
            'source' => $meta['source'] ?? 'app',
            'reason' => $meta['reason'] ?? null,
            'actor' => $actor ? [
                'id' => (int) $actor->id, 'full_name' => $actor->full_name, 'member_id' => \App\Mz\Services\MemberIds::format($actor->member_no, $actor->member_group),
                'role' => $actor->is_hidden ? null : ($actor->role_name ?: ($actor->account_type === 'admin' ? 'admin' : 'member')),
                'departments' => $actorDepts, 'department_admin' => $actorAdminOf,
            ] : null,
            'project' => ['id' => (int) $p->id, 'title' => $p->title, 'status' => $p->status, 'department' => $dept ? ['id' => (int) $dept->id, 'name' => $dept->name] : null,
                'leader' => $p->leader_id ? (Pm::users([(int) $p->leader_id])[(int) $p->leader_id] ?? null) : null],
            'task' => $task,
            'issue' => $issue,
            'before' => $readable($meta['before'] ?? null),
            'after' => $readable($meta['after'] ?? null),
            'added' => $readable($meta['added'] ?? null),
            'removed' => $readable($meta['removed'] ?? null),
            'related_users' => array_values($people),
            'notifications' => $sent->map(fn ($n) => ['user' => ['id' => (int) $n->id, 'full_name' => $n->full_name], 'title' => $n->title, 'push' => $n->delivery_status, 'email' => $n->email_status, 'read' => (bool) $n->read_at])->all(),
            'bot_messages' => $bot->map(fn ($m) => ['id' => (int) $m->id, 'body' => $m->body, 'created_at' => $m->created_at])->all(),
        ];
    }
}
