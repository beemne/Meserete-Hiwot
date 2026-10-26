<?php

use App\Mz\Http\Ctx;
use App\Mz\Http\Upload;
use App\Mz\Projects\BudgetService;
use App\Mz\Projects\Bot;
use App\Mz\Projects\FeedbackService;
use App\Mz\Projects\Feed;
use App\Mz\Projects\FileService;
use App\Mz\Projects\Pm;
use App\Mz\Projects\ProjectService;
use App\Mz\Projects\ReportService;
use App\Mz\Projects\TaskService;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use App\Mz\Support\Page;
use App\Mz\Support\V;
use App\Mz\Support\Z;
use Illuminate\Support\Facades\Route;

// Department Project Management (rules: App\Mz\Projects\Access — every route is checked server-side).

/** "a,b" or a[]=…: values limited to $allowed (or positive ints). */
$csv = function (array $q, string $key, ?array $allowed = null): ?array {
    $v = $q[$key] ?? null;
    if ($v === null || $v === '') return null;
    $items = is_array($v) ? $v : explode(',', (string) $v);
    $out = [];
    foreach ($items as $i) {
        $i = trim((string) $i);
        if ($i === '') continue;
        if ($allowed === null) {
            if (! ctype_digit($i) || (int) $i < 1) throw ApiError::field($key, 'INVALID_ID');
            $out[] = (int) $i;
        } else {
            if (! in_array($i, $allowed, true)) throw ApiError::field($key, 'INVALID_VALUE');
            $out[] = $i;
        }
    }
    return array_slice(array_values(array_unique($out)), 0, 200) ?: null;
};
$flag = fn (array $q, string $k) => in_array(strtolower((string) ($q[$k] ?? '')), ['1', 'true', 'yes'], true);
$int = function (array $q, string $k) {
    $v = $q[$k] ?? null;
    if ($v === null || $v === '') return null;
    if (! ctype_digit((string) $v)) throw ApiError::field($k, 'INVALID_ID');
    return (int) $v;
};
$actx = fn () => Ctx::actx() + ['source' => in_array(request()->header('X-Client-Source'), Pm::SOURCES, true) ? request()->header('X-Client-Source') : 'app'];
$file = function (array $f) {
    $headers = ['Cache-Control' => 'private, max-age=3600', 'Content-Type' => $f['mime']];
    if ($f['name']) $headers['Content-Disposition'] = "inline; filename*=UTF-8''" . rawurlencode($f['name']);
    return response()->file($f['abs'], $headers);
};

$projectSchema = fn () => Z::object([
    'department_id' => V::id(),
    'title' => V::text(2, 200),
    'description' => V::optionalText(20000),
    'leader_id' => V::id()->nullable()->optional(),
    'team' => Z::array(V::id())->max(200)->optional(),
    'start_date' => V::dateOnly()->nullable()->optional(),
    'deadline' => V::dateTime()->nullable()->optional(),
    'status' => Z::enum(Pm::PROJECT_STATUSES)->optional(),
    'priority' => Z::enum(Pm::PRIORITIES)->optional(),
    'progress_mode' => Z::enum(['tasks', 'weighted', 'manual'])->optional(),
    'progress' => Z::number()->int()->min(0)->max(100)->optional(),
    'notes' => V::optionalText(20000),
    'allow_late_tasks' => Z::boolean()->optional(),
    'currency' => Z::string()->regex('/^[A-Z]{3}$/', 'INVALID_CURRENCY')->optional(),
    'proposed_budget' => Z::number()->min(0)->max(1e12)->nullable()->optional(),
    'reason' => V::optionalText(500),
]);
$taskSchema = fn () => Z::object([
    'title' => V::text(2, 200),
    'description' => V::optionalText(20000),
    'assignee_ids' => Z::array(V::id())->max(50)->optional(),
    'start_date' => V::dateOnly()->nullable()->optional(),
    'deadline' => V::dateTime()->nullable()->optional(),
    'priority' => Z::enum(Pm::PRIORITIES)->optional(),
    'weight' => Z::number()->int()->min(1)->max(100)->optional(),
    'notes' => V::optionalText(20000),
    'issue_id' => V::id()->nullable()->optional(),
    'program_id' => V::id()->nullable()->optional(),
    'allow_after_project_deadline' => Z::boolean()->optional(),
    'reason' => V::optionalText(500),
]);
$statusSchema = fn () => Z::object([
    'status' => Z::enum(Pm::TASK_STATUSES)->optional(),
    'reason' => V::optionalText(500),
    'pending_reason' => Z::enum(Pm::PENDING_REASONS)->nullable()->optional(),
    'progress' => Z::number()->int()->min(0)->max(100)->nullable()->optional(),
    'note' => V::optionalText(1000),
    'notes' => V::optionalText(20000),
    'base_version' => Z::number()->int()->positive()->optional(),
]);

