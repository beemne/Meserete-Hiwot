<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Fcm;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Department chat (port of chatService.js): one private group per department plus private
 * leader ↔ member conversations. Members write text in the group; leaders and the supervisor
 * (chat.supervise) also send media and voice-meeting links. Attachments are private files
 * streamed only to someone who may read that conversation.
 */
final class Chat
{
    public const GROUP = 'g';
    private const MEDIA_KINDS = ['image', 'audio', 'video', 'file'];
    private const PAGE = 50;
    private const MEETING_HOSTS = '~^https://([a-z0-9-]+\.)*(meet\.jit\.si|jitsi\.[a-z.]+|meet\.google\.com|zoom\.us|teams\.microsoft\.com|t\.me|telegram\.me)(/|$)~i';

    private static function dmKey(int $a, int $b): string
    {
        return 'd:' . min($a, $b) . ':' . max($a, $b);
    }

    private static function dmPeer(string $key, int $me): int
    {
        [, $a, $b] = array_map('intval', explode(':', $key));
        return $a === $me ? $b : $a;
    }

    private static function activeDepartment(int $id): object
    {
        $d = DB::table('departments')->where(['id' => $id, 'is_active' => true])->first(['id', 'name', 'name_en']);
        if (! $d) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
        return $d;
    }

    /** @return array<int,true> */
    private static function leaderIds(int $departmentId): array
    {
        $leads = DB::table('user_departments')->where(['department_id' => $departmentId, 'role' => 'leader'])->pluck('user_id')->all();
        $admins = DB::table('department_admins as da')->join('users as u', 'u.id', '=', 'da.user_id')->where('da.department_id', $departmentId)->whereNull('u.deleted_at')->pluck('da.user_id')->all();
        $out = [];
        foreach (array_merge($leads, $admins) as $id) $out[(int) $id] = true;
        return $out;
    }

    /** The caller's place in a department's chat; throws when they have none. */
    public static function access(AuthContext $auth, int $departmentId): array
    {
        $dept = self::activeDepartment($departmentId);
        $member = DB::table('user_departments')->where(['user_id' => $auth->id, 'department_id' => $departmentId])->exists();
        $leader = isset(self::leaderIds($departmentId)[$auth->id]);
        $supervisor = $auth->can('chat.supervise');
        if (! $member && ! $leader && ! $supervisor) throw ApiError::forbidden('CHAT_FORBIDDEN', 'You are not a member of this department');
        return ['dept' => $dept, 'member' => $member || $leader, 'leader' => $leader, 'supervisor' => $supervisor, 'canSendMedia' => true];
    }

    private static function inDepartment(int $departmentId, int $userId): bool
    {
        if (DB::table('user_departments')->where(['department_id' => $departmentId, 'user_id' => $userId])->exists()) return true;
        return isset(self::leaderIds($departmentId)[$userId]);
    }

    private static function invalidThread(): ApiError
    {
        return ApiError::validation([['field' => 'thread', 'code' => 'INVALID_THREAD', 'message' => 'INVALID_THREAD']]);
    }

    private static function resolveThread(AuthContext $auth, array $a, int $departmentId, ?string $thread, bool $forWriting = false): array
    {
        if (! $thread || $thread === 'group') return ['key' => self::GROUP, 'recipientId' => null];
        if (! preg_match('/^user:(\d+)$/', $thread, $m)) throw self::invalidThread();
        $peer = (int) $m[1];
        if ($peer === $auth->id) throw self::invalidThread();
        $key = self::dmKey($auth->id, $peer);
        if (! $a['member']) throw ApiError::forbidden('CHAT_FORBIDDEN', 'Private conversations are only between department members');
        if (! self::inDepartment($departmentId, $peer)) throw ApiError::forbidden('CHAT_PRIVATE_NOT_ALLOWED', 'That person is not in this department');
        $leaders = self::leaderIds($departmentId);
        // A private conversation always has a leader on one side.
        if (! $a['leader'] && ! isset($leaders[$peer])) throw ApiError::forbidden('CHAT_PRIVATE_NOT_ALLOWED', 'Members can only write privately to their department leaders');
        if ($forWriting && ! DB::table('users')->where('id', $peer)->whereNull('deleted_at')->exists()) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        return ['key' => $key, 'recipientId' => $peer];
    }

