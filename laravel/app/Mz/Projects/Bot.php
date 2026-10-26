<?php

namespace App\Mz\Projects;

use App\Mz\Services\Chat;
use App\Mz\Support\ApiError;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * The Task Bot of the existing department chat. Its messages are ordinary chat_messages rows
 * (kind 'task_bot') in the department's group conversation that point at the real task; the
 * buttons under them call action(), which goes through TaskService::changeStatus — the same record
 * and the same authorization as the Project Management screens. The bot never keeps task data of
 * its own and is never a way around the rules: anyone else gets "not authorized".
 */
final class Bot
{
    /** "What is the status?" → the answers the responsible people / leaders can press. */
    public const ACTIONS = ['pending', 'in_progress', 'blocked', 'completed'];
    /** Messages that carry the status buttons (the rest only inform). */
    private const ASKING = ['reminder', 'request', 'overdue', 'assigned'];

    /**
     * Post a bot message about a task. kind: reminder | request | overdue | assigned (with status
     * buttons) or updated | reassigned | status | completed | issue | resolved (information).
     */
    public static function post(object $t, string $kind, int $senderId, string $text, array $extra = []): int
    {
        $data = ['kind' => $kind, 'task_id' => (int) $t->id, 'project_id' => (int) $t->project_id, 'actions' => in_array($kind, self::ASKING, true) ? self::ACTIONS : []] + $extra;
        return (int) DB::table('chat_messages')->insertGetId([
            'department_id' => $t->department_id,
            'thread_key' => Chat::GROUP,
            // The person who triggered it (or the task's creator for scheduled reminders) is the
            // technical sender; the app shows the message as the Task Bot.
            'sender_id' => $senderId,
            'kind' => 'task_bot',
            'body' => mb_substr($text, 0, 4000),
            'task_id' => $t->id,
            'bot_data' => json_encode($data, JSON_UNESCAPED_UNICODE),
        ]);
    }

    private static function params(object $t): array
    {
        $assignees = Access::assigneeIds((int) $t->id);
        return ['task' => $t->title, 'names' => Pm::names($assignees), 'due' => Pm::localTime($t->deadline), 'status' => T::t("task.status.{$t->status}")];
    }

    /** A project-level message (project status, problems without a task) in the department chat. */
    public static function postProject(object $p, string $kind, int $senderId, string $text, array $extra = []): int
    {
        if (! $p->department_id || ! $senderId) return 0;
        return (int) DB::table('chat_messages')->insertGetId([
            'department_id' => $p->department_id,
            'thread_key' => Chat::GROUP,
            'sender_id' => $senderId,
            'kind' => 'task_bot',
            'body' => mb_substr($text, 0, 4000),
            'task_id' => null,
            'bot_data' => json_encode(['kind' => $kind, 'project_id' => (int) $p->id, 'actions' => []] + $extra, JSON_UNESCAPED_UNICODE),
        ]);
    }

    /**
     * A task event from the normal Project Management flow, posted once into the department chat.
     * Never fails the action that caused it.
     */
    public static function event(object $t, string $kind, int $senderId, array $params = []): void
    {
        try {
            $p = DB::table('projects')->where('id', $t->project_id)->first(['title']);
            self::post($t, $kind, $senderId, T::t("bot.$kind", self::params($t) + ['project' => $p->title ?? ''] + $params));
        } catch (\Throwable $e) {
            \Illuminate\Support\Facades\Log::warning('task bot post failed', ['task' => $t->id ?? null, 'error' => $e->getMessage()]);
        }
    }

    /** Scheduled reminder (from ProjectReminders). */
    public static function reminder(object $t, string $slot): void
    {
        $sender = (int) ($t->created_by ?: (Access::assigneeIds((int) $t->id)[0] ?? 0));
        if (! $sender) return;
        $key = match ($slot) { 'overdue' => 'bot.overdue', 'due' => 'bot.due', default => 'bot.reminder' };
        $left = ['d3' => 3, 'd2' => 2, 'd1' => 1][$slot] ?? 0;
        self::post($t, $slot === 'overdue' ? 'overdue' : 'reminder', $sender, T::t($key, self::params($t) + ['days' => $left]), ['slot' => $slot]);
    }