Route::prefix('projects')->middleware('mz')->group(function () use ($csv, $flag, $int, $actx, $file, $projectSchema, $taskSchema, $statusSchema) {
    // ---- overview, my tasks, live events, approvals, categories ----
    Route::get('overview', fn () => Http::ok(ProjectService::overview(Ctx::auth())));
    Route::get('my-tasks', function () use ($csv, $flag, $int) {
        $q = Ctx::q();
        return Http::page(TaskService::mine(Ctx::auth(), [
            'status' => $csv($q, 'status', Pm::TASK_STATUSES), 'open' => $flag($q, 'open'), 'overdue' => $flag($q, 'overdue'),
            'priority' => $csv($q, 'priority', Pm::PRIORITIES), 'department_id' => $int($q, 'department_id'), 'q' => isset($q['q']) ? mb_substr((string) $q['q'], 0, 100) : null,
        ], Page::params($q)));
    });
    Route::get('events', function () use ($int) {
        $q = Ctx::q();
        return Http::ok(Feed::events(Ctx::auth(), isset($q['after']) && $q['after'] !== '' ? (int) $int($q, 'after') : null, $int($q, 'project_id'), $int($q, 'department_id')));
    });
    Route::get('departments/{id}/people', fn () => Http::ok(ProjectService::people(Ctx::auth(), Ctx::id())));
    Route::get('approvals', fn () => Http::ok(BudgetService::approvals(Ctx::auth())));
    Route::get('budget-categories', fn () => Http::ok(BudgetService::categories(($flag)(Ctx::q(), 'all'))));
    Route::post('budget-categories', fn () => Http::ok(BudgetService::saveCategory(Ctx::actx(), null, Ctx::body(Z::object(['name' => V::text(1, 120), 'name_en' => V::optionalText(120), 'sort_order' => Z::number()->int()->min(0)->max(1000)->optional(), 'is_active' => Z::boolean()->optional()])))));
    Route::patch('budget-categories/{id}', function () {
        $id = Ctx::id();
        return Http::ok(BudgetService::saveCategory(Ctx::actx(), $id, Ctx::body(Z::object(['name' => V::text(1, 120)->optional(), 'name_en' => V::optionalText(120), 'sort_order' => Z::number()->int()->min(0)->max(1000)->optional(), 'is_active' => Z::boolean()->optional()])->strict())));
    });

    // ---- reports (categorized filters) ----
    $reportFilters = function () use ($csv, $flag, $int) {
        $q = Ctx::q();
        $period = $q['period'] ?? null;
        if ($period !== null && ! in_array($period, ['today', 'week', 'month', 'custom'], true)) throw ApiError::field('period', 'INVALID_VALUE');
        foreach (['from', 'to'] as $d) if (! empty($q[$d]) && ! preg_match('/^\d{4}-\d{2}-\d{2}$/', (string) $q[$d])) throw ApiError::field($d, 'INVALID_DATE');
        $dateField = $q['date_field'] ?? 'deadline';
        if (! in_array($dateField, ['deadline', 'created', 'start', 'completed'], true)) throw ApiError::field('date_field', 'INVALID_VALUE');
        $budget = $q['budget_status'] ?? null;
        if ($budget !== null && $budget !== '' && ! in_array($budget, ['within', 'over', 'none'], true)) throw ApiError::field('budget_status', 'INVALID_VALUE');
        $f = [
            'department_id' => $int($q, 'department_id'),
            'user_ids' => $csv($q, 'user_ids'), 'created_by' => $csv($q, 'created_by'),
            'project_ids' => $csv($q, 'project_ids'), 'project_status' => $csv($q, 'project_status', Pm::PROJECT_STATUSES), 'project_priority' => $csv($q, 'project_priority', Pm::PRIORITIES),
            'project_overdue' => $flag($q, 'project_overdue'),
            'task_status' => $csv($q, 'task_status', Pm::TASK_STATUSES), 'task_priority' => $csv($q, 'task_priority', Pm::PRIORITIES), 'overdue' => $flag($q, 'overdue'),
            'period' => $period, 'from' => $q['from'] ?? null, 'to' => $q['to'] ?? null, 'date_field' => $dateField,
            'budget_status' => $budget ?: null,
        ];
        foreach (['min_progress', 'max_progress'] as $k) if (isset($q[$k]) && $q[$k] !== '') $f[$k] = max(0, min(100, (int) $q[$k]));
        return $f;
    };
    Route::get('reports/summary', fn () => Http::ok(ReportService::summary(Ctx::auth(), $reportFilters())));
    Route::get('reports/tasks', fn () => Http::page(ReportService::tasks(Ctx::auth(), $reportFilters(), Page::params(Ctx::q()))));

    // ---- tasks (by id) ----
    Route::get('tasks/{id}', fn () => Http::ok(TaskService::get(Ctx::auth(), Ctx::id())));
    Route::patch('tasks/{id}', function () use ($actx, $taskSchema) {
        $id = Ctx::id();
        return Http::ok(TaskService::update($actx(), $id, Ctx::body($taskSchema()->omit(['assignee_ids'])->partial()->strict())));
    });
    Route::delete('tasks/{id}', function () use ($actx) {
        TaskService::delete($actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::post('tasks/{id}/status', function () use ($actx, $statusSchema) {
        $id = Ctx::id();
        $out = TaskService::changeStatus($actx(), $id, Ctx::body($statusSchema()));
        if (! empty($out['conflict'])) throw ApiError::conflict('TASK_CHANGED', 'The task was changed by someone else', [['field' => 'task', 'code' => 'TASK_CHANGED', 'message' => 'TASK_CHANGED', 'server' => $out['task']]]);
        return Http::ok($out['task']);
    });
    Route::put('tasks/{id}/assignees', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['user_ids' => Z::array(V::id())->max(50), 'reason' => V::optionalText(500)]));
        return Http::ok(TaskService::setAssignees($actx(), $id, $b['user_ids'], $b['reason'] ?? null));
    });
    Route::post('tasks/{id}/ask-status', fn () => Http::ok(Bot::requestStatus($actx(), Ctx::id())));
    Route::get('tasks/{id}/comments', function () {
        $id = Ctx::id();
        \App\Mz\Projects\Access::loadTask(Ctx::auth(), $id);
        return Http::ok(FeedbackService::comments(Ctx::auth(), 'task', $id));
    });
    Route::post('tasks/{id}/comments', function () use ($actx) {
        $id = Ctx::id();
        return Http::ok(FeedbackService::addComment($actx(), 'task', $id, Ctx::body(Z::object(['body' => V::text(1, 4000)]))['body']));
    });

    // ---- issues / suggestions (by id) ----
    Route::get('issues', function () use ($csv, $flag, $int) {
        $q = Ctx::q();
        return Http::page(FeedbackService::issues(Ctx::auth(), ['project_id' => $int($q, 'project_id'), 'department_id' => $int($q, 'department_id'), 'status' => $csv($q, 'status', Pm::ISSUE_STATUSES), 'open' => $flag($q, 'open'), 'mine' => $flag($q, 'mine')], Page::params($q)));
    });
    Route::get('issues/{id}', fn () => Http::ok(FeedbackService::issue(Ctx::auth(), Ctx::id())));
    Route::patch('issues/{id}', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'title' => V::text(2, 200)->optional(), 'description' => V::optionalText(20000), 'priority' => Z::enum(Pm::PRIORITIES)->optional(),
            'status' => Z::enum(Pm::ISSUE_STATUSES)->optional(), 'assignee_id' => V::id()->nullable()->optional(), 'due_date' => V::dateOnly()->nullable()->optional(),
            'resolution' => V::optionalText(20000),
        ])->strict());
        return Http::ok(FeedbackService::updateIssue($actx(), $id, $b));
    });
    Route::post('issues/{id}/comments', function () use ($actx) {
        $id = Ctx::id();
        return Http::ok(FeedbackService::addComment($actx(), 'issue', $id, Ctx::body(Z::object(['body' => V::text(1, 4000)]))['body']));
    });
    Route::get('suggestions', function () use ($csv, $int) {
        $q = Ctx::q();
        return Http::page(FeedbackService::suggestions(Ctx::auth(), ['project_id' => $int($q, 'project_id'), 'department_id' => $int($q, 'department_id'), 'status' => $csv($q, 'status', ['submitted', 'under_review', 'accepted', 'rejected', 'converted'])], Page::params($q)));
    });
    Route::post('suggestions', function () use ($actx) {
        $b = Ctx::body(Z::object(['department_id' => V::id()->optional(), 'project_id' => V::id()->optional(), 'title' => V::text(2, 200), 'body' => V::optionalText(20000)]));
        if (empty($b['department_id']) && empty($b['project_id'])) throw ApiError::field('department_id', 'REQUIRED');
        return Http::created(FeedbackService::createSuggestion($actx(), $b));
    });
    Route::get('suggestions/{id}', fn () => Http::ok(FeedbackService::suggestion(Ctx::auth(), Ctx::id())));
    Route::patch('suggestions/{id}', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['status' => Z::enum(['under_review', 'accepted', 'rejected']), 'note' => V::optionalText(1000)]));
        return Http::ok(FeedbackService::reviewSuggestion($actx(), $id, $b['status'], $b['note'] ?? null));
    });
    Route::post('suggestions/{id}/convert', function () use ($actx, $taskSchema) {
        $id = Ctx::id();
        $b = Ctx::body($taskSchema()->partial()->extend(['project_id' => V::id()]));
        $projectId = $b['project_id'];
        unset($b['project_id']);
        return Http::ok(FeedbackService::convertSuggestion($actx(), $id, $projectId, $b));
    });
    Route::post('suggestions/{id}/comments', function () use ($actx) {
        $id = Ctx::id();
        return Http::ok(FeedbackService::addComment($actx(), 'suggestion', $id, Ctx::body(Z::object(['body' => V::text(1, 4000)]))['body']));
    });

    // ---- money (by id) ----
    Route::get('expenses', function () use ($csv, $int) {
        $q = Ctx::q();
        return Http::page(BudgetService::expenses(Ctx::auth(), ['project_id' => $int($q, 'project_id'), 'department_id' => $int($q, 'department_id'), 'status' => $csv($q, 'status', ['pending', 'approved', 'rejected', 'recorded', 'cancelled'])], Page::params($q)));
    });
    Route::patch('expenses/{id}', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['status' => Z::enum(['approved', 'rejected', 'recorded', 'cancelled']), 'note' => V::optionalText(1000), 'override' => Z::boolean()->optional()]));
        return Http::ok(BudgetService::reviewExpense($actx(), $id, $b));
    });
    Route::get('expenses/{id}/receipt', fn () => $file(BudgetService::receipt(Ctx::auth(), Ctx::id())));
    Route::patch('budget/adjustments/{id}', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['status' => Z::enum(['approved', 'rejected', 'cancelled']), 'note' => V::optionalText(1000)]));
        return Http::ok(BudgetService::reviewAdjustment($actx(), $id, $b['status'], $b['note'] ?? null));
    });
    Route::get('files/{id}', fn () => $file(FileService::download(Ctx::auth(), Ctx::id())));
    Route::delete('files/{id}', function () use ($actx) {
        FileService::remove($actx(), Ctx::id());
        return Http::ok(null);
    });

    // ---- projects ----
    Route::get('/', function () use ($csv, $flag, $int) {
        $q = Ctx::q();
        return Http::page(ProjectService::list(Ctx::auth(), [
            'department_id' => $int($q, 'department_id'), 'status' => $csv($q, 'status', Pm::PROJECT_STATUSES), 'priority' => $csv($q, 'priority', Pm::PRIORITIES),
            'active' => $flag($q, 'active'), 'overdue' => $flag($q, 'overdue'), 'mine' => $flag($q, 'mine'), 'leader_id' => $int($q, 'leader_id'),
            'q' => isset($q['q']) ? mb_substr((string) $q['q'], 0, 100) : null,
        ], Page::params($q)));
    });
    Route::post('/', fn () => Http::created(ProjectService::create($actx(), Ctx::body($projectSchema()))));
    Route::get('{id}', fn () => Http::ok(ProjectService::detail(Ctx::auth(), Ctx::id())));
    Route::patch('{id}', function () use ($actx, $projectSchema) {
        $id = Ctx::id();
        return Http::ok(ProjectService::update($actx(), $id, Ctx::body($projectSchema()->omit(['department_id', 'team'])->partial()->strict())));
    });
    Route::delete('{id}', function () use ($actx) {
        ProjectService::delete($actx(), Ctx::id());
        return Http::ok(null);
    });
    Route::put('{id}/team', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['members' => Z::array(Z::object(['user_id' => V::id()]))->max(200)]));
        return Http::ok(ProjectService::setTeam($actx(), $id, $b['members']));
    });
    Route::get('{id}/activity', fn () => Http::page(ProjectService::activity(Ctx::auth(), Ctx::id(), Page::params(Ctx::q()))));
    Route::get('{id}/activity/{logId}', fn () => Http::ok(ProjectService::activityDetail(Ctx::auth(), Ctx::id(), Ctx::id('logId'))))->whereNumber('logId');
    Route::get('{id}/tasks', function () use ($csv, $flag) {
        $id = Ctx::id();
        $q = Ctx::q();
        return Http::page(TaskService::listForProject(Ctx::auth(), $id, [
            'status' => $csv($q, 'status', Pm::TASK_STATUSES), 'open' => $flag($q, 'open'), 'overdue' => $flag($q, 'overdue'), 'priority' => $csv($q, 'priority', Pm::PRIORITIES),
            'assignee_ids' => $csv($q, 'assignee_ids'), 'mine' => $flag($q, 'mine'), 'q' => isset($q['q']) ? mb_substr((string) $q['q'], 0, 100) : null,
        ], Page::params($q + ['limit' => 100])));
    });
    Route::post('{id}/tasks', function () use ($actx, $taskSchema) {
        $id = Ctx::id();
        return Http::created(TaskService::create($actx(), $id, Ctx::body($taskSchema())));
    });
    Route::post('{id}/issues', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['title' => V::text(2, 200), 'description' => V::optionalText(20000), 'task_id' => V::id()->nullable()->optional(), 'priority' => Z::enum(Pm::PRIORITIES)->optional(), 'due_date' => V::dateOnly()->nullable()->optional()]));
        return Http::created(FeedbackService::createIssue($actx(), $id, $b));
    });
    Route::get('{id}/budget', fn () => Http::ok(BudgetService::budget(Ctx::auth(), Ctx::id())));
    Route::put('{id}/budget', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object([
            'proposed_budget' => Z::number()->min(0)->max(1e12)->nullable()->optional(),
            'currency' => Z::string()->regex('/^[A-Z]{3}$/', 'INVALID_CURRENCY')->optional(),
            'lines' => Z::array(Z::object(['category_id' => V::id(), 'amount' => Z::number()->min(0)->max(1e12)]))->max(50)->optional(),
        ])->strict());
        return Http::ok(BudgetService::setBudget($actx(), $id, $b));
    });
    Route::post('{id}/budget/approve', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['amount' => Z::number()->min(0)->max(1e12), 'note' => V::optionalText(1000)]));
        return Http::ok(BudgetService::approveBudget($actx(), $id, (float) $b['amount'], $b['note'] ?? null));
    });
    Route::post('{id}/budget/adjustments', function () use ($actx) {
        $id = Ctx::id();
        $b = Ctx::body(Z::object(['amount' => Z::number()->positive()->max(1e12), 'reason' => V::text(2, 1000)]));
        return Http::created(BudgetService::requestAdjustment($actx(), $id, (float) $b['amount'], $b['reason']));
    });
    Route::post('{id}/expenses', function () use ($actx) {
        $id = Ctx::id();
        $receipt = request()->hasFile('receipt') ? Upload::single('project', 'receipt') : (request()->hasFile('file') ? Upload::single('project') : null);
        $b = Ctx::body(Z::object([
            'amount' => Z::coerceNumber()->positive()->max(1e12),
            'category_id' => V::id()->optional(),
            'description' => V::text(2, 1000),
            'expense_date' => V::dateOnly()->optional(),
            'paid_by' => V::optionalText(150),
            'notes' => V::optionalText(1000),
        ]));
        return Http::created(BudgetService::createExpense($actx(), $id, $b, $receipt));
    });
    Route::get('{id}/files', function () use ($int) {
        $id = Ctx::id();
        $q = Ctx::q();
        return Http::ok(FileService::list(Ctx::auth(), $id, ['task_id' => $int($q, 'task_id'), 'issue_id' => $int($q, 'issue_id')]));
    });
    Route::post('{id}/files', function () use ($actx, $int) {
        $id = Ctx::id();
        $f = Upload::single('project');
        $in = Ctx::input();
        return Http::created(FileService::upload($actx(), $id, $f, ['task_id' => $int($in, 'task_id'), 'issue_id' => $int($in, 'issue_id')]));
    });
});

// The Task Bot's buttons in the department chat (same task record, same rules).
Route::post('chat/{id}/messages/{messageId}/task-status', function () use ($actx, $statusSchema) {
    $p = Ctx::params(Z::object(['id' => Z::coerceNumber()->int()->positive(), 'messageId' => Z::coerceNumber()->int()->positive()]));
    $b = Ctx::body($statusSchema());
    return Http::ok(Bot::action($actx(), $p['id'], $p['messageId'], $b));
})->middleware('mz');