    private static function serialize(object $m, AuthContext $auth, bool $leader): array
    {
        $deleted = (bool) $m->deleted_at;
        return [
            'id' => (int) $m->id,
            'department_id' => $m->department_id,
            'thread' => $m->thread_key === self::GROUP ? 'group' : 'user:' . self::dmPeer($m->thread_key, $auth->id),
            'kind' => $m->kind,
            'body' => $deleted ? null : $m->body,
            'deleted' => $deleted,
            'sender' => ['id' => $m->sender_id, 'full_name' => $m->sender_name, 'member_id' => MemberIds::format($m->sender_no, $m->sender_group), 'avatar_url' => Storage::url($m->sender_avatar), 'is_leader' => $leader],
            'attachment' => ! $deleted && $m->attachment_path ? ['url' => "/chat/messages/{$m->id}/file", 'mime' => $m->attachment_mime, 'size' => $m->attachment_size, 'name' => $m->attachment_name] : null,
            'meeting' => ! $deleted && $m->kind === 'meeting' ? ['url' => $m->meeting_url, 'at' => $m->meeting_at] : null,
            // Task Bot: the task's current state and the status buttons (Project Management).
            'bot' => ! $deleted && $m->kind === 'task_bot' ? \App\Mz\Projects\Bot::payload($m, $auth) : null,
            'mine' => (int) $m->sender_id === $auth->id,
            'created_at' => $m->created_at,
        ];
    }

    private static function messageQuery()
    {
        return DB::table('chat_messages as m')->join('users as s', 's.id', '=', 'm.sender_id')
            ->select('m.*', 's.full_name as sender_name', 's.member_no as sender_no', 's.member_group as sender_group', 's.profile_image as sender_avatar');
    }

    /** Messages of a conversation, oldest first. `before` pages back; `after` polls. */
    public static function messages(AuthContext $auth, int $departmentId, array $q): array
    {
        $a = self::access($auth, $departmentId);
        $t = self::resolveThread($auth, $a, $departmentId, $q['thread'] ?? null);
        $limit = min($q['limit'] ?? self::PAGE, 200);
        $after = $q['after'] ?? null;
        $qb = self::messageQuery()->where(['m.department_id' => $departmentId, 'm.thread_key' => $t['key']]);
        if ($after) {
            $qb->where('m.id', '>', $after)->orderBy('m.id')->limit($limit);
        } else {
            if (! empty($q['before'])) $qb->where('m.id', '<', $q['before']);
            $qb->orderByDesc('m.id')->limit($limit);
        }
        $rows = $qb->get()->all();
        if (! $after) $rows = array_reverse($rows);
        $leaders = self::leaderIds($departmentId);
        return [
            'department' => $a['dept'],
            'thread' => $t['key'] === self::GROUP ? 'group' : "user:{$t['recipientId']}",
            'can_send_media' => $a['canSendMedia'],
            'is_leader' => $a['leader'],
            'items' => array_map(fn ($r) => self::serialize($r, $auth, isset($leaders[(int) $r->sender_id])), $rows),
        ];
    }

