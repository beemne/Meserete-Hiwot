<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Wedding ceremony Mezmur services (port of weddingService.js). Participants are chosen by hand by
 * an authorized administrator (choir.manage) from the eligible members; the former automatic
 * requirements (minimum attendance / exam over a look-back period, program categories) no longer
 * decide or limit who may be selected. Their columns stay in the table only so history is kept.
 */
final class Weddings
{
    private const FIELDS = ['title', 'service_at', 'location', 'notes', 'status'];

    /** Old app versions still send the former requirement fields: accepted and ignored. */
    public const LEGACY_FIELDS = ['requires_attendance', 'min_attendance', 'requires_exam', 'min_exam', 'lookback_months', 'category_ids'];

    private static function toRow(array $input): array
    {
        return array_intersect_key($input, array_flip(self::FIELDS));
    }

    /**
     * Members who may be chosen: active member (or administrator) accounts with an active
     * membership, not in the children group, never the hidden system authority.
     */
    private static function eligible(string $alias = 'u')
    {
        return MemberIds::membersAndAdmins(DB::table("users as $alias"), $alias)
            ->where(["$alias.status" => 'active', "$alias.membership_status" => 'active'])
            ->where("$alias.member_group", '<>', 'children')->whereNull("$alias.deleted_at");
    }

    private static function serialize(object $w): array
    {
        $out = [
            'id' => $w->id,
            'title' => $w->title,
            'service_at' => $w->service_at,
            'location' => $w->location,
            'notes' => $w->notes,
            'status' => $w->status,
        ];
        if (property_exists($w, 'member_count')) $out['member_count'] = (int) $w->member_count;
        $out['created_by_name'] = $w->created_by_name ?? null;
        $out['created_at'] = $w->created_at;
        return $out;
    }

    private static function service(int $id): object
    {
        $w = DB::table('wedding_services')->where('id', $id)->first();
        if (! $w) throw ApiError::notFound('WEDDING_NOT_FOUND', 'Wedding service not found');
        return $w;
    }

