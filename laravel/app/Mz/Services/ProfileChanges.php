<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\MemberSchemas;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Members' requests to change their details (name, phone and any membership-form field), held for an
 * administrator's approval, and the history of every applied change (old → new, never deleted).
 */
final class ProfileChanges
{
    public static function serialize(?object $r): ?array
    {
        if (! $r) {
            return null;
        }
        return [
            'id' => $r->id,
            'user_id' => $r->user_id,
            'user_name' => $r->user_name ?? null,
            'old_full_name' => $r->old_full_name,
            'old_phone' => $r->old_phone,
            'full_name' => $r->full_name,
            'phone' => $r->phone,
            'changes' => self::changesOf($r),
            'note' => $r->note ?? null,
            'status' => $r->status,
            'reason' => $r->reason,
            'reviewed_by_name' => $r->reviewed_by_name ?? null,
            'reviewed_at' => $r->reviewed_at,
            'created_at' => $r->created_at,
        ];
    }

    public static function pendingFor(int $userId): ?array
    {
        return self::serialize(DB::table('profile_change_requests')->where(['user_id' => $userId, 'status' => 'pending'])->orderByDesc('id')->first());
    }

    /** [{field, old, new}] of a request: name / phone and the membership-form fields. */
    public static function changesOf(object $r): array
    {
        $out = [];
        if ($r->full_name) $out[] = ['field' => 'full_name', 'old' => $r->old_full_name, 'new' => $r->full_name];
        if ($r->phone) $out[] = ['field' => 'phone', 'old' => $r->old_phone, 'new' => $r->phone];
        $more = isset($r->changes) && $r->changes ? json_decode($r->changes, true) : [];
        foreach (is_array($more) ? $more : [] as $field => $c) $out[] = ['field' => $field, 'old' => $c['old'] ?? null, 'new' => $c['new'] ?? null];
        return $out;
    }

    private static function norm(mixed $v): ?string
    {
        if ($v === null) return null;
        $s = trim((string) $v);
        return $s === '' ? null : $s;
    }

    /**
     * Submit (or replace) the member's pending request with only what differs from the current
     * details; null when nothing changed. in: full_name?, phone?, profile? {field: value}, note?
     */
    public static function submit(int $userId, array $in): ?array
    {
        $id = DB::transaction(function () use ($userId, $in) {
            $u = DB::table('users')->where('id', $userId)->lockForUpdate()->first(['full_name', 'phone']);
            $nameChanged = array_key_exists('full_name', $in) && self::norm($in['full_name']) !== null && self::norm($in['full_name']) !== $u->full_name;
            $phoneChanged = array_key_exists('phone', $in) && self::norm($in['phone']) !== null && self::norm($in['phone']) !== $u->phone;
            $current = MemberProfile::get($userId) ?? [];
            $changes = [];
            foreach ($in['profile'] ?? [] as $field => $value) {
                if (! in_array($field, MemberSchemas::profileFields(), true)) continue;
                $old = self::norm($current[$field] ?? null);
                $new = self::norm($value);
                if ($old !== $new) $changes[$field] = ['old' => $old, 'new' => $new];
            }
            if (! $nameChanged && ! $phoneChanged && ! $changes) return null;
            if ($phoneChanged) {
                $taken = Users::phoneOrEmailTaken($in['phone'], null, $userId);
                if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Phone already in use', $taken);
            }
            DB::table('profile_change_requests')->where(['user_id' => $userId, 'status' => 'pending'])->update(['status' => 'cancelled']);
            return DB::table('profile_change_requests')->insertGetId([
                'user_id' => $userId,
                'old_full_name' => $u->full_name,
                'old_phone' => $u->phone,
                'full_name' => $nameChanged ? self::norm($in['full_name']) : null,
                'phone' => $phoneChanged ? self::norm($in['phone']) : null,
                'changes' => $changes ? json_encode($changes, JSON_UNESCAPED_UNICODE) : null,
                'note' => self::norm($in['note'] ?? null),
            ]);
        });
        if (! $id) return null;
        $reviewers = Holders::of('users.update');
        if ($reviewers) {
            $name = DB::table('users')->where('id', $userId)->value('full_name');
            Notifications::createForUsers($reviewers, [
                'type' => 'system', 'title' => T::t('profile.request.title'), 'body' => T::t('profile.request.body', ['name' => $name]),
                'entityType' => 'profile_change', 'entityId' => $id, 'dedupeKey' => fn ($uid) => "profile-change:new:$id:$uid",
            ]);
            Notifications::kick();
        }
        return self::serialize(DB::table('profile_change_requests')->where('id', $id)->first());
    }

    /** Record applied changes, field by field (only ever added to). */
    public static function recordHistory(int $userId, array $changes, string $source, ?int $actorId, ?int $requestId = null): void
    {
        $rows = [];
        foreach ($changes as $c) {
            $old = self::norm($c['old'] ?? null);
            $new = self::norm($c['new'] ?? null);
            if ($old === $new) continue;
            $rows[] = ['user_id' => $userId, 'field' => $c['field'], 'old_value' => $old, 'new_value' => $new, 'source' => $source, 'request_id' => $requestId, 'changed_by' => $actorId];
        }
        if ($rows) DB::table('profile_change_history')->insert($rows);
    }

