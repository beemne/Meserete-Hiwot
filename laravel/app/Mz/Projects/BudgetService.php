<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Holders;
use App\Mz\Services\Storage;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/**
 * Project budget, expenses and budget adjustments. Money is approved only by holders of
 * projects.expenses.approve (Finance and Property); the department proposes and spends. An expense
 * that would take spending over the approved budget is refused unless the approver explicitly
 * overrides it with a note (or a budget adjustment is approved first). Every change is audited.
 */
final class BudgetService
{
    private const SPENT = ['approved', 'recorded'];

    private static function spent(int $projectId, ?int $categoryId = null): float
    {
        $q = DB::table('project_expenses')->where('project_id', $projectId)->whereIn('status', self::SPENT);
        if ($categoryId) $q->where('category_id', $categoryId);
        return (float) $q->sum('amount');
    }

    public static function categories(bool $all = false): array
    {
        $q = DB::table('project_budget_categories')->orderBy('sort_order')->orderBy('id');
        if (! $all) $q->where('is_active', true);
        return $q->get(['id', 'name', 'name_en', 'sort_order', 'is_active'])->map(function ($c) {
            $c->is_active = (bool) $c->is_active;
            return $c;
        })->all();
    }

    public static function saveCategory(array $actx, ?int $id, array $in): array
    {
        $auth = $actx['auth'];
        if (! ($auth->isSystem || $auth->can('projects.expenses.approve'))) throw ApiError::forbidden();
        if ($id) {
            if (! DB::table('project_budget_categories')->where('id', $id)->exists()) throw ApiError::notFound('CATEGORY_NOT_FOUND', 'Category not found');
            DB::table('project_budget_categories')->where('id', $id)->update($in);
        } else {
            $id = DB::table('project_budget_categories')->insertGetId($in);
        }
        \App\Mz\Auth\Audit::log($actx, 'project.budget_category', 'project_budget_category', $id, $in);
        return self::categories(true);
    }

    public static function budget(AuthContext $auth, int $projectId): array
    {
        [$p, $a] = Access::loadProject($auth, $projectId);
        $spent = self::spent($projectId);
        $pending = (float) DB::table('project_expenses')->where(['project_id' => $projectId, 'status' => 'pending'])->sum('amount');
        $approved = $p->approved_budget !== null ? (float) $p->approved_budget : null;
        $lines = DB::table('project_budget_categories as c')->leftJoin('project_budget_lines as l', fn ($j) => $j->on('l.category_id', '=', 'c.id')->where('l.project_id', '=', $projectId))
            ->orderBy('c.sort_order')->get(['c.id', 'c.name', 'c.name_en', 'c.is_active', 'l.amount']);
        $users = Pm::users([$p->budget_approved_by]);
        return [
            'project_id' => (int) $p->id,
            'currency' => $p->currency,
            'proposed' => $p->proposed_budget !== null ? Pm::money($p->proposed_budget) : null,
            'approved' => $approved !== null ? Pm::money($approved) : null,
            'approved_by' => $p->budget_approved_by ? ($users[(int) $p->budget_approved_by] ?? null) : null,
            'approved_at' => $p->budget_approved_at,
            'spent' => Pm::money($spent),
            'pending' => Pm::money($pending),
            'remaining' => $approved !== null ? Pm::money($approved - $spent) : null,
            'utilization' => $approved ? round($spent / $approved * 100, 1) : null,
            'over_budget' => $approved !== null && $spent > $approved,
            'lines' => $lines->filter(fn ($l) => $l->is_active || $l->amount !== null)->map(fn ($l) => [
                'category' => ['id' => (int) $l->id, 'name' => $l->name, 'name_en' => $l->name_en],
                'planned' => $l->amount !== null ? Pm::money($l->amount) : null,
                'spent' => Pm::money(self::spent($projectId, (int) $l->id)),
            ])->values()->all(),
            'adjustments' => self::adjustments($projectId),
            'can' => ['edit' => $a['budget'], 'approve' => $a['approve'], 'spend' => $a['project_manage'] || $a['team_member']],
        ];
    }