    public static function send(AuthContext $auth, int $departmentId, array $input, ?UploadedFile $file): array
    {
        $a = self::access($auth, $departmentId);
        $t = self::resolveThread($auth, $a, $departmentId, $input['thread'] ?? null, true);
        if ($t['key'] === self::GROUP && ! $a['member'] && ! $a['supervisor']) throw ApiError::forbidden('CHAT_FORBIDDEN', 'You are not a member of this department');
        $kind = $input['kind'] ?? ($file ? null : 'text');
        $body = is_string($input['body'] ?? null) ? mb_substr(trim($input['body']), 0, 4000) : null;
        $row = ['department_id' => $departmentId, 'thread_key' => $t['key'], 'sender_id' => $auth->id, 'recipient_id' => $t['recipientId'], 'body' => $body ?: null];

        if ($kind === 'meeting' && ! ($a['leader'] || $a['supervisor'])) {
            throw ApiError::forbidden('CHAT_MEETING_LEADERS_ONLY', 'Only department leaders can create voice meetings');
        }
        if ($file) {
            $saved = Storage::save('chat', Storage::FOLDERS['CHAT'], $file);
            $mime = $saved['mime'];
            $kind = str_starts_with($mime, 'image/') ? 'image' : (str_starts_with($mime, 'audio/') ? 'audio' : (str_starts_with($mime, 'video/') ? 'video' : 'file'));
            $name = mb_substr(preg_replace('/[^\p{L}\p{N}._ -]/u', '', (string) $file->getClientOriginalName()), 0, 150);
            $row += ['attachment_path' => $saved['path'], 'attachment_mime' => $mime, 'attachment_size' => $saved['size'], 'attachment_name' => $name ?: null];
        } elseif ($kind === 'meeting') {
            $url = trim((string) ($input['meeting_url'] ?? ''));
            if (! preg_match(self::MEETING_HOSTS, $url) || strlen($url) > 500) throw ApiError::validation([['field' => 'meeting_url', 'code' => 'INVALID_MEETING_URL', 'message' => 'INVALID_MEETING_URL']]);
            $row['meeting_url'] = $url;
            $row['meeting_at'] = null;
            if (! empty($input['meeting_at'])) {
                $at = Dates::of($input['meeting_at']);
                if (! $at) throw ApiError::validation([['field' => 'meeting_at', 'code' => 'INVALID_DATE', 'message' => 'INVALID_DATE']]);
                $row['meeting_at'] = Dates::sql($at);
            }
        } elseif (in_array($kind, self::MEDIA_KINDS, true)) {
            throw ApiError::badRequest('FILE_REQUIRED', 'File is required');
        } else {
            $kind = 'text';
            if (! $row['body']) throw ApiError::validation([['field' => 'body', 'code' => 'MESSAGE_EMPTY', 'message' => 'MESSAGE_EMPTY']]);
        }
        $row['kind'] = $kind;
        try {
            $id = DB::table('chat_messages')->insertGetId($row);
        } catch (\Throwable $e) {
            if (! empty($row['attachment_path'])) Storage::remove($row['attachment_path']);
            throw $e;
        }
        self::markRead($auth, $departmentId, $input['thread'] ?? null, $id, $t['key']);
        $saved = self::messageQuery()->where('m.id', $id)->first();
        $leaders = self::leaderIds($departmentId);
        $dept = $a['dept'];
        // Everyone concerned is notified: an in-app notification (one per conversation until it is
        // read, updated with the latest message) and a push after the response is sent.
        $recipients = self::recipients($dept, $t, $auth);
        try {
            self::notifyInApp($dept, $t, $saved, $auth, $recipients);
        } catch (\Throwable $e) {
            Log::warning('chat notification failed', ['error' => $e->getMessage()]);
        }
        app()->terminating(function () use ($dept, $t, $saved, $auth, $recipients) {
            try {
                self::push($dept, $t, $saved, $auth, $recipients);
            } catch (\Throwable $e) {
                Log::warning('chat push failed', ['error' => $e->getMessage()]);
            }
        });
        return self::serialize($saved, $auth, isset($leaders[$auth->id]));
    }

    /**
     * Who hears about a message: for the group — every department member, its leaders and
     * department administrators, and the higher administrators who supervise all department chats
     * (chat.supervise); for a private conversation — only the other person. Never the sender.
     * @return int[]
     */
    public static function recipients(object $dept, array $t, AuthContext $auth): array
    {
        if ($t['key'] !== self::GROUP) return [(int) $t['recipientId']];
        $members = DB::table('user_departments as ud')->join('users as u', 'u.id', '=', 'ud.user_id')
            ->where('ud.department_id', $dept->id)->where('u.status', 'active')->whereNull('u.deleted_at')->pluck('ud.user_id')->all();
        $ids = array_unique(array_merge(array_map('intval', $members), array_keys(self::leaderIds($dept->id)), Holders::of('chat.supervise')));
        return array_values(array_filter($ids, fn ($id) => $id !== $auth->id));
    }

