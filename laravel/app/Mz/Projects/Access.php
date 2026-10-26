<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;

/**
 * Who may do what in Department Project Management. Every rule is checked here, on the server, for
 * every request (screens, the chat Task Bot, offline sync and the change feed all come through it).
 *
 * Department scope — permissions are evaluated PER DEPARTMENT: a member who administers department A
 * gets nothing in department B from that role.
 *  - in department: member (user_departments), its leader, or one of its department administrators;
 *  - view:   anyone in the department, Finance approvers (read-only, to review money), and holders of
 *            projects.all_departments;
 *  - manage: the department leader; a department administrator of THIS department whose role (or a
 *            direct grant) has projects.manage; an account administrator in the department with
 *            projects.manage; anyone with projects.all_departments + projects.manage.
 *    Department Leader and Department Admin therefore have the same control.
 *  - reports: managers, and holders of projects.reports in the department (or all departments).
 *  - approve money: projects.expenses.approve (Finance, across departments).
 * Project scope — the project leader manages that project's tasks and team; team members see it.
 * Task scope — the responsible people update its status, progress and notes.
 */
final class Access
{
    /** @var array<string,array> per-request cache */
    private static array $cache = [];

    public static function reset(): void
    {
        self::$cache = [];
    }

    /** Permission keys that apply to this person inside one department. */
    private static function deptPermissions(AuthContext $auth, int $departmentId): array
    {
        if ($auth->isSystem) return array_keys($auth->permissions);
        // Account administrators: their role + direct grants (already revocation-filtered).
        if ($auth->accountType === 'admin') return array_keys($auth->permissions);
        $fromRoles = DB::table('department_admins as da')->join('role_permissions as rp', 'rp.role_id', '=', 'da.role_id')->join('roles as r', 'r.id', '=', 'da.role_id')
            ->join('permissions as p', 'p.id', '=', 'rp.permission_id')
            ->where(['da.user_id' => $auth->id, 'da.department_id' => $departmentId])->where('r.is_active', true)->pluck('p.key')->all();
        $direct = DB::table('user_permissions as up')->join('permissions as p', 'p.id', '=', 'up.permission_id')->where('up.user_id', $auth->id)->pluck('p.key')->all();
        $revoked = DB::table('user_permission_revocations as r')->join('permissions as p', 'p.id', '=', 'r.permission_id')->where('r.user_id', $auth->id)->pluck('p.key')->all();
        return array_values(array_diff(array_unique(array_merge($fromRoles, $direct)), $revoked));
    }

    /**
     * @return array{department_id:int, member:bool, leader:bool, dept_admin:bool, in_department:bool,
     *   view:bool, manage:bool, reports:bool, approve:bool, all:bool}
     */
    public static function department(AuthContext $auth, int $departmentId): array
    {
        $key = "{$auth->id}:$departmentId";
        if (isset(self::$cache[$key])) return self::$cache[$key];
        $ud = DB::table('user_departments')->where(['user_id' => $auth->id, 'department_id' => $departmentId])->first(['role']);
        $member = (bool) $ud;
        $leader = $ud && $ud->role === 'leader';
        $deptAdmin = DB::table('department_admins')->where(['user_id' => $auth->id, 'department_id' => $departmentId])->exists();
        $in = $member || $leader || $deptAdmin;
        $perms = array_flip(self::deptPermissions($auth, $departmentId));
        $all = $auth->isSystem || $auth->can('projects.all_departments');
        $approve = $auth->isSystem || $auth->can('projects.expenses.approve');
        $manage = $auth->isSystem || $leader || ($in && isset($perms['projects.manage'])) || ($all && $auth->can('projects.manage'));
        $reports = $manage || ($in && isset($perms['projects.reports'])) || ($all && $auth->can('projects.reports'));
        $view = $all || $in || $approve;
        return self::$cache[$key] = [
            'department_id' => $departmentId, 'member' => $member, 'leader' => $leader, 'dept_admin' => $deptAdmin, 'in_department' => $in,
            'view' => $view, 'manage' => $manage, 'reports' => $reports, 'approve' => $approve, 'all' => $all,
        ];
    }

    /** Departments this person can open in Project Management. */
    public static function departments(AuthContext $auth): array
    {
        $q = DB::table('departments')->where('is_active', true)->orderBy('sort_order')->orderBy('id')->select('id', 'name', 'name_en');
        $out = [];
        foreach ($q->get() as $d) {
            $a = self::department($auth, (int) $d->id);
            if ($a['view']) $out[] = ['department' => $d, 'access' => $a];
        }
        return $out;
    }

    /** @return int[] ids of departments visible to this person */
    public static function visibleDepartmentIds(AuthContext $auth): array
    {
        return array_map(fn ($d) => (int) $d['department']->id, self::departments($auth));
    }

    public static function requireDepartment(AuthContext $auth, int $departmentId, string $need = 'view'): array
    {
        if (! DB::table('departments')->where(['id' => $departmentId, 'is_active' => true])->exists()) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
        $a = self::department($auth, $departmentId);
        if (! $a[$need]) {
            // Someone outside the department learns nothing about it.
            if (! $a['view']) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
            throw ApiError::forbidden('PROJECT_FORBIDDEN', 'You are not allowed to do this in this department');
        }
        return $a;
    }