    /** A leader / administrator asks the responsible people for the current status. */
    public static function requestStatus(array $actx, int $taskId): array
    {
        $auth = $actx['auth'];
        [$t] = Access::loadTask($auth, $taskId, 'edit');
        if (! in_array($t->status, Pm::OPEN_TASK, true)) throw ApiError::conflict('TASK_CLOSED', 'This task is closed');
        $id = self::post($t, 'request', $auth->id, T::t('bot.request', self::params($t)));
        Pm::log($actx, 'project.task.status_request', (int) $t->project_id, ['task_id' => $taskId, 'message_id' => $id]);
        Pm::notify(Access::assigneeIds($taskId), $auth->id, 'task.reminder.soon.title', 'task.reminder.soon.body',
            ['task' => $t->title, 'due' => Pm::localTime($t->deadline), 'status' => T::t("task.status.{$t->status}")], 'chat', (int) $t->department_id, "botreq:$id");
        return ['message_id' => $id];
    }

    /**
     * A button under a bot message. The caller must be able to read the chat AND be allowed to
     * update the task (responsible person, department leader / admin, project leader).
     */
    public static function action(array $actx, int $departmentId, int $messageId, array $in): array
    {
        $auth = $actx['auth'];
        Chat::access($auth, $departmentId);
        $m = DB::table('chat_messages')->where(['id' => $messageId, 'department_id' => $departmentId, 'kind' => 'task_bot'])->whereNull('deleted_at')->first();
        if (! $m || ! $m->task_id) throw ApiError::notFound('MESSAGE_NOT_FOUND', 'Message not found');
        $t = DB::table('project_tasks')->where('id', $m->task_id)->whereNull('deleted_at')->first();
        if (! $t) throw ApiError::notFound('TASK_NOT_FOUND', 'Task not found');
        $a = Access::task($auth, $t);
        if (! $a['update_status']) throw ApiError::forbidden('TASK_UPDATE_FORBIDDEN', 'You are not authorized to update this task.');
        $out = TaskService::changeStatus(array_merge($actx, ['source' => 'chat_bot']), (int) $t->id, $in);
        $fresh = DB::table('project_tasks')->where('id', $t->id)->first();
        $reason = $fresh->status_reason ? T::t('project.reason.suffix', ['reason' => $fresh->status_reason]) : '';
        $confirm = self::post($fresh, 'updated', $auth->id, T::t('bot.updated', ['task' => $fresh->title, 'status' => T::t("task.status.{$fresh->status}"), 'reason' => $reason, 'actor' => $auth->fullName]));
        return ['task' => $out['task'], 'message_id' => $confirm];
    }

    /** @var array<string,bool> */
    private static array $canCache = [];

    /** What the app needs to draw a bot message (the task's CURRENT state, from the real record). */
    public static function payload(object $m, \App\Mz\Auth\AuthContext $viewer): ?array
    {
        $data = $m->bot_data ? json_decode($m->bot_data, true) : [];
        $t = $m->task_id ? DB::table('project_tasks')->where('id', $m->task_id)->first() : null;
        if (! $t) return ['kind' => $data['kind'] ?? 'reminder', 'task' => null, 'actions' => [], 'can_update' => false];
        $key = "{$viewer->id}:{$t->id}";
        // Only a hint for drawing the buttons — the server checks again on every press.
        self::$canCache[$key] ??= ! $t->deleted_at && Access::task($viewer, $t)['update_status'];
        return [
            'kind' => $data['kind'] ?? 'reminder',
            'task' => ['id' => (int) $t->id, 'title' => $t->title, 'status' => $t->status, 'deadline' => $t->deadline, 'progress' => (int) $t->progress, 'project_id' => (int) $t->project_id, 'deleted' => (bool) $t->deleted_at],
            'actions' => $t->deleted_at || in_array($t->status, ['completed', 'cancelled'], true) ? [] : ($data['actions'] ?? []),
            'can_update' => self::$canCache[$key],
        ];
    }
}