    /** [{field, old, new}] between the current details and an administrator's update input. */
    public static function diffForUpdate(object $current, array $input): array
    {
        $out = [];
        foreach (['full_name', 'phone', 'email', ...MemberProfile::CLASSIFICATION_FIELDS] as $k) {
            if (array_key_exists($k, $input)) {
                $old = $current->{$k} ?? null;
                if ($old instanceof \DateTimeInterface) $old = $old->format('Y-m-d');
                $new = $input[$k];
                if (is_bool($new)) $new = $new ? '1' : '0';
                if ($k === 'can_login' && $old !== null) $old = $old ? '1' : '0';
                $out[] = ['field' => $k, 'old' => $old === null ? null : (string) $old, 'new' => $new === null ? null : (string) $new];
            }
        }
        if (! empty($input['profile']) && is_array($input['profile'])) {
            $profile = MemberProfile::get((int) $current->id) ?? [];
            foreach ($input['profile'] as $k => $v) {
                if (in_array($k, MemberSchemas::profileFields(), true)) $out[] = ['field' => $k, 'old' => $profile[$k] ?? null, 'new' => $v];
            }
        }
        return $out;
    }

    public static function history(int $userId, array $page): array
    {
        $qb = DB::table('profile_change_history as h')
            ->leftJoin('users as a', 'a.id', '=', 'h.changed_by')
            ->leftJoin('roles as ar', 'ar.id', '=', 'a.role_id')
            ->where('h.user_id', $userId)
            ->orderByDesc('h.created_at')->orderByDesc('h.id')
            ->select('h.*', Actor::hiddenName('a', 'ar', 'changed_by_name'));
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($h) => [
            'id' => (int) $h->id, 'field' => $h->field, 'old' => $h->old_value, 'new' => $h->new_value, 'source' => $h->source,
            'request_id' => $h->request_id ? (int) $h->request_id : null, 'changed_by_name' => $h->changed_by_name, 'created_at' => $h->created_at,
        ], $res['items']), 'meta' => $res['meta']];
    }

    public static function cancel(int $userId): void
    {
        DB::table('profile_change_requests')->where(['user_id' => $userId, 'status' => 'pending'])->update(['status' => 'cancelled']);
    }

    public static function list(string $status, ?string $q, array $page): array
    {
        $qb = DB::table('profile_change_requests as r')
            ->join('users as u', 'u.id', '=', 'r.user_id')
            ->leftJoin('users as a', 'a.id', '=', 'r.reviewed_by')
            ->leftJoin('roles as ar', 'ar.id', '=', 'a.role_id')
            ->whereIn('u.account_type', ['user', 'admin'])
            ->select('r.*', 'u.full_name as user_name', Actor::hiddenName('a', 'ar', 'reviewed_by_name'))
            ->orderBy('r.created_at', $status === 'pending' ? 'asc' : 'desc');
        if ($status !== 'all') $qb->where('r.status', $status);
        if ($q) $qb->where(fn ($w) => $w->where('u.full_name', 'like', "%$q%")->orWhere('u.phone', 'like', "%$q%")->orWhere('r.phone', 'like', "%$q%"));
        $res = Page::paginate($qb, $page);
        return ['items' => array_map([self::class, 'serialize'], $res['items']), 'meta' => $res['meta']];
    }

    public static function pendingCount(): int
    {
        return DB::table('profile_change_requests')->where('status', 'pending')->count();
    }

    public static function review(array $actx, int $id, bool $approve, ?string $reason): void
    {
        DB::transaction(function () use ($actx, $id, $approve, $reason) {
            $r = DB::table('profile_change_requests')->where('id', $id)->lockForUpdate()->first();
            if (! $r || $r->status !== 'pending') {
                throw ApiError::notFound('REQUEST_NOT_FOUND', 'Request not found or already reviewed');
            }
            if ($approve) {
                if ($r->phone) {
                    $taken = Users::phoneOrEmailTaken($r->phone, null, $r->user_id);
                    if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Phone already in use', $taken);
                }
                $patch = [];
                if ($r->full_name) $patch['full_name'] = $r->full_name;
                if ($r->phone) $patch['phone'] = $r->phone;
                if ($patch) DB::table('users')->where('id', $r->user_id)->update($patch);
                $changes = self::changesOf($r);
                $profile = [];
                foreach ($changes as $c) {
                    if (! in_array($c['field'], ['full_name', 'phone'], true)) $profile[$c['field']] = $c['new'] ?? '';
                }
                if ($profile) MemberProfile::save((int) $r->user_id, $profile);
                self::recordHistory((int) $r->user_id, $changes, 'request', $actx['auth']->id, $id);
                Activity::track($r->user_id, Activity::PROFILE_UPDATE, metadata: ['fields' => array_column($changes, 'field'), 'approved' => true], inTrx: true);
            }
            DB::table('profile_change_requests')->where('id', $id)->update(['status' => $approve ? 'approved' : 'rejected', 'reason' => $reason, 'reviewed_by' => $actx['auth']->id, 'reviewed_at' => DB::raw('NOW()')]);
            Audit::log($actx, $approve ? Audit::PROFILE_CHANGE_APPROVE : Audit::PROFILE_CHANGE_REJECT, 'user', $r->user_id, [
                'request_id' => $id,
                'fields' => array_column(self::changesOf($r), 'field'),
                'reason' => $reason,
            ], inTrx: true);
            Notifications::createForUsers([$r->user_id], [
                'type' => 'system',
                'title' => T::t($approve ? 'profile.approved.title' : 'profile.rejected.title'),
                'body' => trim(T::t($approve ? 'profile.approved.body' : 'profile.rejected.body', ['reason' => $reason ?? ''])),
                'entityType' => 'user',
                'entityId' => $r->user_id,
                'email' => true,
                'dedupeKey' => fn () => "profile-change:$id",
            ]);
        });
        Notifications::kick();
    }
}