    private static function preview(object $m): string
    {
        return $m->kind === 'text' ? (string) $m->body : "[{$m->kind}]" . ($m->body ? " {$m->body}" : '');
    }

    /** Collapsing key: one notification per person and conversation until they read it. */
    private static function notificationKey(int $departmentId, string $threadKey, int $uid, int $lastRead): string
    {
        return "chat:$departmentId:$threadKey:$uid:$lastRead";
    }

    private static function notifyInApp(object $dept, array $t, object $m, AuthContext $auth, array $recipients): void
    {
        if (! $recipients) return;
        $reads = DB::table('chat_reads')->where('department_id', $dept->id)->whereIn('user_id', $recipients)
            ->where('thread_key', $t['key'] === self::GROUP ? self::GROUP : $t['key'])->pluck('last_read_id', 'user_id')->all();
        $title = $t['key'] === self::GROUP ? $dept->name : (string) $m->sender_name;
        $body = mb_substr($t['key'] === self::GROUP ? "{$m->sender_name}: " . self::preview($m) : self::preview($m), 0, 500);
        $now = gmdate('Y-m-d H:i:s');
        foreach (array_chunk($recipients, 500) as $chunk) {
            $rows = [];
            foreach ($chunk as $uid) {
                $thread = $t['key'] === self::GROUP ? 'group' : "user:{$auth->id}";
                $rows[] = [
                    'user_id' => $uid, 'type' => 'chat', 'topic' => 'department', 'title' => mb_substr($title, 0, 255), 'body' => $body,
                    'entity_type' => 'chat', 'entity_id' => $dept->id,
                    'data' => json_encode(['department_id' => $dept->id, 'thread' => $thread, 'message_id' => (int) $m->id], JSON_UNESCAPED_UNICODE),
                    // The push is sent directly (below), so the dispatcher does not send it again.
                    'delivery_status' => 'skipped',
                    'dedupe_key' => self::notificationKey((int) $dept->id, $t['key'], $uid, (int) ($reads[$uid] ?? 0)),
                    'created_at' => $now,
                ];
            }
            // A newer message refreshes the same unread notification instead of piling up rows.
            DB::table('notifications')->upsert($rows, ['dedupe_key'], ['title', 'body', 'data', 'created_at', 'read_at' => DB::raw('NULL')]);
        }
    }

    private static function push(object $dept, array $t, object $m, AuthContext $auth, array $recipients): void
    {
        if (! Fcm::enabled()) return;
        if (! $recipients) return;
        // The member's "department" push preference (and the master switch) decide.
        $recipients = \App\Mz\Notifications\Notifications::pushRecipients($recipients, 'chat');
        if (! $recipients) return;
        $tokens = DB::table('fcm_tokens as t')->whereIn('t.user_id', $recipients)->whereNull('t.invalidated_at')->pluck('t.token')->all();
        $preview = self::preview($m);
        $title = $t['key'] === self::GROUP ? $dept->name : $m->sender_name;
        $body = $t['key'] === self::GROUP ? "{$m->sender_name}: $preview" : $preview;
        $messages = array_map(fn ($token) => [
            'token' => $token, 'title' => $title, 'body' => mb_substr((string) $body, 0, 200),
            'data' => ['type' => 'chat', 'department_id' => (string) $dept->id, 'thread' => $t['key'] === self::GROUP ? 'group' : "user:{$auth->id}", 'entity_type' => 'chat', 'entity_id' => (string) $dept->id, 'channel' => 'chat'],
        ], $tokens);
        $dead = array_column(array_filter(Fcm::sendBatch($messages), fn ($r) => ! empty($r['dead'])), 'token');
        if ($dead) DB::table('fcm_tokens')->whereIn('token', $dead)->update(['invalidated_at' => DB::raw('NOW()')]);
    }