    /** The department proposes the budget and its split by category. */
    public static function setBudget(array $actx, int $projectId, array $in): array
    {
        $auth = $actx['auth'];
        [$p] = Access::loadProject($auth, $projectId, 'budget');
        $before = ['proposed' => $p->proposed_budget, 'currency' => $p->currency, 'lines' => DB::table('project_budget_lines')->where('project_id', $projectId)->pluck('amount', 'category_id')->all()];
        DB::transaction(function () use ($actx, $projectId, $in, $before) {
            $patch = array_intersect_key($in, array_flip(['proposed_budget', 'currency']));
            if ($patch) DB::table('projects')->where('id', $projectId)->update($patch);
            if (isset($in['lines'])) {
                DB::table('project_budget_lines')->where('project_id', $projectId)->delete();
                foreach ($in['lines'] as $l) {
                    if (! DB::table('project_budget_categories')->where('id', $l['category_id'])->exists()) throw ApiError::field('lines', 'CATEGORY_NOT_FOUND');
                    DB::table('project_budget_lines')->insert(['project_id' => $projectId, 'category_id' => $l['category_id'], 'amount' => $l['amount']]);
                }
            }
            Pm::log($actx, 'project.budget.update', $projectId, ['before' => $before, 'after' => $in]);
        });
        return self::budget($auth, $projectId);
    }

    /** Finance approves (or changes) the approved budget. */
    public static function approveBudget(array $actx, int $projectId, float $amount, ?string $note): array
    {
        $auth = $actx['auth'];
        [$p] = Access::loadProject($auth, $projectId, 'approve');
        DB::transaction(function () use ($actx, $auth, $projectId, $p, $amount, $note) {
            DB::table('projects')->where('id', $projectId)->update(['approved_budget' => $amount, 'budget_approved_by' => $auth->id, 'budget_approved_at' => DB::raw('NOW()')]);
            Pm::log($actx, 'project.budget.approve', $projectId, ['before' => ['approved' => $p->approved_budget], 'after' => ['approved' => $amount], 'reason' => $note]);
        });
        Pm::notify(array_merge(Access::managersOf((int) $p->department_id), $p->leader_id ? [(int) $p->leader_id] : []), $auth->id, 'project.budget_approved.title', 'project.budget_approved.body',
            ['project' => $p->title, 'amount' => number_format($amount, 2), 'currency' => $p->currency], 'project', $projectId, "budget:$projectId:" . Pm::stamp());
        return self::budget($auth, $projectId);
    }

    // ------------------------------------------------------------------ expenses
    private static function serializeExpense(object $e): array
    {
        $users = Pm::users([$e->requested_by, $e->reviewed_by]);
        return [
            'id' => (int) $e->id,
            'project_id' => (int) $e->project_id,
            'category' => $e->category_id ? DB::table('project_budget_categories')->where('id', $e->category_id)->first(['id', 'name', 'name_en']) : null,
            'amount' => Pm::money($e->amount),
            'currency' => $e->currency,
            'description' => $e->description,
            'expense_date' => Dates::toDateOnly($e->expense_date),
            'requested_by' => $e->requested_by ? ($users[(int) $e->requested_by] ?? null) : null,
            'paid_by' => $e->paid_by,
            'receipt' => $e->receipt_path ? ['url' => "/projects/expenses/{$e->id}/receipt", 'mime' => $e->receipt_mime, 'name' => $e->receipt_name] : null,
            'status' => $e->status,
            'over_budget' => (bool) $e->over_budget,
            'reviewed_by' => $e->reviewed_by ? ($users[(int) $e->reviewed_by] ?? null) : null,
            'reviewed_at' => $e->reviewed_at,
            'review_note' => $e->review_note,
            'notes' => $e->notes,
            'created_at' => $e->created_at,
        ];
    }

