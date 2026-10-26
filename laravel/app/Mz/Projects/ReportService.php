<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;

/**
 * Project and task reports for department leaders / administrators — factual counts only (no
 * performance scores). Filters come in categories (the app shows them that way):
 *   user:       user_ids (responsible), created_by
 *   project:    project_ids, project_status, project_priority, project_overdue
 *   task:       task_status, task_priority, overdue
 *   department: department_id (several only with projects.all_departments)
 *   date:       period today|week|month|custom + from / to (local dates, Ethiopian periods are
 *               converted by the app), date_field deadline|created|start|completed
 *   budget:     budget_status within|over|none
 *   completion: min_progress, max_progress (project progress)
 */
final class ReportService
{
    private static function departments(AuthContext $auth, array $f): array
    {
        if (! empty($f['department_id'])) {
            $a = Access::requireDepartment($auth, (int) $f['department_id'], 'view');
            if (! $a['reports']) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Reports are for department leaders and administrators');
            return [(int) $f['department_id']];
        }
        $ids = [];
        foreach (Access::departments($auth) as ['department' => $d, 'access' => $a]) {
            if ($a['reports']) $ids[] = (int) $d->id;
        }
        if (! $ids) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Reports are for department leaders and administrators');
        return $ids;
    }

    /** [from, to] as UTC SQL datetimes, or null. */
    private static function range(array $f): ?array
    {
        $today = Dates::todayLocal();
        $period = $f['period'] ?? (! empty($f['from']) || ! empty($f['to']) ? 'custom' : null);
        [$from, $to] = match ($period) {
            'today' => [$today, $today],
            'week' => [Dates::addDays($today, -((int) (new \DateTimeImmutable($today))->format('N') - 1)), $today],
            'month' => [substr($today, 0, 8) . '01', $today],
            'custom' => [$f['from'] ?? '1970-01-01', $f['to'] ?? '2999-12-31'],
            default => [null, null],
        };
        if (! $from) return null;
        return [Dates::sql(Dates::fromLocal("$from 00:00:00")), Dates::sql(Dates::fromLocal("$to 23:59:59"))];
    }

    private static function projectQuery(array $depts, array $f): Builder
    {
        $now = Dates::sql(Dates::now());
        $q = DB::table('projects as p')->whereNull('p.deleted_at')->whereIn('p.department_id', $depts);
        if (! empty($f['project_ids'])) $q->whereIn('p.id', $f['project_ids']);
        if (! empty($f['project_status'])) $q->whereIn('p.status', $f['project_status']);
        if (! empty($f['project_priority'])) $q->whereIn('p.priority', $f['project_priority']);
        if (! empty($f['project_overdue'])) $q->whereIn('p.status', ['planning', 'not_started', 'in_progress', 'on_hold'])->whereNotNull('p.deadline')->where('p.deadline', '<', $now);
        if (isset($f['min_progress'])) $q->where('p.progress', '>=', $f['min_progress']);
        if (isset($f['max_progress'])) $q->where('p.progress', '<=', $f['max_progress']);
        if (! empty($f['budget_status'])) {
            $spent = "(SELECT COALESCE(SUM(e.amount),0) FROM project_expenses e WHERE e.project_id = p.id AND e.status IN ('approved','recorded'))";
            match ($f['budget_status']) {
                'none' => $q->whereNull('p.approved_budget'),
                'over' => $q->whereNotNull('p.approved_budget')->whereRaw("$spent > p.approved_budget"),
                default => $q->whereNotNull('p.approved_budget')->whereRaw("$spent <= p.approved_budget"),
            };
        }
        return $q;
    }

    private static function taskQuery(array $depts, array $f): Builder
    {
        $now = Dates::sql(Dates::now());
        $q = DB::table('project_tasks as t')->whereNull('t.deleted_at')->whereIn('t.project_id', self::projectQuery($depts, $f)->select('p.id'));
        if (! empty($f['task_status'])) $q->whereIn('t.status', $f['task_status']);
        if (! empty($f['task_priority'])) $q->whereIn('t.priority', $f['task_priority']);
        if (! empty($f['overdue'])) $q->whereIn('t.status', Pm::OPEN_TASK)->whereNotNull('t.deadline')->where('t.deadline', '<', $now);
        if (! empty($f['user_ids'])) $q->whereExists(fn ($s) => $s->select(DB::raw(1))->from('project_task_assignees as a')->whereColumn('a.task_id', 't.id')->whereIn('a.user_id', $f['user_ids']));
        if (! empty($f['created_by'])) $q->whereIn('t.created_by', $f['created_by']);
        if ($r = self::range($f)) {
            $col = ['created' => 't.created_at', 'start' => 't.start_date', 'completed' => 't.completed_at'][$f['date_field'] ?? 'deadline'] ?? 't.deadline';
            $q->whereBetween($col, $col === 't.start_date' ? [substr($r[0], 0, 10), substr($r[1], 0, 10)] : $r);
        }
        return $q;
    }

