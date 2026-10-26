<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Page;
use Illuminate\Support\Facades\DB;

/**
 * Admin messaging: one user, a selection, a filtered group or everyone (port of broadcastService.js).
 * A resend is a NEW broadcast (edited text, new receivers) linked to the original by resent_from_id;
 * the original and its delivery history are never changed.
 */
final class Broadcasts
{
    private const KIND_TO_TYPE = ['announcement' => 'announcement', 'reminder' => 'admin_message', 'program_info' => 'program', 'admin_message' => 'admin_message'];
    private const ENTITY_TABLE = ['program' => 'programs', 'mezmur' => 'mezmurs', 'page' => 'pages', 'category' => 'categories'];

    public static function send(array $actx, array $input, bool $allowAll, ?int $resentFrom = null): array
    {
        if (! empty($input['entity_type'])) {
            if (! DB::table(self::ENTITY_TABLE[$input['entity_type']])->where('id', $input['entity_id'])->exists()) throw ApiError::field('entity_id', 'ENTITY_NOT_FOUND');
        }
        $email = (bool) ($input['email'] ?? false);
        return DB::transaction(function () use ($actx, $input, $allowAll, $resentFrom, $email) {
            $ids = Targeting::resolve($input['target'], $allowAll);
            if (! $ids) throw ApiError::field('target', 'NO_RECIPIENTS');
            $broadcastId = DB::table('notification_broadcasts')->insertGetId([
                'sender_id' => $actx['auth']->id,
                'kind' => $input['kind'],
                'title' => $input['title'],
                'body' => $input['body'],
                'target_type' => Targeting::type($input['target']),
                'target_filter' => isset($input['target']['filter']) ? json_encode($input['target']['filter'], JSON_UNESCAPED_UNICODE) : null,
                'entity_type' => $input['entity_type'] ?? null,
                'entity_id' => $input['entity_id'] ?? null,
                'recipient_count' => count($ids),
                'resent_from_id' => $resentFrom,
                'channels' => $email ? 'push,email' : 'push',
            ]);
            Notifications::createForUsers($ids, [
                'type' => self::KIND_TO_TYPE[$input['kind']],
                'title' => $input['title'],
                'body' => $input['body'],
                'entityType' => $input['entity_type'] ?? null,
                'entityId' => $input['entity_id'] ?? null,
                'broadcastId' => $broadcastId,
                'sentBy' => $actx['auth']->id,
                'email' => $email,
            ]);
            $meta = ['kind' => $input['kind'], 'target' => Targeting::type($input['target']), 'recipients' => count($ids), 'email' => $email];
            if ($resentFrom) $meta['resent_from'] = $resentFrom;
            Audit::log($actx, $resentFrom ? Audit::NOTIFICATION_RESEND : Audit::NOTIFICATION_BROADCAST, 'broadcast', $broadcastId, $meta, inTrx: true);
            return ['broadcast_id' => $broadcastId, 'recipients' => count($ids), 'resent_from_id' => $resentFrom];
        });
    }

    /** Resend: the original must exist (and be visible to this administrator). */
    public static function resend(array $actx, int $id, array $input, bool $allowAll): array
    {
        self::row($actx['auth'], $id);
        return self::send($actx, $input, $allowAll, $id);
    }

    private static function base(AuthContext $auth)
    {
        $qb = DB::table('notification_broadcasts as b')->leftJoin('users as s', 's.id', '=', 'b.sender_id')->leftJoin('roles as r', 'r.id', '=', 's.role_id');
        if (! $auth->isSystem) $qb->where(fn ($w) => $w->whereNull('r.is_hidden')->orWhere('r.is_hidden', false));
        return $qb;
    }

    private static function row(AuthContext $auth, int $id): object
    {
        $b = self::base($auth)->where('b.id', $id)->first(['b.*', Actor::hiddenName('s', 'r', 'sender_name')]);
        if (! $b) throw ApiError::notFound('BROADCAST_NOT_FOUND', 'Notification not found');
        return $b;
    }

    public static function history(AuthContext $auth, array $filter, array $page): array
    {
        $qb = self::base($auth)
            ->select('b.id', 'b.kind', 'b.title', 'b.body', 'b.target_type', 'b.recipient_count', 'b.entity_type', 'b.entity_id', 'b.created_at', 'b.resent_from_id', 'b.channels', Actor::hiddenName('s', 'r', 'sender_name'),
                DB::raw('(SELECT COUNT(*) FROM notifications n WHERE n.broadcast_id = b.id AND n.read_at IS NOT NULL) as read_count'),
                DB::raw("(SELECT COUNT(*) FROM notifications n WHERE n.broadcast_id = b.id AND n.delivery_status = 'sent') as delivered_count"))
            ->orderByDesc('b.created_at');
        if (! empty($filter['kind'])) $qb->where('b.kind', $filter['kind']);
        if (! empty($filter['q'])) $qb->where('b.title', 'like', "%{$filter['q']}%");
        return Page::paginate($qb, $page);
    }

    /** Everything about one sent notification: text, target, receivers, delivery per channel, resends. */
    public static function detail(AuthContext $auth, int $id): array
    {
        $b = self::row($auth, $id);
        $stats = fn (string $col) => array_map('intval', DB::table('notifications')->where('broadcast_id', $id)->groupBy($col)->selectRaw("$col as s, COUNT(*) as c")->pluck('c', 's')->all());
        $recipients = DB::table('notifications as n')->join('users as u', 'u.id', '=', 'n.user_id')->where('n.broadcast_id', $id)
            ->orderBy('u.full_name')->limit(200)
            ->get(['u.id', 'u.full_name', 'u.member_no', 'u.member_group', 'n.delivery_status', 'n.email_status', 'n.read_at'])
            ->map(fn ($r) => ['id' => (int) $r->id, 'full_name' => $r->full_name, 'member_id' => MemberIds::format($r->member_no, $r->member_group), 'push' => $r->delivery_status, 'email' => $r->email_status, 'read_at' => $r->read_at])->all();
        $chain = self::base($auth)->where('b.resent_from_id', $id)->orderBy('b.id')->get(['b.id', 'b.title', 'b.created_at', 'b.recipient_count', Actor::hiddenName('s', 'r', 'sender_name')])->all();
        return [
            'id' => (int) $b->id,
            'kind' => $b->kind,
            'title' => $b->title,
            'body' => $b->body,
            'target_type' => $b->target_type,
            'target_filter' => $b->target_filter ? json_decode($b->target_filter, true) : null,
            'entity_type' => $b->entity_type,
            'entity_id' => $b->entity_id,
            'channels' => explode(',', (string) ($b->channels ?: 'push')),
            'sender_name' => $b->sender_name,
            'created_at' => $b->created_at,
            'recipient_count' => (int) $b->recipient_count,
            'push' => $stats('delivery_status'),
            'email' => $stats('email_status'),
            'read' => DB::table('notifications')->where('broadcast_id', $id)->whereNotNull('read_at')->count(),
            'recipients' => $recipients,
            'resent_from_id' => $b->resent_from_id ? (int) $b->resent_from_id : null,
            'resends' => $chain,
        ];
    }
}