    public static function expenses(AuthContext $auth, array $f, array $page): array
    {
        $qb = DB::table('project_expenses as e')->join('projects as p', 'p.id', '=', 'e.project_id')->whereNull('p.deleted_at')->select('e.*');
        if (! empty($f['project_id'])) {
            Access::loadProject($auth, (int) $f['project_id']);
            $qb->where('e.project_id', $f['project_id']);
        } elseif (! empty($f['department_id'])) {
            Access::requireDepartment($auth, (int) $f['department_id']);
            $qb->where('p.department_id', $f['department_id']);
        } else {
            $approver = $auth->isSystem || $auth->can('projects.expenses.approve');
            if (! $approver) $qb->whereIn('p.department_id', Access::visibleDepartmentIds($auth) ?: [0]);
        }
        if (! empty($f['status'])) $qb->whereIn('e.status', (array) $f['status']);
        $qb->orderByRaw("e.status = 'pending' DESC")->orderByDesc('e.id');
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(fn ($e) => self::serializeExpense($e), $res['items']);
        return $res;
    }

    public static function createExpense(array $actx, int $projectId, array $in, ?UploadedFile $receipt): array
    {
        $auth = $actx['auth'];
        [$p, $a] = Access::loadProject($auth, $projectId);
        if (! ($a['project_manage'] || $a['team_member'])) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only the project team submits expenses');
        if (! empty($in['category_id']) && ! DB::table('project_budget_categories')->where('id', $in['category_id'])->exists()) throw ApiError::field('category_id', 'CATEGORY_NOT_FOUND');
        $saved = $receipt ? Storage::save('project', Storage::FOLDERS['PROJECTS'], $receipt) : null;
        $over = $p->approved_budget === null || self::spent($projectId) + (float) $in['amount'] > (float) $p->approved_budget;
        try {
            $id = DB::transaction(function () use ($actx, $auth, $p, $in, $saved, $receipt, $over) {
                $id = DB::table('project_expenses')->insertGetId([
                    'project_id' => $p->id, 'category_id' => $in['category_id'] ?? null, 'amount' => $in['amount'], 'currency' => $p->currency,
                    'description' => $in['description'], 'expense_date' => $in['expense_date'] ?? Dates::todayLocal(), 'requested_by' => $auth->id, 'paid_by' => $in['paid_by'] ?? null,
                    'receipt_path' => $saved['path'] ?? null, 'receipt_mime' => $saved['mime'] ?? null,
                    'receipt_name' => $receipt ? mb_substr(preg_replace('/[^\p{L}\p{N}._ -]/u', '', (string) $receipt->getClientOriginalName()), 0, 150) ?: null : null,
                    'over_budget' => $over, 'notes' => $in['notes'] ?? null,
                ]);
                Pm::log($actx, 'project.expense.submit', (int) $p->id, ['expense_id' => $id, 'after' => ['amount' => $in['amount'], 'category_id' => $in['category_id'] ?? null, 'over_budget' => $over]]);
                return $id;
            });
        } catch (\Throwable $e) {
            if ($saved) Storage::remove($saved['path']);
            throw $e;
        }
        Pm::notify(Holders::of('projects.expenses.approve'), $auth->id, 'project.expense.title', 'project.expense.body',
            ['amount' => number_format((float) $in['amount'], 2), 'currency' => $p->currency, 'description' => $in['description'], 'project' => $p->title], 'project_expense', $id, "exp:$id:new");
        return self::serializeExpense(DB::table('project_expenses')->where('id', $id)->first());
    }