    public static function summary(AuthContext $auth, array $f): array
    {
        $depts = self::departments($auth, $f);
        $now = Dates::sql(Dates::now());
        $projects = self::projectQuery($depts, $f)->select('p.*')->orderByRaw('p.deadline IS NULL')->orderBy('p.deadline')->get();
        $pStatus = array_fill_keys(Pm::PROJECT_STATUSES, 0);
        $pOverdue = 0;
        foreach ($projects as $p) {
            $pStatus[$p->status]++;
            if (in_array($p->status, ['planning', 'not_started', 'in_progress', 'on_hold'], true) && $p->deadline && Dates::of($p->deadline) < Dates::now()) $pOverdue++;
        }
        $tasks = self::taskQuery($depts, $f)->select('t.id', 't.status', 't.deadline', 't.project_id')->get();
        $tStatus = array_fill_keys(Pm::TASK_STATUSES, 0);
        $tOverdue = 0;
        foreach ($tasks as $t) {
            $tStatus[$t->status]++;
            if (Pm::isOverdue($t)) $tOverdue++;
        }
        // Per person: tasks they are responsible for (within the filters).
        $taskIds = $tasks->pluck('id')->all();
        $users = [];
        if ($taskIds) {
            $rows = DB::table('project_task_assignees as a')->join('project_tasks as t', 't.id', '=', 'a.task_id')->whereIn('a.task_id', $taskIds)
                ->groupBy('a.user_id')
                ->selectRaw("a.user_id, COUNT(*) as assigned, COUNT(DISTINCT t.project_id) as projects,
                    SUM(t.status = 'not_started') as not_started, SUM(t.status = 'pending') as pending, SUM(t.status = 'in_progress') as in_progress,
                    SUM(t.status = 'blocked') as blocked, SUM(t.status = 'completed') as completed, SUM(t.status = 'cancelled') as cancelled,
                    SUM(t.status IN ('not_started','pending','in_progress','blocked') AND t.deadline IS NOT NULL AND t.deadline < ?) as overdue", [$now])->get();
            $info = Pm::users($rows->pluck('user_id')->all());
            foreach ($rows as $r) {
                if (! empty($f['user_ids']) && ! in_array((int) $r->user_id, array_map('intval', $f['user_ids']), true)) continue;
                $users[] = ['user' => $info[(int) $r->user_id] ?? null, 'projects_involved' => (int) $r->projects, 'assigned' => (int) $r->assigned,
                    'not_started' => (int) $r->not_started, 'pending' => (int) $r->pending, 'in_progress' => (int) $r->in_progress, 'blocked' => (int) $r->blocked,
                    'completed' => (int) $r->completed, 'cancelled' => (int) $r->cancelled, 'overdue' => (int) $r->overdue];
            }
            usort($users, fn ($a, $b) => strcmp((string) ($a['user']['full_name'] ?? ''), (string) ($b['user']['full_name'] ?? '')));
        }
        $pids = $projects->pluck('id')->all();
        $spent = $pids ? DB::table('project_expenses')->whereIn('project_id', $pids)->whereIn('status', ['approved', 'recorded'])->groupBy('project_id')->pluck(DB::raw('SUM(amount)'), 'project_id')->all() : [];
        $pending = $pids ? (float) DB::table('project_expenses')->whereIn('project_id', $pids)->where('status', 'pending')->sum('amount') : 0;
        $byProjectTasks = [];
        foreach ($tasks as $t) {
            $byProjectTasks[$t->project_id]['total'] = ($byProjectTasks[$t->project_id]['total'] ?? 0) + 1;
            if ($t->status === 'completed') $byProjectTasks[$t->project_id]['completed'] = ($byProjectTasks[$t->project_id]['completed'] ?? 0) + 1;
            if (Pm::isOverdue($t)) $byProjectTasks[$t->project_id]['overdue'] = ($byProjectTasks[$t->project_id]['overdue'] ?? 0) + 1;
        }
        return [
            'departments' => $depts,
            'projects' => ['total' => $projects->count(), 'active' => $pStatus['planning'] + $pStatus['not_started'] + $pStatus['in_progress'] + $pStatus['on_hold'], 'by_status' => $pStatus, 'overdue' => $pOverdue],
            'tasks' => ['total' => $tasks->count(), 'by_status' => $tStatus, 'overdue' => $tOverdue],
            'users' => $users,
            'project_list' => $projects->map(fn ($p) => [
                'id' => (int) $p->id, 'title' => $p->title, 'department_id' => (int) $p->department_id, 'status' => $p->status, 'priority' => $p->priority, 'progress' => (int) $p->progress, 'deadline' => $p->deadline,
                'overdue' => in_array($p->status, ['planning', 'not_started', 'in_progress', 'on_hold'], true) && $p->deadline && Dates::of($p->deadline) < Dates::now(),
                'tasks' => ['total' => $byProjectTasks[$p->id]['total'] ?? 0, 'completed' => $byProjectTasks[$p->id]['completed'] ?? 0, 'overdue' => $byProjectTasks[$p->id]['overdue'] ?? 0],
                'budget' => ['currency' => $p->currency, 'approved' => $p->approved_budget !== null ? Pm::money($p->approved_budget) : null, 'spent' => Pm::money($spent[$p->id] ?? 0)],
            ])->all(),
            'budget' => [
                'approved' => Pm::money($projects->sum(fn ($p) => (float) ($p->approved_budget ?? 0))),
                'spent' => Pm::money(array_sum(array_map('floatval', $spent))),
                'pending' => Pm::money($pending),
            ],
        ];
    }

    /** The tasks behind the numbers (same filters), for drill-down. */
    public static function tasks(AuthContext $auth, array $f, array $page): array
    {
        $depts = self::departments($auth, $f);
        $qb = self::taskQuery($depts, $f)->select('t.*')->orderByRaw('t.deadline IS NULL')->orderBy('t.deadline');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($t) => TaskService::serialize($t, $auth), $res['items']);
        return $res;
    }
}
