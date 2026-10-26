<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Department property requests (port of propertyRequestService.js).
 * draft → submitted → under_review → approved | rejected → issued | partially_issued → returned
 * (cancelled by the requester before it is issued). Stock moves in the same transaction.
 */
final class PropertyRequests
{
    private const TRANSITIONS = [
        'submit' => [['draft'], 'submitted'],
        'review' => [['submitted'], 'under_review'],
        'approve' => [['submitted', 'under_review'], 'approved'],
        'reject' => [['submitted', 'under_review'], 'rejected'],
        'cancel' => [['draft', 'submitted', 'under_review', 'approved'], 'cancelled'],
    ];

    private static function base()
    {
        return DB::table('property_requests as r')->join('departments as d', 'd.id', '=', 'r.department_id')
            ->leftJoin('items as i', 'i.id', '=', 'r.item_id')->leftJoin('users as rq', 'rq.id', '=', 'r.requested_by')->leftJoin('users as rv', 'rv.id', '=', 'r.reviewed_by')
            ->select('r.*', 'd.name as department_name', 'd.name_en as department_name_en', 'i.name as inventory_name', 'i.code as item_code', 'i.available_quantity', 'rq.full_name as requested_by_name', 'rv.full_name as reviewed_by_name');
    }

    private static function serialize(object $r): array
    {
        return [
            'id' => $r->id,
            'department' => ['id' => $r->department_id, 'name' => $r->department_name, 'name_en' => $r->department_name_en],
            'item' => $r->item_id ? ['id' => $r->item_id, 'name' => $r->inventory_name, 'code' => $r->item_code, 'available_quantity' => $r->available_quantity] : null,
            'item_name' => $r->item_name ?? $r->inventory_name ?? null,
            'quantity' => $r->quantity,
            'purpose' => $r->purpose,
            'needed_on' => Dates::toDateOnly($r->needed_on),
            'return_on' => Dates::toDateOnly($r->return_on),
            'status' => $r->status,
            'issued_quantity' => $r->issued_quantity,
            'returned_quantity' => $r->returned_quantity,
            'requested_by_name' => $r->requested_by_name,
            'reviewed_by_name' => $r->reviewed_by_name,
            'review_note' => $r->review_note,
            'created_at' => $r->created_at,
            'updated_at' => $r->updated_at,
        ];
    }

    private static function event(int $requestId, int $actorId, string $action, ?string $from, string $to, $quantity = null, $note = null): void
    {
        DB::table('property_request_events')->insert(['request_id' => $requestId, 'action' => $action, 'from_status' => $from, 'to_status' => $to, 'quantity' => $quantity, 'note' => $note, 'actor_id' => $actorId]);
    }

    private static function row(int $id): object
    {
        $r = DB::table('property_requests')->where('id', $id)->lockForUpdate()->first();
        if (! $r) throw ApiError::notFound('REQUEST_NOT_FOUND', 'Property request not found');
        return $r;
    }

    private static function canReview(AuthContext $auth): bool
    {
        return $auth->can('property.review');
    }

    public static function get(AuthContext $auth, int $id): array
    {
        $r = self::base()->where('r.id', $id)->first();
        if (! $r || (! self::canReview($auth) && ! DepartmentAdmins::administers($auth, (int) $r->department_id))) throw ApiError::notFound('REQUEST_NOT_FOUND', 'Property request not found');
        $events = DB::table('property_request_events as e')->leftJoin('users as u', 'u.id', '=', 'e.actor_id')->where('e.request_id', $id)->orderBy('e.id')
            ->select('e.action', 'e.from_status', 'e.to_status', 'e.quantity', 'e.note', 'u.full_name as actor_name', 'e.created_at')->get()->all();
        return self::serialize($r) + ['events' => $events];
    }