    /**
     * approved / rejected / recorded: Finance. cancelled: the requester or a manager, while pending.
     * Approving over the approved budget needs override = true and a note.
     */
    public static function reviewExpense(array $actx, int $id, array $in): array
    {
        $auth = $actx['auth'];
        $e = DB::table('project_expenses')->where('id', $id)->first();
        if (! $e) throw ApiError::notFound('EXPENSE_NOT_FOUND', 'Expense not found');
        [$p, $a] = Access::loadProject($auth, (int) $e->project_id);
        $status = $in['status'];
        $note = isset($in['note']) ? trim((string) $in['note']) : null;
        if ($status === 'cancelled') {
            if ($e->status !== 'pending') throw ApiError::conflict('EXPENSE_NOT_PENDING', 'Only a pending expense can be cancelled');
            if ((int) $e->requested_by !== $auth->id && ! $a['project_manage']) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only the requester or a manager cancels');
        } else {
            if (! $a['approve']) throw ApiError::forbidden('EXPENSE_APPROVE_FORBIDDEN', 'Only Finance approves expenses');
            $from = ['approved' => ['pending'], 'rejected' => ['pending'], 'recorded' => ['approved']][$status];
            if (! in_array($e->status, $from, true)) throw ApiError::conflict('EXPENSE_STATUS', 'This expense cannot move to that status');
            if ($status === 'rejected' && ! $note) throw ApiError::field('note', 'REASON_REQUIRED');
            if ($status === 'approved') {
                $budget = $p->approved_budget;
                $over = $budget === null || self::spent((int) $p->id) + (float) $e->amount > (float) $budget;
                if ($over && empty($in['override'])) throw ApiError::conflict('OVER_BUDGET', 'This expense goes over the approved budget; approve a budget adjustment or override with a note');
                if ($over && ! $note) throw ApiError::field('note', 'REASON_REQUIRED');
            }
        }
        DB::transaction(function () use ($actx, $auth, $e, $status, $note, $in) {
            DB::table('project_expenses')->where('id', $e->id)->update(['status' => $status, 'reviewed_by' => $auth->id, 'reviewed_at' => DB::raw('NOW()'), 'review_note' => $note]);
            Pm::log($actx, 'project.expense.' . $status, (int) $e->project_id, ['expense_id' => (int) $e->id, 'before' => ['status' => $e->status], 'after' => ['status' => $status, 'override' => (bool) ($in['override'] ?? false)], 'reason' => $note]);
        });
        Pm::notify(array_merge([(int) $e->requested_by], $p->leader_id ? [(int) $p->leader_id] : [], Access::managersOf((int) $p->department_id)), $auth->id, 'project.expense_reviewed.title', 'project.expense_reviewed.body',
            ['amount' => number_format((float) $e->amount, 2), 'currency' => $e->currency, 'project' => $p->title, 'status' => T::t("expense.status.$status")], 'project_expense', (int) $e->id, "exp:{$e->id}:$status");
        return self::serializeExpense(DB::table('project_expenses')->where('id', $id)->first());
    }

    public static function receipt(AuthContext $auth, int $id): array
    {
        $e = DB::table('project_expenses')->where('id', $id)->first();
        if (! $e || ! $e->receipt_path) throw ApiError::notFound();
        try {
            Access::loadProject($auth, (int) $e->project_id);
        } catch (ApiError) {
            throw ApiError::notFound();
        }
        $abs = Storage::privatePath($e->receipt_path);
        if (! is_file($abs)) throw ApiError::notFound();
        return ['abs' => $abs, 'mime' => $e->receipt_mime, 'name' => $e->receipt_name];
    }

    // ------------------------------------------------------------------ budget adjustments
    private static function adjustments(int $projectId): array
    {
        $rows = DB::table('project_budget_adjustments')->where('project_id', $projectId)->orderByDesc('id')->get();
        $users = Pm::users(array_merge($rows->pluck('requested_by')->all(), $rows->pluck('reviewed_by')->all()));
        return $rows->map(fn ($r) => [
            'id' => (int) $r->id, 'current_budget' => $r->current_budget !== null ? Pm::money($r->current_budget) : null, 'amount' => Pm::money($r->amount), 'reason' => $r->reason,
            'status' => $r->status, 'requested_by' => $users[(int) $r->requested_by] ?? null, 'reviewed_by' => $r->reviewed_by ? ($users[(int) $r->reviewed_by] ?? null) : null,
            'reviewed_at' => $r->reviewed_at, 'review_note' => $r->review_note, 'created_at' => $r->created_at,
        ])->all();
    }

    public static function requestAdjustment(array $actx, int $projectId, float $amount, string $reason): array
    {
        $auth = $actx['auth'];
        [$p] = Access::loadProject($auth, $projectId, 'budget');
        $id = DB::transaction(function () use ($actx, $auth, $p, $amount, $reason) {
            $id = DB::table('project_budget_adjustments')->insertGetId(['project_id' => $p->id, 'current_budget' => $p->approved_budget, 'amount' => $amount, 'reason' => $reason, 'requested_by' => $auth->id]);
            Pm::log($actx, 'project.budget.adjustment_request', (int) $p->id, ['adjustment_id' => $id, 'after' => ['amount' => $amount], 'reason' => $reason]);
            return $id;
        });
        Pm::notify(Holders::of('projects.expenses.approve'), $auth->id, 'project.adjustment.title', 'project.adjustment.body',
            ['project' => $p->title, 'amount' => number_format($amount, 2), 'currency' => $p->currency, 'reason' => $reason], 'project', (int) $p->id, "adj:$id:new");
        return self::budget($auth, $projectId);
    }

