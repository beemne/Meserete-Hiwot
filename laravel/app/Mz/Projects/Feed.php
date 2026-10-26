<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use Illuminate\Support\Facades\DB;

/**
 * Live updates. The hosting (cPanel / LiteSpeed PHP, process-limited) cannot keep a WebSocket
 * server running, so the app asks "what changed after event N?" every few seconds while a project
 * screen is open — one cheap indexed query, no extra process, no connection per task. The events
 * are the Project Management audit records the change already wrote, filtered to the projects the
 * caller may see. A WebSocket gateway can later push exactly these events without app changes to
 * the data model.
 */
final class Feed
{
    public static function events(AuthContext $auth, ?int $after, ?int $projectId, ?int $departmentId): array
    {
        $latest = (int) (DB::table('audit_logs')->max('id') ?? 0);
        if ($after === null) return ['cursor' => $latest, 'events' => []];
        $q = DB::table('audit_logs as l')->join('projects as p', 'p.id', '=', 'l.entity_id')
            ->where('l.entity_type', 'project')->where('l.id', '>', $after)->where('l.is_hidden', false)
            ->orderBy('l.id')->limit(200)
            ->select('l.id', 'l.action', 'l.entity_id', 'l.metadata', 'l.actor_id', 'l.created_at', 'p.department_id');
        if ($projectId) {
            Access::loadProject($auth, $projectId);
            $q->where('l.entity_id', $projectId);
        } elseif ($departmentId) {
            Access::requireDepartment($auth, $departmentId);
            $q->where('p.department_id', $departmentId);
        } else {
            $depts = Access::visibleDepartmentIds($auth);
            $q->where(fn ($w) => $w->whereIn('p.department_id', $depts ?: [0])
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('project_members as pm')->whereColumn('pm.project_id', 'p.id')->where('pm.user_id', $auth->id))
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('project_tasks as t')->join('project_task_assignees as ta', 'ta.task_id', '=', 't.id')->whereColumn('t.project_id', 'p.id')->where('ta.user_id', $auth->id)));
        }
        $rows = $q->get();
        $events = [];
        foreach ($rows as $r) {
            $m = is_string($r->metadata) ? json_decode($r->metadata, true) : (array) $r->metadata;
            $events[] = [
                'id' => (int) $r->id,
                'type' => $r->action,
                'project_id' => (int) $r->entity_id,
                'department_id' => (int) $r->department_id,
                'task_id' => isset($m['task_id']) ? (int) $m['task_id'] : null,
                'issue_id' => isset($m['issue_id']) ? (int) $m['issue_id'] : null,
                'actor_id' => $r->actor_id ? (int) $r->actor_id : null,
                'source' => $m['source'] ?? null,
                'at' => $r->created_at,
            ];
        }
        $more = $rows->count() === 200;
        // Everything up to $latest (read before the query) has been seen, visible or not.
        $last = $rows->count() ? (int) $rows->last()->id : $after;
        return ['cursor' => $more ? $last : max($last, $latest, $after), 'events' => $events, 'more' => $more];
    }
}