    /** Sender removes their own message; leaders / the supervisor remove any group message. */
    public static function remove(AuthContext $auth, int $departmentId, int $messageId): array
    {
        $a = self::access($auth, $departmentId);
        $m = DB::table('chat_messages')->where(['id' => $messageId, 'department_id' => $departmentId])->first();
        if (! $m || $m->deleted_at) throw ApiError::notFound('MESSAGE_NOT_FOUND', 'Message not found');
        $mine = (int) $m->sender_id === $auth->id;
        if ($m->thread_key !== self::GROUP && ! $mine && (int) $m->recipient_id !== $auth->id) throw ApiError::notFound('MESSAGE_NOT_FOUND', 'Message not found');
        $moderator = $m->thread_key === self::GROUP && ($a['leader'] || $a['supervisor']);
        if (! $mine && ! $moderator) throw ApiError::forbidden('CHAT_DELETE_FORBIDDEN', 'You can only remove your own messages');
        DB::table('chat_messages')->where('id', $m->id)->update(['deleted_at' => DB::raw('NOW()'), 'deleted_by' => $auth->id]);
        if ($m->attachment_path) Storage::remove($m->attachment_path);
        return ['id' => (int) $m->id, 'deleted' => true];
    }

    /** An attachment, only to someone who may read its conversation. */
    public static function attachment(AuthContext $auth, int $messageId): array
    {
        $m = DB::table('chat_messages')->where('id', $messageId)->whereNull('deleted_at')->first();
        if (! $m || ! $m->attachment_path) throw ApiError::notFound();
        try {
            self::access($auth, (int) $m->department_id);
        } catch (ApiError) {
            throw ApiError::notFound();
        }
        if ($m->thread_key !== self::GROUP && (int) $m->sender_id !== $auth->id && (int) $m->recipient_id !== $auth->id) throw ApiError::notFound();
        $abs = Storage::privatePath($m->attachment_path);
        if (! is_file($abs)) throw ApiError::notFound();
        return ['abs' => $abs, 'mime' => $m->attachment_mime, 'name' => $m->attachment_name];
    }

    public static function markRead(AuthContext $auth, int $departmentId, ?string $thread, int $lastId, ?string $key = null): array
    {
        if ($key === null) {
            $a = self::access($auth, $departmentId);
            $key = self::resolveThread($auth, $a, $departmentId, $thread)['key'];
        }
        DB::statement(
            'INSERT INTO chat_reads (user_id, department_id, thread_key, last_read_id) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE last_read_id = GREATEST(last_read_id, VALUES(last_read_id)), updated_at = NOW()',
            [$auth->id, $departmentId, $key, $lastId],
        );
        // Reading the conversation also clears its notification.
        DB::table('notifications')->where(['user_id' => $auth->id, 'type' => 'chat', 'entity_id' => $departmentId])->whereNull('read_at')
            ->where('dedupe_key', 'like', "chat:$departmentId:$key:{$auth->id}:%")->update(['read_at' => DB::raw('NOW()')]);
        return ['thread' => $thread ?? 'group', 'last_read_id' => $lastId];
    }

    private static function unread(int $userId, int $departmentId, string $key): int
    {
        $last = DB::table('chat_reads')->where(['user_id' => $userId, 'department_id' => $departmentId, 'thread_key' => $key])->value('last_read_id') ?? 0;
        return DB::table('chat_messages')->where(['department_id' => $departmentId, 'thread_key' => $key])->whereNull('deleted_at')->where('sender_id', '!=', $userId)->where('id', '>', $last)->count();
    }