    public static function reviewAdjustment(array $actx, int $id, string $status, ?string $note): array
    {
        $auth = $actx['auth'];
        $r = DB::table('project_budget_adjustments')->where('id', $id)->first();
        if (! $r) throw ApiError::notFound('ADJUSTMENT_NOT_FOUND', 'Adjustment not found');
        [$p, $a] = Access::loadProject($auth, (int) $r->project_id);
        if ($status === 'cancelled') {
            if ((int) $r->requested_by !== $auth->id && ! $a['budget']) throw ApiError::forbidden();
        } elseif (! $a['approve']) {
            throw ApiError::forbidden('EXPENSE_APPROVE_FORBIDDEN', 'Only Finance approves budget adjustments');
        }
        if ($r->status !== 'pending') throw ApiError::conflict('ADJUSTMENT_NOT_PENDING', 'This request was already decided');
        if ($status === 'rejected' && ! $note) throw ApiError::field('note', 'REASON_REQUIRED');
        DB::transaction(function () use ($actx, $auth, $r, $p, $status, $note) {
            DB::table('project_budget_adjustments')->where('id', $r->id)->update(['status' => $status, 'reviewed_by' => $auth->id, 'reviewed_at' => DB::raw('NOW()'), 'review_note' => $note]);
            if ($status === 'approved') {
                $new = (float) ($p->approved_budget ?? 0) + (float) $r->amount;
                DB::table('projects')->where('id', $p->id)->update(['approved_budget' => $new, 'budget_approved_by' => $auth->id, 'budget_approved_at' => DB::raw('NOW()')]);
                Pm::log($actx, 'project.budget.adjustment_approved', (int) $p->id, ['adjustment_id' => (int) $r->id, 'before' => ['approved' => $p->approved_budget], 'after' => ['approved' => $new], 'reason' => $note]);
            } else {
                Pm::log($actx, 'project.budget.adjustment_' . $status, (int) $p->id, ['adjustment_id' => (int) $r->id, 'reason' => $note]);
            }
        });
        if ($status !== 'cancelled') {
            Pm::notify(array_merge([(int) $r->requested_by], Access::managersOf((int) $p->department_id)), $auth->id, 'project.adjustment_reviewed.title', 'project.adjustment_reviewed.body',
                ['project' => $p->title, 'amount' => number_format((float) $r->amount, 2), 'currency' => $p->currency, 'status' => T::t("expense.status.$status")], 'project', (int) $p->id, "adj:{$r->id}:$status");
        }
        return self::budget($auth, (int) $p->id);
    }

    /** Approver's queue: pending expenses and adjustments across departments. */
    public static function approvals(AuthContext $auth): array
    {
        if (! ($auth->isSystem || $auth->can('projects.expenses.approve'))) throw ApiError::forbidden();
        $exp = DB::table('project_expenses as e')->join('projects as p', 'p.id', '=', 'e.project_id')->whereNull('p.deleted_at')->where('e.status', 'pending')->orderBy('e.id')->select('e.*', 'p.title as project_title')->get();
        $adj = DB::table('project_budget_adjustments as a')->join('projects as p', 'p.id', '=', 'a.project_id')->whereNull('p.deleted_at')->where('a.status', 'pending')->orderBy('a.id')->select('a.*', 'p.title as project_title', 'p.currency')->get();
        return [
            'expenses' => $exp->map(fn ($e) => self::serializeExpense($e) + ['project_title' => $e->project_title])->all(),
            'adjustments' => $adj->map(fn ($a) => ['id' => (int) $a->id, 'project_id' => (int) $a->project_id, 'project_title' => $a->project_title, 'amount' => Pm::money($a->amount), 'currency' => $a->currency, 'reason' => $a->reason, 'current_budget' => $a->current_budget !== null ? Pm::money($a->current_budget) : null, 'created_at' => $a->created_at])->all(),
        ];
    }
}