    /** Reviewers see every department's requests; department administrators only their departments'. */
    public static function list(AuthContext $auth, array $f, array $page): array
    {
        $qb = self::base()->orderByDesc('r.created_at');
        if (! self::canReview($auth) && $auth->isMemberStaff) {
            $mine = array_map(fn ($d) => is_array($d) ? $d['id'] : $d->id, $auth->departments ?? []);
            $qb->whereIn('r.department_id', $mine ?: [0]);
        }
        if (! empty($f['status'])) $qb->where('r.status', $f['status']);
        if (! empty($f['department_id'])) $qb->where('r.department_id', $f['department_id']);
        if (! empty($f['q'])) {
            $q = $f['q'];
            $qb->where(fn ($w) => $w->where('i.name', 'like', "%$q%")->orWhere('r.item_name', 'like', "%$q%")->orWhere('r.purpose', 'like', "%$q%"));
        }
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($r) => self::serialize($r), $res['items']), 'meta' => $res['meta']];
    }

    public static function create(array $actx, array $input): array
    {
        $auth = $actx['auth'];
        if (! DepartmentAdmins::administers($auth, (int) $input['department_id'])) throw ApiError::forbidden('NOT_DEPARTMENT_ADMIN', 'You can only request property for your own department');
        if (empty($input['item_id']) && trim((string) ($input['item_name'] ?? '')) === '') throw ApiError::validation([['field' => 'item_name', 'code' => 'REQUIRED', 'message' => 'REQUIRED']]);
        if (! DB::table('departments')->where(['id' => $input['department_id'], 'is_active' => true])->exists()) throw ApiError::notFound('DEPARTMENT_NOT_FOUND', 'Department not found');
        if (! empty($input['item_id']) && ! DB::table('items')->where('id', $input['item_id'])->whereNull('deleted_at')->exists()) {
            throw ApiError::validation([['field' => 'item_id', 'code' => 'ITEM_NOT_FOUND', 'message' => 'ITEM_NOT_FOUND']]);
        }
        $status = ! empty($input['draft']) ? 'draft' : 'submitted';
        $id = DB::transaction(function () use ($actx, $auth, $input, $status) {
            $newId = DB::table('property_requests')->insertGetId([
                'department_id' => $input['department_id'], 'item_id' => $input['item_id'] ?? null, 'item_name' => $input['item_name'] ?? null, 'quantity' => $input['quantity'] ?? null,
                'purpose' => $input['purpose'], 'needed_on' => $input['needed_on'] ?? null, 'return_on' => $input['return_on'] ?? null, 'status' => $status, 'requested_by' => $auth->id,
            ]);
            self::event($newId, $auth->id, 'create', null, $status);
            if ($status === 'submitted') self::notifyReviewers($newId, (int) $input['department_id'], $auth->id);
            Audit::log($actx, Audit::PROPERTY_REQUEST, 'property_request', $newId, ['department_id' => $input['department_id'], 'item_id' => $input['item_id'] ?? null, 'quantity' => $input['quantity'] ?? null, 'status' => $status], inTrx: true);
            return $newId;
        });
        return self::get($auth, $id);
    }

    /** Finance & Property (property.review holders) hear about a request waiting for them. */
    private static function notifyReviewers(int $id, int $departmentId, int $actorId): void
    {
        $r = DB::table('property_requests as r')->leftJoin('items as i', 'i.id', '=', 'r.item_id')->where('r.id', $id)->first(['r.item_name', 'r.quantity', 'i.name as item']);
        $dept = DB::table('departments')->where('id', $departmentId)->value('name');
        $ids = array_values(array_filter(\App\Mz\Auth\Holders::of('property.review'), fn ($u) => (int) $u !== $actorId));
        Notifications::createForUsers($ids, [
            'type' => 'property',
            'title' => T::t('property.submitted.title'),
            'body' => T::t('property.submitted.body', ['item' => $r->item ?: $r->item_name, 'quantity' => $r->quantity ?: 1, 'department' => $dept]),
            'entityType' => 'property_request',
            'entityId' => $id,
            'dedupeKey' => fn ($uid) => "property:$id:submitted:$uid",
        ]);
    }

    public static function transition(array $actx, int $id, string $action, ?string $note): array
    {
        $auth = $actx['auth'];
        [$from, $to] = self::TRANSITIONS[$action];
        DB::transaction(function () use ($actx, $auth, $id, $action, $note, $from, $to) {
            $r = self::row($id);
            $own = DepartmentAdmins::administers($auth, (int) $r->department_id);
            $reviewAction = in_array($action, ['review', 'approve', 'reject'], true);
            if ($reviewAction && ! self::canReview($auth)) throw ApiError::forbidden();
            if (! $reviewAction && ! $own && ! self::canReview($auth)) throw ApiError::forbidden();
            if (! in_array($r->status, $from, true)) throw ApiError::conflict('INVALID_REQUEST_STATUS', "Cannot $action a {$r->status} request");
            if ($action === 'reject' && trim((string) $note) === '') throw ApiError::validation([['field' => 'note', 'code' => 'REASON_REQUIRED', 'message' => 'REASON_REQUIRED']]);
            $patch = ['status' => $to];
            if ($reviewAction) $patch += ['reviewed_by' => $auth->id, 'review_note' => $note ?? $r->review_note];
            DB::table('property_requests')->where('id', $id)->update($patch);
            self::event($id, $auth->id, $action, $r->status, $to, null, $note);
            Audit::log($actx, $reviewAction ? Audit::PROPERTY_REVIEW : Audit::PROPERTY_REQUEST, 'property_request', $id, ['action' => $action, 'from' => $r->status, 'to' => $to, 'note' => $note], inTrx: true);
            $requester = $r->requested_by;
            if ($requester && (int) $requester !== $auth->id) {
                Notifications::createForUsers([(int) $requester], [
                    'type' => 'borrowing',
                    'title' => T::t('property.request.title'),
                    'body' => T::t('property.request.body', ['status' => $to]),
                    'entityType' => 'property_request',
                    'entityId' => $id,
                    'email' => true,
                    'dedupeKey' => fn ($uid) => "property:$id:$to:$uid",
                ]);
            }
        });
        Notifications::kick();
        return self::get($auth, $id);
    }

    /** Issue (part of) an approved request; never more than available or than requested. */
    public static function issue(array $actx, int $id, array $input): array
    {
        $auth = $actx['auth'];
        DB::transaction(function () use ($actx, $auth, $id, $input) {
            $r = self::row($id);
            if (! in_array($r->status, ['approved', 'partially_issued'], true)) throw ApiError::conflict('INVALID_REQUEST_STATUS', 'Only approved requests can be issued');
            $qty = $input['quantity'] ?? null;
            $status = 'issued';
            if ($r->item_id) {
                $remaining = $r->quantity ? $r->quantity - $r->issued_quantity : null;
                $qty = $qty ?? $remaining ?? 1;
                if ($remaining !== null && $qty > $remaining) throw ApiError::validation([['field' => 'quantity', 'code' => 'ABOVE_REQUESTED', 'message' => "ABOVE_REQUESTED:$remaining"]]);
                $item = DB::table('items')->where('id', $r->item_id)->whereNull('deleted_at')->lockForUpdate()->first(['id', 'status', 'available_quantity']);
                if (! $item || $item->status !== 'active') throw ApiError::conflict('ITEM_UNAVAILABLE', 'Item is not available');
                if ($item->available_quantity < $qty) throw ApiError::conflict('INSUFFICIENT_QUANTITY', 'Not enough items available', [['field' => 'quantity', 'code' => 'INSUFFICIENT_QUANTITY', 'message' => "{$item->id}:{$item->available_quantity}"]]);
                DB::table('items')->where('id', $r->item_id)->decrement('available_quantity', $qty);
                if ($remaining !== null && $qty < $remaining) $status = 'partially_issued';
            }
            DB::table('property_requests')->where('id', $id)->update(['status' => $status, 'issued_quantity' => $r->issued_quantity + ($qty ?? 0), 'reviewed_by' => $r->reviewed_by ?? $auth->id]);
            self::event($id, $auth->id, 'issue', $r->status, $status, $qty, $input['note'] ?? null);
            Audit::log($actx, Audit::PROPERTY_ISSUE, 'property_request', $id, ['item_id' => $r->item_id, 'quantity' => $qty, 'status' => $status, 'note' => $input['note'] ?? null], inTrx: true);
        });
        return self::get($auth, $id);
    }

    public static function returnItems(array $actx, int $id, array $input): array
    {
        $auth = $actx['auth'];
        DB::transaction(function () use ($actx, $auth, $id, $input) {
            $r = self::row($id);
            if (! in_array($r->status, ['issued', 'partially_issued'], true)) throw ApiError::conflict('INVALID_REQUEST_STATUS', 'Nothing issued to return');
            $outstanding = $r->issued_quantity - $r->returned_quantity;
            $qty = $r->item_id ? ($input['quantity'] ?? $outstanding) : 0;
            if ($r->item_id && ($qty < 1 || $qty > $outstanding)) throw ApiError::validation([['field' => 'quantity', 'code' => 'INVALID_RETURN_QUANTITY', 'message' => "INVALID_RETURN_QUANTITY:$outstanding"]]);
            if ($r->item_id) DB::table('items')->where('id', $r->item_id)->increment('available_quantity', $qty);
            $status = $r->returned_quantity + $qty >= $r->issued_quantity ? 'returned' : $r->status;
            DB::table('property_requests')->where('id', $id)->update(['status' => $status, 'returned_quantity' => $r->returned_quantity + $qty]);
            $condition = $input['condition'] ?? null;
            $text = implode(' · ', array_filter([$condition ? "condition: $condition" : null, $input['note'] ?? null])) ?: null;
            self::event($id, $auth->id, 'return', $r->status, $status, $qty, $text);
            Audit::log($actx, Audit::PROPERTY_RETURN, 'property_request', $id, ['item_id' => $r->item_id, 'quantity' => $qty, 'condition' => $condition, 'status' => $status], inTrx: true);
        });
        return self::get($auth, $id);
    }
}