    // ------------------------------------------------------------------ project / task scope
    public static function project(AuthContext $auth, object $p): array
    {
        $a = self::department($auth, (int) $p->department_id);
        $role = DB::table('project_members')->where(['project_id' => $p->id, 'user_id' => $auth->id])->value('role');
        $isLeader = (int) $p->leader_id === $auth->id || $role === 'leader';
        $assigned = DB::table('project_task_assignees as a')->join('project_tasks as t', 't.id', '=', 'a.task_id')
            ->where(['t.project_id' => $p->id, 'a.user_id' => $auth->id])->whereNull('t.deleted_at')->exists();
        $manage = $a['manage'] || $isLeader;
        $view = $a['view'] || $role !== null || $assigned;
        return $a + [
            'project_view' => $view,
            'project_manage' => $manage,
            'project_leader' => $isLeader,
            'team_member' => $role !== null,
            // Members of the department (and the team) report problems and suggest improvements.
            'report_issue' => $view && ($a['in_department'] || $role !== null || $assigned || $manage),
            'budget' => $manage,
        ];
    }

    public static function loadProject(AuthContext $auth, int $id, string $need = 'project_view'): array
    {
        $p = DB::table('projects')->where('id', $id)->whereNull('deleted_at')->first();
        if (! $p) throw ApiError::notFound('PROJECT_NOT_FOUND', 'Project not found');
        $a = self::project($auth, $p);
        if (! $a['project_view']) throw ApiError::notFound('PROJECT_NOT_FOUND', 'Project not found');
        if (! $a[$need]) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'You are not allowed to do this in this project');
        return [$p, $a];
    }

    /** @return int[] */
    public static function assigneeIds(int $taskId): array
    {
        return array_map('intval', DB::table('project_task_assignees')->where('task_id', $taskId)->pluck('user_id')->all());
    }

    public static function task(AuthContext $auth, object $t): array
    {
        $p = DB::table('projects')->where('id', $t->project_id)->first();
        $a = self::project($auth, $p);
        $responsible = in_array($auth->id, self::assigneeIds((int) $t->id), true);
        return $a + [
            'responsible' => $responsible,
            // Status / progress: the responsible people, the department leader, authorized
            // department administrators and the project leader — nobody else (chat Task Bot included).
            'update_status' => $responsible || $a['project_manage'],
            'edit' => $a['project_manage'],
        ];
    }

    public static function loadTask(AuthContext $auth, int $id, ?string $need = null): array
    {
        $t = DB::table('project_tasks')->where('id', $id)->whereNull('deleted_at')->first();
        if (! $t) throw ApiError::notFound('TASK_NOT_FOUND', 'Task not found');
        $a = self::task($auth, $t);
        if (! $a['project_view'] && ! $a['responsible']) throw ApiError::notFound('TASK_NOT_FOUND', 'Task not found');
        if ($need && ! $a[$need]) {
            throw ApiError::forbidden($need === 'update_status' ? 'TASK_UPDATE_FORBIDDEN' : 'PROJECT_FORBIDDEN', 'You are not authorized to update this task');
        }
        return [$t, $a];
    }

    /** Department leaders and the department administrators who manage its projects (for notifications). */
    public static function managersOf(int $departmentId): array
    {
        $leaders = DB::table('user_departments')->where(['department_id' => $departmentId, 'role' => 'leader'])->pluck('user_id')->all();
        $pid = DB::table('permissions')->where('key', 'projects.manage')->value('id');
        $admins = DB::table('department_admins as da')->join('role_permissions as rp', 'rp.role_id', '=', 'da.role_id')->join('roles as r', 'r.id', '=', 'da.role_id')
            ->where('da.department_id', $departmentId)->where('rp.permission_id', $pid)->where('r.is_active', true)->pluck('da.user_id')->all();
        $ids = array_unique(array_map('intval', array_merge($leaders, $admins)));
        if (! $ids) return [];
        $revoked = DB::table('user_permission_revocations')->where('permission_id', $pid)->pluck('user_id')->all();
        $leaderIds = array_map('intval', $leaders);
        // A revocation removes an admin's role permission, never a leader's leadership.
        $ids = array_values(array_filter($ids, fn ($id) => in_array($id, $leaderIds, true) || ! in_array($id, array_map('intval', $revoked), true)));
        return array_map('intval', DB::table('users')->whereIn('id', $ids)->where('status', 'active')->whereNull('deleted_at')->pluck('id')->all());
    }

    /** Can this user be put on a project / task of the department? (members, leaders, its admins, admins) */
    public static function assertAssignable(int $departmentId, array $userIds): void
    {
        $ids = array_values(array_unique(array_map('intval', $userIds)));
        if (! $ids) return;
        $ok = DB::table('users as u')->whereIn('u.id', $ids)->where('u.status', 'active')->whereNull('u.deleted_at')
            ->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('roles as hr')->whereColumn('hr.id', 'u.role_id')->where('hr.is_hidden', true))
            ->where(fn ($w) => $w->whereExists(fn ($s) => $s->select(DB::raw(1))->from('user_departments as ud')->whereColumn('ud.user_id', 'u.id')->where('ud.department_id', $departmentId))
                ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('department_admins as da')->whereColumn('da.user_id', 'u.id')->where('da.department_id', $departmentId))
                ->orWhere('u.account_type', 'admin'))
            ->pluck('u.id')->all();
        if (count($ok) !== count($ids)) throw ApiError::field('user_ids', 'USER_NOT_IN_DEPARTMENT');
    }
}