    /** The caller's department chats with unread counts (the supervisor sees every department). */
    public static function overview(AuthContext $auth): array
    {
        $own = array_map('intval', DB::table('user_departments')->where('user_id', $auth->id)->pluck('department_id')->all());
        $adm = array_map('intval', DB::table('department_admins')->where('user_id', $auth->id)->pluck('department_id')->all());
        $q = DB::table('departments')->where('is_active', true)->orderBy('sort_order')->orderBy('id')->select('id', 'name', 'name_en');
        if (! $auth->can('chat.supervise')) $q->whereIn('id', array_values(array_unique(array_merge($own, $adm))) ?: [0]);
        $out = [];
        foreach ($q->get() as $d) {
            $leaders = self::leaderIds($d->id);
            $last = self::messageQuery()->where(['m.department_id' => $d->id, 'm.thread_key' => self::GROUP])->orderByDesc('m.id')->first();
            $dmKeys = DB::table('chat_messages')->where('department_id', $d->id)->where(fn ($w) => $w->where('sender_id', $auth->id)->orWhere('recipient_id', $auth->id))
                ->where('thread_key', '!=', self::GROUP)->distinct()->pluck('thread_key')->all();
            $privateUnread = 0;
            foreach ($dmKeys as $k) $privateUnread += self::unread($auth->id, $d->id, $k);
            $out[] = [
                'department' => $d,
                'is_leader' => isset($leaders[$auth->id]),
                'is_member' => in_array((int) $d->id, $own, true) || isset($leaders[$auth->id]),
                'unread_group' => self::unread($auth->id, $d->id, self::GROUP),
                'unread_private' => $privateUnread,
                'last_message' => $last ? self::serialize($last, $auth, isset($leaders[(int) $last->sender_id])) : null,
            ];
        }
        return $out;
    }

    /** The caller's private conversations in a department (newest first). */
    public static function threads(AuthContext $auth, int $departmentId): array
    {
        $a = self::access($auth, $departmentId);
        if (! $a['member']) return [];
        $keys = DB::table('chat_messages')->where('department_id', $departmentId)->where(fn ($w) => $w->where('sender_id', $auth->id)->orWhere('recipient_id', $auth->id))
            ->where('thread_key', '!=', self::GROUP)->groupBy('thread_key')->selectRaw('thread_key, MAX(id) as last')->get()->all();
        usort($keys, fn ($x, $y) => (int) $y->last <=> (int) $x->last);
        $out = [];
        foreach ($keys as $k) {
            $peerId = self::dmPeer($k->thread_key, $auth->id);
            $peer = DB::table('users')->where('id', $peerId)->first(['id', 'full_name', 'member_no', 'member_group', 'profile_image']);
            if (! $peer) continue;
            $last = self::messageQuery()->where('m.id', $k->last)->first();
            $out[] = [
                'thread' => "user:$peerId",
                'peer' => ['id' => $peer->id, 'full_name' => $peer->full_name, 'member_id' => MemberIds::format($peer->member_no, $peer->member_group), 'avatar_url' => Storage::url($peer->profile_image)],
                'unread' => self::unread($auth->id, $departmentId, $k->thread_key),
                'last_message' => self::serialize($last, $auth, false),
            ];
        }
        return $out;
    }

    /** Who the caller may write to privately: leaders → every member; members → their leaders. */
    public static function contacts(AuthContext $auth, int $departmentId, ?string $q): array
    {
        $a = self::access($auth, $departmentId);
        if (! $a['member']) return [];
        $leaders = self::leaderIds($departmentId);
        $memberIds = array_map('intval', DB::table('user_departments')->where('department_id', $departmentId)->pluck('user_id')->all());
        $ids = $a['leader'] ? array_unique(array_merge($memberIds, array_keys($leaders))) : array_keys($leaders);
        $ids = array_values(array_filter($ids, fn ($id) => $id !== $auth->id));
        if (! $ids) return [];
        $qb = DB::table('users')->whereIn('id', $ids)->whereNull('deleted_at')->orderBy('full_name')->select('id', 'full_name', 'member_no', 'member_group', 'profile_image');
        if ($q) $qb->where('full_name', 'like', "%$q%");
        return $qb->get()->map(fn ($u) => [
            'id' => $u->id, 'full_name' => $u->full_name, 'member_id' => MemberIds::format($u->member_no, $u->member_group),
            'avatar_url' => Storage::url($u->profile_image), 'is_leader' => isset($leaders[(int) $u->id]),
        ])->all();
    }
}
