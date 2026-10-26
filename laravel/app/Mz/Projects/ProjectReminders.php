<?php

namespace App\Mz\Projects;

use App\Mz\Jobs\ScheduledNotifications;
use App\Mz\Support\Dates;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Task deadline reminders — planned when a task changes, delivered by the one central
 * `scheduled:dispatch` job (no cron entry, no process per task, no polling per task).
 *
 * Slots per task: 3, 2 and 1 day before ('d3', 'd2', 'd1'), at the deadline ('due') and one day after
 * ('overdue'). The 1-day, deadline and overdue reminders are also emailed (if the member allows it).
 * Each (slot, deadline, person) has a unique key, so nothing is sent twice. Changing the deadline,
 * the responsible people or the status cancels the pending reminders and plans them again; a
 * completed or cancelled task has none. The text is written when the reminder is delivered, so it
 * shows the task's status at that moment, and a task completed in the meantime sends nothing.
 * The Task Bot posts every reminder into the department chat once (one message per slot, not per person).
 */
final class ProjectReminders
{
    private const SLOTS = ['d3' => -4320, 'd2' => -2880, 'd1' => -1440, 'due' => 0, 'overdue' => 1440];
    private const BOT_SLOTS = ['d3', 'd2', 'd1', 'due', 'overdue'];
    private const EMAIL_SLOTS = ['d1', 'due', 'overdue'];

    public static function planTask(int $taskId): void
    {
        ScheduledNotifications::cancel('project_task', $taskId);
        $t = DB::table('project_tasks')->where('id', $taskId)->whereNull('deleted_at')->first();
        if (! $t || ! $t->deadline || ! in_array($t->status, Pm::OPEN_TASK, true)) return;
        $assignees = Access::assigneeIds($taskId);
        $deadline = Dates::of($t->deadline);
        $now = Dates::now();
        $p = DB::table('projects')->where('id', $t->project_id)->first(['leader_id']);
        foreach (self::SLOTS as $slot => $minutes) {
            $at = Dates::fromMs(Dates::ms($deadline) + $minutes * 60000);
            if ($at <= $now) continue;
            $recipients = $assignees;
            if ($slot === 'overdue') {
                // Overdue also reaches the department leader / admins and the project leader.
                $recipients = array_merge($recipients, Access::managersOf((int) $t->department_id), $p?->leader_id ? [(int) $p->leader_id] : []);
            }
            $n = ['type' => 'project', 'title' => "task.reminder.$slot", 'body' => "task.reminder.$slot", 'entityType' => 'project_task', 'entityId' => $taskId,
                'data' => in_array($slot, self::EMAIL_SLOTS, true) ? ['email' => true] : null];
            if ($recipients) ScheduledNotifications::plan('project_task', $taskId, $slot, $at, $recipients, $n);
            if (in_array($slot, self::BOT_SLOTS, true)) {
                // One chat post per slot; user_id is only the row's owner (the task's creator / first person).
                $owner = (int) ($t->created_by ?: ($assignees[0] ?? 0));
                if ($owner) ScheduledNotifications::plan('project_task', $taskId, "bot-$slot", $at, [$owner], ['data' => ['bot' => $slot]] + $n);
            }
        }
    }

    /**
     * Called by ScheduledNotifications when a planned row comes due: returns the final text, or
     * null to drop it (task gone / closed; bot rows post into the chat instead).
     */
    public static function render(object $row): ?array
    {
        $t = DB::table('project_tasks')->where('id', $row->source_id)->whereNull('deleted_at')->first();
        if (! $t || ! in_array($t->status, Pm::OPEN_TASK, true)) return null;
        $p = DB::table('projects')->where('id', $t->project_id)->whereNull('deleted_at')->first(['id', 'title', 'status']);
        if (! $p || in_array($p->status, ['completed', 'cancelled'], true)) return null;
        $data = $row->data ? json_decode($row->data, true) : [];
        $slot = preg_replace('/^task\.reminder\./', '', $row->title);
        if (! empty($data['bot'])) {
            Bot::reminder($t, (string) $data['bot']);
            return null;
        }
        $names = DB::table('users')->where('id', $row->user_id)->value('full_name');
        $params = ['task' => $t->title, 'project' => $p->title, 'due' => Pm::localTime($t->deadline), 'status' => T::t("task.status.{$t->status}"), 'name' => $names ?: ''];
        return ['title' => T::t("task.reminder.$slot.title", $params), 'body' => T::t("task.reminder.$slot.body", $params)];
    }
}