    public static function list(?string $scope, array $page): array
    {
        $qb = DB::table('wedding_services as w')->leftJoin('users as c', 'c.id', '=', 'w.created_by')
            ->select('w.*', 'c.full_name as created_by_name', DB::raw("(SELECT COUNT(*) FROM wedding_service_members m WHERE m.service_id = w.id AND m.status <> 'withdrawn') as member_count"));
        if ($scope === 'upcoming') $qb->where('w.service_at', '>=', Dates::sql(Dates::fromLocal(Dates::todayLocal() . ' 00:00:00')))->orderBy('w.service_at');
        else $qb->orderByDesc('w.service_at');
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($w) => self::serialize($w), $res['items']), 'meta' => $res['meta']];
    }

    public static function get(int $id): array
    {
        $w = self::service($id);
        $members = DB::table('wedding_service_members as m')->join('users as u', 'u.id', '=', 'm.user_id')->leftJoin('users as s', 's.id', '=', 'm.selected_by')
            ->where('m.service_id', $id)->orderBy('u.full_name')
            ->select('m.user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'm.status', 'm.snapshot', 'm.note', 's.full_name as selected_by_name', 'm.created_at', 'm.updated_at')->get()
            ->map(function ($m) {
                // Selections made under the former automatic requirements keep their recorded values.
                $m->snapshot = is_string($m->snapshot) ? json_decode($m->snapshot, true) : $m->snapshot;
                return $m;
            })->all();
        MemberIds::decorate($members);
        foreach ($members as $m) unset($m->member_no);
        return self::serialize($w) + ['members' => $members];
    }

    /**
     * A new service, optionally with its participants chosen in the same step (user_ids): the
     * service and its participants are saved together — one ineligible member refuses both.
     */
    public static function create(array $actx, array $input): array
    {
        $row = self::toRow($input);
        $id = DB::transaction(function () use ($actx, $input, $row) {
            $id = DB::table('wedding_services')->insertGetId($row + ['created_by' => $actx['auth']->id]);
            Audit::log($actx, Audit::WEDDING_UPDATE, 'wedding_service', $id, ['created' => $row], inTrx: true);
            if (! empty($input['user_ids'])) self::select($actx, $id, $input['user_ids'], $input['note_for_members'] ?? null);
            return $id;
        });
        return self::get($id);
    }

    public static function update(array $actx, int $id, array $input): array
    {
        $w = self::service($id);
        $patch = self::toRow($input);
        if ($patch) DB::table('wedding_services')->where('id', $id)->update($patch);
        $previous = [];
        foreach (array_keys($patch) as $k) $previous[$k] = $w->{$k};
        Audit::log($actx, Audit::WEDDING_UPDATE, 'wedding_service', $id, ['previous' => (object) $previous, 'next' => (object) $patch]);
        return self::get($id);
    }

    /**
     * Eligible members to choose from, with their identifiers. Filters: name / phone / member
     * number search, member group, and whether they are already chosen for this service.
     */
    /** $id null: the eligible members before a service exists (choosing participants while creating it). */
    public static function candidates(?int $id, ?string $q, array $page, array $filter = []): array
    {
        if ($id !== null) self::service($id);
        $id ??= 0;
        $chosen = fn ($sq) => $sq->select(DB::raw(1))->from('wedding_service_members as m')->whereColumn('m.user_id', 'u.id')->where('m.service_id', $id)->where('m.status', '<>', 'withdrawn');
        $qb = MemberIds::search(self::eligible(), $q)->orderBy('u.full_name')->select('u.id', 'u.full_name', 'u.member_no', 'u.member_group');
        if (! empty($filter['member_group'])) $qb->where('u.member_group', $filter['member_group']);
        if (($filter['selected'] ?? null) === true) $qb->whereExists($chosen);
        if (($filter['selected'] ?? null) === false) $qb->whereNotExists($chosen);
        $res = Page::paginate($qb, $page);
        $selected = array_flip(DB::table('wedding_service_members')->where('service_id', $id)->where('status', '<>', 'withdrawn')->pluck('user_id')->all());
        MemberIds::decorate($res['items']);
        $items = array_map(fn ($u) => ['user_id' => $u->id, 'full_name' => $u->full_name, 'member_id' => $u->member_id, 'member_group' => $u->member_group, 'selected' => isset($selected[$u->id])], $res['items']);
        return ['items' => $items, 'meta' => $res['meta']];
    }

    /**
     * Choose participants by hand. Every id must be an eligible member; members already chosen are
     * left as they are (no duplicates), a withdrawn member chosen again is selected again. All or
     * nothing: one invalid id refuses the whole selection.
     */
    public static function select(array $actx, int $id, array $userIds, ?string $note): array
    {
        $userIds = array_values(array_unique(array_map('intval', $userIds)));
        $added = [];
        $already = [];
        DB::transaction(function () use ($actx, $id, $userIds, $note, &$added, &$already) {
            $w = DB::table('wedding_services')->where('id', $id)->lockForUpdate()->first();
            if (! $w) throw ApiError::notFound('WEDDING_NOT_FOUND', 'Wedding service not found');
            if ($w->status !== 'planned') throw ApiError::conflict('WEDDING_CLOSED', 'This service is no longer planned');
            $valid = self::eligible()->whereIn('u.id', $userIds)->pluck('u.id')->map(fn ($v) => (int) $v)->all();
            $invalid = array_values(array_diff($userIds, $valid));
            if ($invalid) {
                throw ApiError::validation(array_map(fn ($uid) => ['field' => 'user_ids', 'code' => 'NOT_ELIGIBLE', 'message' => (string) $uid], $invalid));
            }
            $current = DB::table('wedding_service_members')->where('service_id', $id)->whereIn('user_id', $userIds)->lockForUpdate()->pluck('status', 'user_id')->all();
            foreach ($userIds as $uid) {
                if (isset($current[$uid]) && $current[$uid] !== 'withdrawn') {
                    $already[] = $uid;
                    continue;
                }
                $row = ['status' => 'selected', 'snapshot' => null, 'note' => $note, 'selected_by' => $actx['auth']->id];
                DB::table('wedding_service_members')->upsert([['service_id' => $id, 'user_id' => $uid] + $row], ['service_id', 'user_id'], array_keys($row));
                $added[] = $uid;
            }
            Audit::log($actx, Audit::WEDDING_MEMBERS, 'wedding_service', $id, ['added' => $added, 'already_selected' => $already, 'note' => $note], inTrx: true);
            if ($added) {
                Notifications::createForUsers($added, [
                    'type' => 'choir',
                    'title' => T::t('wedding.selected.title'),
                    'body' => T::t('wedding.selected.body', ['title' => $w->title]),
                    'entityType' => 'wedding_service',
                    'entityId' => $id,
                    'dedupeKey' => fn ($uid) => "wedding:$id:selected:$uid:" . time(),
                ]);
            }
        });
        if ($added) Notifications::kick();
        return self::get($id) + ['added' => $added, 'already_selected' => $already];
    }

    public static function setMember(array $actx, int $id, int $userId, string $status, ?string $note): array
    {
        self::service($id);
        $m = DB::table('wedding_service_members')->where(['service_id' => $id, 'user_id' => $userId])->first(['id', 'status']);
        if (! $m) throw ApiError::notFound('MEMBER_NOT_SELECTED', 'This member was not selected');
        DB::table('wedding_service_members')->where('id', $m->id)->update(['status' => $status, 'note' => $note]);
        Audit::log($actx, Audit::WEDDING_MEMBERS, 'wedding_service', $id, ['user_id' => $userId, 'from' => $m->status, 'to' => $status, 'note' => $note]);
        return self::get($id);
    }

    public static function announce(array $actx, int $id, array $input = []): array
    {
        $w = self::service($id);
        if ($w->status !== 'planned') throw ApiError::conflict('SERVICE_NOT_PLANNED', 'Only planned services can be announced');

        $title = ! empty($input['title']) ? $input['title'] : ('የመዝሙር አገልግሎት ጥሪ: ' . $w->title);
        $body = ! empty($input['body']) ? $input['body'] : ($w->title . ' በ ' . ($w->location ? $w->location . ' ' : '') . 'ይካሄዳል።');

        $members = DB::table('wedding_service_members')->where('service_id', $id)->where('status', '<>', 'withdrawn')->pluck('user_id')->all();
        if (! empty($members)) {
            $targets = $members;
        } else {
            $targets = DB::table('users')->where(['status' => 'active', 'membership_status' => 'active'])
                ->where('member_group', '<>', 'children')->whereNull('deleted_at')->pluck('id')->all();
        }

        if ($targets) {
            $n = Notifications::createForUsers($targets, [
                'type' => 'choir',
                'title' => $title,
                'body' => $body,
                'entityType' => 'wedding_service',
                'entityId' => $id,
                'dedupeKey' => fn ($uid) => "wedding:$id:announced:$uid",
            ]);
            if ($n) Notifications::kick();
        }

        Audit::log($actx, Audit::WEDDING_UPDATE, 'wedding_service', $id, [
            'announced' => true,
            'title' => $title,
            'recipient_count' => count($targets),
        ]);

        return ['announced' => true, 'recipient_count' => count($targets)];
    }
}
