<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/** Issues (problems) and suggestions (improvements) — kept separate — and their comments. */
final class FeedbackService
{
    // ------------------------------------------------------------------ issues
    private static function serializeIssue(object $i, AuthContext $auth): array
    {
        $users = Pm::users([$i->reporter_id, $i->assignee_id]);
        $p = DB::table('projects')->where('id', $i->project_id)->first(['id', 'title']);
        return [
            'id' => (int) $i->id,
            'project' => ['id' => (int) $p->id, 'title' => $p->title],
            'department_id' => (int) $i->department_id,
            'task_id' => $i->task_id ? (int) $i->task_id : null,
            'task_title' => $i->task_id ? DB::table('project_tasks')->where('id', $i->task_id)->value('title') : null,
            'title' => $i->title,
            'description' => $i->description,
            'priority' => $i->priority,
            'status' => $i->status,
            'reporter' => $i->reporter_id ? ($users[(int) $i->reporter_id] ?? null) : null,
            'assignee' => $i->assignee_id ? ($users[(int) $i->assignee_id] ?? null) : null,
            'due_date' => Dates::toDateOnly($i->due_date),
            'resolution' => $i->resolution,
            'resolved_at' => $i->resolved_at,
            'comments' => DB::table('project_comments')->where(['entity_type' => 'issue', 'entity_id' => $i->id])->count(),
            'files' => DB::table('project_files')->where('issue_id', $i->id)->count(),
            'created_at' => $i->created_at,
            'updated_at' => $i->updated_at,
        ];
    }

