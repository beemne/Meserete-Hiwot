<?php

namespace App\Mz\Jobs;

use App\Mz\Db\Locks;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

/**
 * Notifications planned for a future moment (event-driven scheduling, no cron entry per reminder).
 *
 * A feature that knows a time in advance (a task deadline…) stores one row per recipient and moment
 * with a unique dedupe key. The single `scheduled:dispatch` job (request-driven ticker, see Jobs)
 * copies every row that has come due into `notifications` — whose own dedupe key makes a repeated
 * release harmless — and the usual dispatcher pushes it. When the source changes (deadline moved,
 * task completed or reassigned) its pending rows are cancelled and planned again.
 */
final class ScheduledNotifications
{
    /** source_type => callable(row): ?array{title, body} — renders at delivery time, null = drop. */
    private const RENDERERS = [
        'project_task' => [\App\Mz\Projects\ProjectReminders::class, 'render'],
    ];

    /**
     * @param array<int> $userIds
     * @param array{type:string,title:string,body:string,entityType?:?string,entityId?:?int,data?:?array} $n
     */
    public static function plan(string $sourceType, int $sourceId, string $slot, \DateTimeInterface $dueAt, array $userIds, array $n): int
    {
        $rows = [];
        foreach (array_values(array_unique(array_map('intval', $userIds))) as $uid) {
            $rows[] = [
                'user_id' => $uid,
                'due_at' => Dates::sql($dueAt),
                'type' => $n['type'],
                'title' => mb_substr($n['title'], 0, 255),
                'body' => mb_substr($n['body'], 0, 2000),
                'entity_type' => $n['entityType'] ?? null,
                'entity_id' => $n['entityId'] ?? null,
                'data' => isset($n['data']) ? json_encode($n['data'], JSON_UNESCAPED_UNICODE) : null,
                'source_type' => $sourceType,
                'source_id' => $sourceId,
                // The due time is part of the key: moving a deadline plans a new reminder.
                'dedupe_key' => mb_substr("$sourceType:$sourceId:$slot:" . Dates::of($dueAt)->format('YmdHi') . ":$uid", 0, 150),
            ];
        }
        return $rows ? DB::table('scheduled_notifications')->insertOrIgnore($rows) : 0;
    }

    /** Cancel what is still pending for a source (optionally only some slots). */
    public static function cancel(string $sourceType, int $sourceId, ?array $slots = null): int
    {
        $q = DB::table('scheduled_notifications')->where(['source_type' => $sourceType, 'source_id' => $sourceId, 'status' => 'pending']);
        if ($slots) {
            $q->where(function ($w) use ($sourceType, $sourceId, $slots) {
                foreach ($slots as $s) $w->orWhere('dedupe_key', 'like', "$sourceType:$sourceId:$s:%");
            });
        }
        return $q->update(['status' => 'cancelled']);
    }

    /** Move every due row into the notification center (one worker at a time). */
    public static function releaseDue(?\DateTimeInterface $now = null, int $batch = 500): array
    {
        $now ??= Dates::now();
        return Locks::named('mz:job:scheduled-dispatch', function () use ($now, $batch) {
            $released = 0;
            while (true) {
                $due = DB::table('scheduled_notifications')->where('status', 'pending')->where('due_at', '<=', Dates::sql($now))->orderBy('id')->limit($batch)->get()->all();
                if (! $due) break;
                $rows = [];
                foreach ($due as $r) {
                    $text = ['title' => $r->title, 'body' => $r->body];
                    // A source may write the final text now (current state) or drop the reminder.
                    $renderer = self::RENDERERS[$r->source_type] ?? null;
                    if ($renderer) {
                        try {
                            $text = $renderer($r);
                        } catch (\Throwable $e) {
                            \Illuminate\Support\Facades\Log::warning('scheduled notification render failed', ['id' => $r->id, 'error' => $e->getMessage()]);
                            $text = null;
                        }
                    }
                    if (! $text) continue;
                    $data = $r->data ? (json_decode($r->data, true) ?: []) : [];
                    $rows[] = [
                        'user_id' => $r->user_id, 'type' => $r->type, 'topic' => \App\Mz\Notifications\Notifications::topicOf($r->type),
                        'title' => mb_substr($text['title'], 0, 255), 'body' => mb_substr($text['body'], 0, 2000),
                        'entity_type' => $r->entity_type, 'entity_id' => $r->entity_id, 'data' => $r->data,
                        'email_status' => ! empty($data['email']) ? 'pending' : 'none',
                        'dedupe_key' => mb_substr('sched:' . $r->dedupe_key, 0, 150),
                    ];
                }
                DB::transaction(function () use ($rows, $due, &$released) {
                    if ($rows) $released += DB::table('notifications')->insertOrIgnore($rows);
                    DB::table('scheduled_notifications')->whereIn('id', array_map(fn ($r) => $r->id, $due))->update(['status' => 'sent', 'sent_at' => DB::raw('NOW()')]);
                });
                if (count($due) < $batch) break;
            }
            return ['released' => $released];
        });
    }
}