    public static function issues(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('project_issues as i')->join('projects as p', 'p.id', '=', 'i.project_id')->whereNull('p.deleted_at')->select('i.*');
        if (! empty($f['project_id'])) {
            Access::loadProject($auth, (int) $f['project_id']);
            $qb->where('i.project_id', $f['project_id']);
        } elseif (! empty($f['department_id'])) {
            Access::requireDepartment($auth, (int) $f['department_id']);
            $qb->where('i.department_id', $f['department_id']);
        } else {
            $qb->where(fn ($w) => $w->whereIn('i.department_id', Access::visibleDepartmentIds($auth) ?: [0])->orWhere('i.reporter_id', $auth->id)->orWhere('i.assignee_id', $auth->id));
        }
        if (! empty($f['status'])) $qb->whereIn('i.status', (array) $f['status']);
        if (! empty($f['open'])) $qb->whereNotIn('i.status', ['resolved', 'closed']);
        if (! empty($f['mine'])) $qb->where(fn ($w) => $w->where('i.reporter_id', $auth->id)->orWhere('i.assignee_id', $auth->id));
        $qb->orderByRaw("FIELD(i.status, 'open', 'under_review', 'assigned', 'in_progress', 'resolved', 'closed')")->orderByRaw("FIELD(i.priority, 'urgent', 'high', 'medium', 'low')")->orderByDesc('i.id');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($i) => self::serializeIssue($i, $auth), $res['items']);
        return $res;
    }

    public static function createIssue(array $actx, int $projectId, array $in): array
    {
        $auth = $actx['auth'];
        [$p] = Access::loadProject($auth, $projectId, 'report_issue');
        if (! empty($in['task_id']) && ! DB::table('project_tasks')->where(['id' => $in['task_id'], 'project_id' => $projectId])->whereNull('deleted_at')->exists()) throw ApiError::field('task_id', 'TASK_NOT_FOUND');
        $id = DB::transaction(function () use ($actx, $auth, $p, $in) {
            $id = DB::table('project_issues')->insertGetId([
                'project_id' => $p->id, 'task_id' => $in['task_id'] ?? null, 'department_id' => $p->department_id, 'reporter_id' => $auth->id,
                'title' => $in['title'], 'description' => $in['description'] ?? null, 'priority' => $in['priority'] ?? 'medium', 'due_date' => $in['due_date'] ?? null,
            ]);
            Pm::log($actx, 'project.issue.create', (int) $p->id, ['issue_id' => $id, 'task_id' => $in['task_id'] ?? null, 'after' => ['title' => $in['title'], 'priority' => $in['priority'] ?? 'medium']]);
            return $id;
        });
        Pm::notify(array_merge(Access::managersOf((int) $p->department_id), $p->leader_id ? [(int) $p->leader_id] : []), $auth->id, 'project.issue.title', 'project.issue.body',
            ['issue' => $in['title'], 'project' => $p->title, 'reporter' => $auth->fullName], 'project', (int) $p->id, "issue:$id:new");
        // The problem is also posted by the Task Bot into the department chat (once).
        $botText = T::t('bot.issue', ['issue' => $in['title'], 'project' => $p->title, 'reporter' => $auth->fullName, 'priority' => T::t('project.priority.' . ($in['priority'] ?? 'medium'))]);
        $task = ! empty($in['task_id']) ? DB::table('project_tasks')->where('id', $in['task_id'])->first() : null;
        try {
            $task ? Bot::post($task, 'issue', $auth->id, $botText, ['issue_id' => $id]) : Bot::postProject($p, 'issue', $auth->id, $botText, ['issue_id' => $id]);
        } catch (\Throwable) {
            // the issue itself is saved; the chat post is best effort
        }
        return self::issue($auth, $id);
    }

    private static function loadIssue(AuthContext $auth, int $id): array
    {
        $i = DB::table('project_issues')->where('id', $id)->first();
        if (! $i) throw ApiError::notFound('ISSUE_NOT_FOUND', 'Issue not found');
        $p = DB::table('projects')->where('id', $i->project_id)->whereNull('deleted_at')->first();
        if (! $p) throw ApiError::notFound('ISSUE_NOT_FOUND', 'Issue not found');
        $a = Access::project($auth, $p);
        $mine = (int) $i->reporter_id === $auth->id || (int) $i->assignee_id === $auth->id;
        if (! $a['project_view'] && ! $mine) throw ApiError::notFound('ISSUE_NOT_FOUND', 'Issue not found');
        return [$i, $p, $a, $mine];
    }

    public static function issue(AuthContext $auth, int $id): array
    {
        [$i] = self::loadIssue($auth, $id);
        return self::serializeIssue($i, $auth) + ['comment_list' => self::comments($auth, 'issue', $id)];
    }

    /** Managers review, assign and close; the assignee moves it along and records the resolution. */
    public static function updateIssue(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        [$i, $p, $a] = self::loadIssue($auth, $id);
        $assignee = (int) $i->assignee_id === $auth->id;
        $manage = $a['project_manage'];
        if (! $manage && ! $assignee) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only the assignee or a leader / administrator updates this issue');
        $patch = [];
        foreach (['title', 'description', 'priority', 'due_date', 'assignee_id'] as $k) {
            if (array_key_exists($k, $in)) {
                if (! $manage) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only a leader / administrator changes this');
                $patch[$k] = $in[$k];
            }
        }
        if (! empty($patch['assignee_id'])) Access::assertAssignable((int) $i->department_id, [$patch['assignee_id']]);
        if (array_key_exists('assignee_id', $patch) && $patch['assignee_id'] && ! isset($in['status']) && in_array($i->status, ['open', 'under_review'], true)) $patch['status'] = 'assigned';
        if (isset($in['status'])) {
            if (! $manage && in_array($in['status'], ['closed', 'under_review', 'open'], true)) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only a leader / administrator closes or reopens issues');
            $patch['status'] = $in['status'];
        }
        if (array_key_exists('resolution', $in)) $patch['resolution'] = $in['resolution'];
        if (isset($patch['status']) && $patch['status'] === 'resolved') {
            if (! trim((string) ($patch['resolution'] ?? $i->resolution))) throw ApiError::field('resolution', 'RESOLUTION_REQUIRED');
            $patch['resolved_at'] = Dates::sql(Dates::now());
        }
        if (! $patch) return self::issue($auth, $id);
        $before = [];
        foreach (array_keys($patch) as $k) $before[$k] = $i->{$k} ?? null;
        DB::transaction(function () use ($actx, $id, $i, $patch, $before) {
            DB::table('project_issues')->where('id', $id)->update($patch);
            $action = isset($patch['status']) && $patch['status'] !== $i->status ? (in_array($patch['status'], ['resolved', 'closed'], true) ? 'project.issue.resolved' : 'project.issue.status') : 'project.issue.update';
            Pm::log($actx, $action, (int) $i->project_id, ['issue_id' => $id, 'before' => $before, 'after' => $patch]);
        });
        $stamp = Pm::stamp();
        if (! empty($patch['assignee_id']) && (int) $patch['assignee_id'] !== (int) $i->assignee_id) {
            Pm::notify([(int) $patch['assignee_id']], $auth->id, 'project.issue_assigned.title', 'project.issue_assigned.body', ['issue' => $i->title, 'project' => $p->title], 'project', (int) $p->id, "issue:$id:assign:$stamp");
        }
        if (isset($patch['status']) && $patch['status'] !== $i->status) {
            Pm::notify(array_merge([(int) $i->reporter_id, (int) ($patch['assignee_id'] ?? $i->assignee_id)], Access::managersOf((int) $i->department_id)), $auth->id, 'project.issue_status.title', 'project.issue_status.body',
                ['issue' => $i->title, 'status' => T::t("issue.status.{$patch['status']}")], 'project', (int) $p->id, "issue:$id:status:$stamp");
            if (in_array($patch['status'], ['resolved', 'closed'], true)) {
                $botText = T::t('bot.resolved', ['issue' => $i->title, 'project' => $p->title, 'resolution' => (string) ($patch['resolution'] ?? $i->resolution ?? ''), 'actor' => $auth->fullName]);
                $task = $i->task_id ? DB::table('project_tasks')->where('id', $i->task_id)->first() : null;
                try {
                    $task ? Bot::post($task, 'resolved', $auth->id, $botText, ['issue_id' => $id]) : Bot::postProject($p, 'resolved', $auth->id, $botText, ['issue_id' => $id]);
                } catch (\Throwable) {
                }
            }
        }
        return self::issue($auth, $id);
    }

    // ------------------------------------------------------------------ comments
    public static function comments(AuthContext $auth, string $type, int $id): array
    {
        return DB::table('project_comments as c')->leftJoin('users as u', 'u.id', '=', 'c.user_id')->where(['c.entity_type' => $type, 'c.entity_id' => $id])->orderBy('c.id')
            ->get(['c.id', 'c.body', 'c.created_at', 'u.id as uid', 'u.full_name', 'u.member_no', 'u.member_group', 'u.profile_image'])
            ->map(fn ($c) => ['id' => (int) $c->id, 'body' => $c->body, 'created_at' => $c->created_at, 'user' => $c->uid ? Pm::user((object) ['id' => $c->uid, 'full_name' => $c->full_name, 'member_no' => $c->member_no, 'member_group' => $c->member_group, 'profile_image' => $c->profile_image]) : null, 'mine' => (int) $c->uid === $auth->id])->all();
    }

    public static function addComment(array $actx, string $type, int $id, string $body): array
    {
        $auth = $actx['auth'];
        if ($type === 'issue') {
            [$i, $p] = self::loadIssue($auth, $id);
            $projectId = (int) $p->id;
        } elseif ($type === 'suggestion') {
            [$s] = self::loadSuggestion($auth, $id);
            $projectId = $s->project_id ? (int) $s->project_id : null;
            if (! $projectId) throw ApiError::badRequest('NOT_SUPPORTED', 'Department suggestions are discussed in the department chat');
        } else {
            [$t] = Access::loadTask($auth, $id);
            $projectId = (int) $t->project_id;
        }
        $cid = DB::table('project_comments')->insertGetId(['project_id' => $projectId, 'entity_type' => $type, 'entity_id' => $id, 'user_id' => $auth->id, 'body' => mb_substr(trim($body), 0, 4000)]);
        Pm::log($actx, 'project.comment', $projectId, [$type . '_id' => $id, 'comment_id' => $cid]);
        return self::comments($auth, $type, $id);
    }

    // ------------------------------------------------------------------ suggestions
    private static function serializeSuggestion(object $s): array
    {
        $users = Pm::users([$s->author_id, $s->reviewed_by]);
        return [
            'id' => (int) $s->id,
            'department_id' => (int) $s->department_id,
            'project' => $s->project_id ? DB::table('projects')->where('id', $s->project_id)->first(['id', 'title']) : null,
            'title' => $s->title,
            'body' => $s->body,
            'status' => $s->status,
            'author' => $s->author_id ? ($users[(int) $s->author_id] ?? null) : null,
            'review_note' => $s->review_note,
            'reviewed_by' => $s->reviewed_by ? ($users[(int) $s->reviewed_by] ?? null) : null,
            'reviewed_at' => $s->reviewed_at,
            'converted_task_id' => $s->converted_task_id ? (int) $s->converted_task_id : null,
            'created_at' => $s->created_at,
        ];
    }

    private static function loadSuggestion(AuthContext $auth, int $id): array
    {
        $s = DB::table('project_suggestions')->where('id', $id)->first();
        if (! $s) throw ApiError::notFound('SUGGESTION_NOT_FOUND', 'Suggestion not found');
        $a = Access::department($auth, (int) $s->department_id);
        $manage = $a['manage'];
        if ($s->project_id) {
            $p = DB::table('projects')->where('id', $s->project_id)->first();
            if ($p) $manage = Access::project($auth, $p)['project_manage'];
        }
        if (! $a['view'] && (int) $s->author_id !== $auth->id) throw ApiError::notFound('SUGGESTION_NOT_FOUND', 'Suggestion not found');
        return [$s, $manage];
    }

    public static function suggestions(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('project_suggestions as s')->select('s.*');
        if (! empty($f['project_id'])) {
            Access::loadProject($auth, (int) $f['project_id']);
            $qb->where('s.project_id', $f['project_id']);
        } elseif (! empty($f['department_id'])) {
            Access::requireDepartment($auth, (int) $f['department_id']);
            $qb->where('s.department_id', $f['department_id']);
        } else {
            $qb->where(fn ($w) => $w->whereIn('s.department_id', Access::visibleDepartmentIds($auth) ?: [0])->orWhere('s.author_id', $auth->id));
        }
        if (! empty($f['status'])) $qb->whereIn('s.status', (array) $f['status']);
        $qb->orderByRaw("FIELD(s.status, 'submitted', 'under_review', 'accepted', 'converted', 'rejected')")->orderByDesc('s.id');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($s) => self::serializeSuggestion($s), $res['items']);
        return $res;
    }

    public static function suggestion(AuthContext $auth, int $id): array
    {
        [$s, $manage] = self::loadSuggestion($auth, $id);
        return self::serializeSuggestion($s) + ['can_review' => $manage, 'comment_list' => $s->project_id ? self::comments($auth, 'suggestion', $id) : []];
    }

    public static function createSuggestion(array $actx, array $in): array
    {
        $auth = $actx['auth'];
        if (! empty($in['project_id'])) {
            [$p] = Access::loadProject($auth, (int) $in['project_id'], 'report_issue');
            $deptId = (int) $p->department_id;
        } else {
            $deptId = (int) ($in['department_id'] ?? 0);
            $a = Access::requireDepartment($auth, $deptId);
            if (! $a['in_department'] && ! $a['manage']) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only department members make suggestions');
        }
        $id = DB::table('project_suggestions')->insertGetId(['department_id' => $deptId, 'project_id' => $in['project_id'] ?? null, 'author_id' => $auth->id, 'title' => $in['title'], 'body' => $in['body'] ?? null]);
        if (! empty($in['project_id'])) Pm::log($actx, 'project.suggestion.create', (int) $in['project_id'], ['suggestion_id' => $id, 'after' => ['title' => $in['title']]]);
        Pm::notify(Access::managersOf($deptId), $auth->id, 'project.suggestion.title', 'project.suggestion.body', ['title' => $in['title'], 'author' => $auth->fullName], 'project_suggestion', $id, "sugg:$id:new");
        return self::suggestion($auth, $id);
    }

    /** Review: under_review / accepted / rejected (with a note). */
    public static function reviewSuggestion(array $actx, int $id, string $status, ?string $note): array
    {
        $auth = $actx['auth'];
        [$s, $manage] = self::loadSuggestion($auth, $id);
        if (! $manage) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only a leader / administrator reviews suggestions');
        if ($s->status === 'converted') throw ApiError::conflict('SUGGESTION_CONVERTED', 'This suggestion is already a task');
        DB::table('project_suggestions')->where('id', $id)->update(['status' => $status, 'review_note' => $note, 'reviewed_by' => $auth->id, 'reviewed_at' => DB::raw('NOW()')]);
        if ($s->project_id) Pm::log($actx, 'project.suggestion.' . $status, (int) $s->project_id, ['suggestion_id' => $id, 'before' => ['status' => $s->status], 'after' => ['status' => $status], 'reason' => $note]);
        Pm::notify([(int) $s->author_id], $auth->id, 'project.suggestion_reviewed.title', 'project.suggestion_reviewed.body', ['title' => $s->title, 'status' => T::t("suggestion.status.$status")], 'project_suggestion', $id, "sugg:$id:$status:" . Pm::stamp());
        return self::suggestion($auth, $id);
    }

    /** Turn a suggestion into a task of a project; the suggestion and its history stay. */
    public static function convertSuggestion(array $actx, int $id, int $projectId, array $task): array
    {
        $auth = $actx['auth'];
        [$s, $manage] = self::loadSuggestion($auth, $id);
        if ($s->status === 'converted') throw ApiError::conflict('SUGGESTION_CONVERTED', 'This suggestion is already a task');
        [$p] = Access::loadProject($auth, $projectId, 'project_manage');
        if ((int) $p->department_id !== (int) $s->department_id) throw ApiError::field('project_id', 'PROJECT_OTHER_DEPARTMENT');
        $task += ['title' => $s->title, 'description' => $s->body];
        $created = TaskService::create($actx, $projectId, $task, $id);
        DB::table('project_suggestions')->where('id', $id)->update(['status' => 'converted', 'converted_task_id' => $created['id'], 'reviewed_by' => $auth->id, 'reviewed_at' => DB::raw('NOW()'), 'project_id' => $s->project_id ?? $projectId]);
        Pm::log($actx, 'project.suggestion.converted', $projectId, ['suggestion_id' => $id, 'task_id' => $created['id'], 'before' => ['status' => $s->status]]);
        Pm::notify([(int) $s->author_id], $auth->id, 'project.suggestion_reviewed.title', 'project.suggestion_reviewed.body', ['title' => $s->title, 'status' => T::t('suggestion.status.converted')], 'project_task', (int) $created['id'], "sugg:$id:converted");
        return ['suggestion' => self::suggestion($auth, $id), 'task' => $created];
    }
}
