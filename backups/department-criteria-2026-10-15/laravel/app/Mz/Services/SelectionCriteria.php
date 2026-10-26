<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

/**
 * Department-owned selection criteria for a holiday selection (configuration "v2").
 *
 * The 100 points are split, by policy (fixed — nobody edits the split):
 *   Education 50   — the education administrators (education.manage),
 *   Mezmur 30      — the Mezmur administrators (choir.manage),
 *   Monthly dues 10 — the monthly-due collection approvers (payments.manage),
 *   Department participation 10 — not configured by anyone: it is the monthly participation score
 *     each department's own administrators / leader record for their members.
 * Holding the permission only through the general Admin / High admin / system roles does NOT
 * count: the permission must come from a specific role, a department-administrator role or a
 * direct grant. The part's administrators define its categories, submit it and approve their
 * evaluators' scores.
 * Each department divides its share among any number of categories it defines: built-in ones that
 * reuse the existing calculations (course attendance, exams, Mezmur attendance, contribution,
 * participation) or manually evaluated ones (interview, practical test …) whose scores evaluators
 * enter and the department approves.
 *
 *   contribution  = raw ÷ maximum × category weight        (built-in: percent ÷ 100 × weight)
 *   department    = Σ its contributions                      final = Σ departments  (≤ 100)
 *
 * Nothing is rounded before the final comparison and ranking. A category without a value is
 * "pending" or "missing" — never 0 — and the applicant's outcome is then 'pending'.
 *
 * Workflow: departments edit their own section of a draft version and submit it (weights must add
 * up to the department's allocation); when every section and the allocation (= 100) are in, the
 * version is submitted; a high-level administrator (selection.finalize) approves or rejects it — never
 * someone who submitted one of its sections. Only an approved version is used for results, and it
 * is stored with each result; changing it afterwards means a new revision that is approved again.
 */
final class SelectionCriteria
{
    public const DEPARTMENTS = ['education', 'mezmur', 'dues', 'participation'];
    public const BUILT_IN = ['course_attendance', 'exam', 'mezmur_attendance', 'contribution', 'participation'];
    /** The fixed split of the 100 points. */
    public const ALLOCATION = ['education' => 50, 'mezmur' => 30, 'dues' => 10, 'participation' => 10];
    /** months: the Ethiopian months (YYYY-MM … YYYY-MM) counted for the monthly parts — dues and department participation; null = the selection's dates. */
    public const DEFAULT_PASSING = ['total_minimum' => 50, 'department_minimums' => [], 'quota' => null, 'months' => null];
    /** The longest monthly range. */
    public const MAX_MONTHS = 24;
    /** The administrators of each configurable part. */
    public const EDITORS = ['education' => 'education.manage', 'mezmur' => 'choir.manage', 'dues' => 'payments.manage'];
    /**
     * Each configurable part's own department (departments.code_prefix): its administrators prepare
     * the part whatever role they were given there (e.g. the Hymns & Arts department's administrator
     * is the Mezmur administrator even with the general "Admin" department role).
     */
    public const PART_DEPARTMENTS = ['education' => 'EDU', 'mezmur' => 'HYM', 'dues' => 'FIN'];
    /** Not configured: the departments' monthly participation scores, always the same single category. */
    public const FIXED_PARTS = ['participation'];
    /** Roles that hold almost every permission: they never make someone a part's administrator by themselves. */
    public const GENERAL_ROLES = ['system_authority', 'high_admin', 'admin'];
    private const EPS = 0.000001;

    // ------------------------------------------------------------------ versions

    private static function decode(object $v): array
    {
        return [
            'id' => (int) $v->id, 'selection_id' => (int) $v->selection_id, 'version' => (int) $v->version, 'status' => $v->status,
            'allocation' => json_decode($v->allocation, true), 'passing' => json_decode($v->passing, true), 'departments' => json_decode($v->departments, true),
            'hash' => $v->hash, 'created_by' => $v->created_by, 'submitted_at' => $v->submitted_at, 'decided_by' => $v->decided_by, 'decided_at' => $v->decided_at,
            'comment' => $v->comment, 'created_at' => $v->created_at, 'updated_at' => $v->updated_at,
        ];
    }

    private static function selection(int $id, bool $lock = false): object
    {
        $q = DB::table('holiday_selections')->where('id', $id);
        if ($lock) $q->lockForUpdate();
        $s = $q->first();
        if (! $s) throw ApiError::notFound('SELECTION_NOT_FOUND', 'Selection not found');
        return $s;
    }

    private static function latest(int $selectionId, bool $lock = false): ?object
    {
        $q = DB::table('selection_config_versions')->where('selection_id', $selectionId)->orderByDesc('version');
        if ($lock) $q->lockForUpdate();
        return $q->first();
    }

    /**
     * The monthly range (Ethiopian periods) the monthly parts are counted over for this selection:
     * the approved criteria's own range, else null (the selection's dates / its contribution months).
     */
    public static function monthRange(int $selectionId): ?array
    {
        $m = self::active($selectionId)['passing']['months'] ?? null;
        return $m && ! empty($m['from']) && ! empty($m['to']) ? ['from' => $m['from'], 'to' => $m['to']] : null;
    }

    /** The approved version in force (null: the selection still uses the former fixed components). */
    public static function active(int $selectionId): ?array
    {
        $v = DB::table('selection_config_versions')->where(['selection_id' => $selectionId, 'status' => 'approved'])->orderByDesc('version')->first();
        return $v ? self::decode($v) : null;
    }

    /**
     * Starting point: the selection's own components, grouped by department — their weights scaled
     * to the fixed split (so each section can be submitted as is), their minimums kept (scaled the
     * same way) — and the selection's own passing score.
     */
    private static function seed(object $sel): array
    {
        $cfg = Selections::mergeConfig(json_decode($sel->config, true) ?: []);
        $names = ['course_attendance' => 'የትምህርት ክፍል ተሳትፎ', 'exam' => 'ፈተና', 'mezmur_attendance' => 'የመዝሙር ክፍል ተሳትፎ', 'contribution' => 'ወርሃዊ መዋጮ'];
        $parts = ['education' => ['course_attendance', 'exam'], 'mezmur' => ['mezmur_attendance'], 'dues' => ['contribution']];
        $out = [];
        foreach ($parts as $d => $keys) {
            $sum = array_sum(array_map(fn ($k) => (float) ($cfg['weights'][$k] ?? 0), $keys));
            // Scale to the part's share; with no weight at all the share is divided equally.
            $f = $sum > 0 ? self::ALLOCATION[$d] / $sum : null;
            $criteria = [];
            foreach ($keys as $k) {
                $weight = $f === null ? self::ALLOCATION[$d] / count($keys) : (float) ($cfg['weights'][$k] ?? 0) * $f;
                $min = $cfg['minimums'][$k] ?? null;
                $min = $min === null || $f === null ? null : min($weight, round((float) $min * $f, 4));
                $criteria[] = ['key' => $k, 'name' => $names[$k], 'source' => $k, 'weight' => round($weight, 4), 'max_score' => 100, 'min_points' => $min ?: null, 'enabled' => true];
            }
            $out[$d] = ['status' => 'draft', 'criteria' => $criteria];
        }
        return $out + ['participation' => self::fixedSection()];
    }

    /** The passing rules a first draft starts from: the selection's own passing score. */
    private static function seedPassing(object $sel): array
    {
        $cfg = Selections::mergeConfig(json_decode($sel->config, true) ?: []);
        return ['total_minimum' => (float) ($cfg['total_minimum'] ?? self::DEFAULT_PASSING['total_minimum'])] + self::DEFAULT_PASSING;
    }

    /**
     * A first draft nobody has changed yet is seeded again from the selection's current settings
     * (drafts started before seeding kept the selection's passing score and minimums).
     */
    public static function reseedUntouched(): int
    {
        $n = 0;
        $rows = DB::table('selection_config_versions')->where(['status' => 'draft', 'version' => 1])->whereColumn('created_at', 'updated_at')->get();
        foreach ($rows as $v) {
            $sel = DB::table('holiday_selections')->where('id', $v->selection_id)->first();
            if (! $sel || in_array($sel->status, ['finalized', 'cancelled'], true)) continue;
            $n += DB::table('selection_config_versions')->where('id', $v->id)->update([
                'passing' => json_encode(self::seedPassing($sel)), 'departments' => json_encode(self::seed($sel), JSON_UNESCAPED_UNICODE),
            ]);
        }
        return $n;
    }

    public static function versions(int $selectionId): array
    {
        self::selection($selectionId);
        return DB::table('selection_config_versions')->where('selection_id', $selectionId)->orderByDesc('version')->get()->map(fn ($v) => self::decode($v))->all();
    }

    /** The version being edited: the latest draft / rejected one, or a first draft seeded from the existing components. */
    private static function editable(array $actx, int $selectionId): object
    {
        $sel = self::selection($selectionId, true);
        if (in_array($sel->status, ['finalized', 'cancelled'], true)) throw ApiError::conflict('SELECTION_LOCKED', 'The criteria of a finalized selection do not change');
        $v = self::latest($selectionId, true);
        if (! $v) {
            $id = DB::table('selection_config_versions')->insertGetId([
                'selection_id' => $selectionId, 'version' => 1, 'status' => 'draft',
                'allocation' => json_encode(self::ALLOCATION), 'passing' => json_encode(self::seedPassing($sel)),
                'departments' => json_encode(self::seed($sel), JSON_UNESCAPED_UNICODE), 'created_by' => $actx['auth']->id,
            ]);
            return DB::table('selection_config_versions')->where('id', $id)->first();
        }
        if ($v->status === 'rejected') {
            DB::table('selection_config_versions')->where('id', $v->id)->update(['status' => 'draft']);
            $v->status = 'draft';
        }
        if ($v->status === 'submitted') throw ApiError::conflict('CONFIG_IN_REVIEW', 'This version is waiting for approval');
        if ($v->status !== 'draft') throw ApiError::conflict('CONFIG_APPROVED', 'The approved criteria are changed through a new revision');
        return $v;
    }

    /** The department participation part: one built-in category, already complete. */
    private static function fixedSection(): array
    {
        return ['status' => 'submitted', 'fixed' => true, 'criteria' => [
            ['key' => 'participation', 'name' => 'የዲፓርትመንት ተሳትፎ', 'source' => 'participation', 'weight' => (float) self::ALLOCATION['participation'], 'max_score' => 100, 'min_points' => null, 'enabled' => true],
        ]];
    }

    /**
     * A part's administrators: the part's permission held through a specific role (e.g. Moderator,
     * Education / Hymns / Planning department roles, Payments manager), a department-administrator
     * role or a direct grant — not merely through the general Admin / High admin / system roles.
     * A permission revoked for the person never counts. The participation part has no editors.
     */
    public static function canEdit(AuthContext $auth, string $dept): bool
    {
        $perm = self::EDITORS[$dept] ?? null;
        if (! $perm) return false;
        $pid = DB::table('permissions')->where('key', $perm)->value('id');
        // The part's own department: its administrators, unless the permission was revoked for them.
        $ownDepartment = DB::table('department_admins as da')->join('roles as r', 'r.id', '=', 'da.role_id')->join('departments as d', 'd.id', '=', 'da.department_id')
            ->where(['da.user_id' => $auth->id, 'r.is_active' => true, 'd.is_active' => true, 'd.code_prefix' => self::PART_DEPARTMENTS[$dept]])->exists();
        if ($ownDepartment && ! DB::table('user_permission_revocations')->where(['user_id' => $auth->id, 'permission_id' => $pid])->exists()) return true;
        if (! $auth->can($perm)) return false;
        if (DB::table('user_permissions')->where(['user_id' => $auth->id, 'permission_id' => $pid])->exists()) return true;
        $viaRole = DB::table('users as u')->join('roles as r', 'r.id', '=', 'u.role_id')->join('role_permissions as rp', 'rp.role_id', '=', 'r.id')
            ->where(['u.id' => $auth->id, 'u.account_type' => 'admin', 'r.is_active' => true, 'rp.permission_id' => $pid])->whereNotIn('r.slug', self::GENERAL_ROLES)->exists();
        if ($viaRole) return true;
        return DB::table('department_admins as da')->join('roles as r', 'r.id', '=', 'da.role_id')->join('departments as d', 'd.id', '=', 'da.department_id')->join('role_permissions as rp', 'rp.role_id', '=', 'r.id')
            ->where(['da.user_id' => $auth->id, 'r.is_active' => true, 'd.is_active' => true, 'rp.permission_id' => $pid])->whereNotIn('r.slug', self::GENERAL_ROLES)->exists();
    }

    /** Who prepares each configurable part (names), so a part nobody can prepare is visible. */
    public static function editors(): array
    {
        $ids = DB::table('users')->where(['account_type' => 'admin', 'status' => 'active'])->whereNull('deleted_at')->pluck('id')
            ->merge(DB::table('department_admins')->pluck('user_id'))
            ->merge(DB::table('user_permissions')->pluck('user_id'))->unique()->all();
        $names = DB::table('users')->whereIn('id', $ids ?: [0])->where('status', 'active')->whereNull('deleted_at')->pluck('full_name', 'id');
        $out = array_fill_keys(array_keys(self::EDITORS), []);
        foreach ($names as $id => $name) {
            $auth = AuthContext::load((int) $id);
            if (! $auth) continue;
            foreach (array_keys(self::EDITORS) as $d) if (self::canEdit($auth, $d)) $out[$d][] = $name;
        }
        return $out;
    }

    /** The parts the signed-in member administers. */
    public static function editableParts(AuthContext $auth): array
    {
        return array_values(array_filter(self::DEPARTMENTS, fn ($d) => self::canEdit($auth, $d)));
    }

    /** May open the criteria: a selection reader, the final approver, or an administrator of one of the four departments. */
    public static function assertCanView(AuthContext $auth): void
    {
        foreach (['selection.view', 'selection.configure', 'selection.review', 'selection.finalize'] as $p) if ($auth->can($p)) return;
        if (! self::editableParts($auth)) throw ApiError::forbidden();
    }

    /** What the signed-in member may do with this selection's criteria (the app shows only that). */
    public static function access(AuthContext $auth): array
    {
        return ['can_edit' => array_fill_keys(self::editableParts($auth), true) + array_fill_keys(self::DEPARTMENTS, false), 'can_decide' => $auth->can('selection.finalize')];
    }

    /** Selections whose criteria the member's departments prepare (for department administrators). */
    public static function mine(AuthContext $auth): array
    {
        $parts = self::editableParts($auth);
        if (! $parts && ! $auth->can('selection.finalize')) return ['parts' => [], 'selections' => []];
        $rows = DB::table('holiday_selections')->whereIn('status', ['draft', 'open', 'review'])->orderByDesc('from_date')->get(['id', 'name', 'from_date', 'to_date', 'status'])->all();
        foreach ($rows as $r) {
            $v = self::latest((int) $r->id);
            $r->criteria_version = $v ? (int) $v->version : null;
            $r->criteria_status = $v?->status;
            $r->sections = $v ? array_map(fn ($s) => $s['status'] ?? 'draft', json_decode($v->departments, true)) : null;
        }
        return ['parts' => $parts, 'selections' => $rows];
    }

    /** Start (or open) the draft; an administrator of one of the four departments or the final approver. */
    public static function draft(array $actx, int $selectionId): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('selection.finalize') && ! self::editableParts($auth)) throw ApiError::forbidden();
        return DB::transaction(fn () => self::decode(self::editable($actx, $selectionId)));
    }

    /**
     * High-level administrator: the passing rules (overall passing score, seats, department
     * minimums). The 50 / 30 / 10 / 10 split itself is fixed and is not edited here.
     */
    public static function setRules(array $actx, int $selectionId, array $passing): array
    {
        if (! $actx['auth']->can('selection.finalize')) throw ApiError::forbidden();
        return DB::transaction(function () use ($actx, $selectionId, $passing) {
            $v = self::editable($actx, $selectionId);
            $alloc = self::ALLOCATION;
            $deptMin = array_intersect_key($passing['department_minimums'] ?? [], array_flip(self::DEPARTMENTS));
            foreach ($deptMin as $d => $m) if ($m !== null && $m > $alloc[$d] + self::EPS) throw ApiError::field("passing.department_minimums.$d", 'MINIMUM_ABOVE_ALLOCATION');
            $months = $passing['months'] ?? null;
            if ($months !== null) {
                if (strcmp($months['from'], $months['to']) > 0) throw ApiError::field('passing.months.to', 'END_BEFORE_START');
                if (Ethiopian::monthCount($months['from'], $months['to']) > self::MAX_MONTHS) throw ApiError::field('passing.months', 'RANGE_TOO_LONG');
                $months = ['from' => $months['from'], 'to' => $months['to']];
            }
            $p = ['total_minimum' => (float) ($passing['total_minimum'] ?? 0), 'department_minimums' => $deptMin, 'quota' => isset($passing['quota']) && $passing['quota'] ? (int) $passing['quota'] : null, 'months' => $months];
            // The departments' weights were checked against the old allocation: they submit again.
            $depts = json_decode($v->departments, true);
            $before = json_decode($v->allocation, true);
            foreach (self::DEPARTMENTS as $d) {
                if (in_array($d, self::FIXED_PARTS, true)) $depts[$d] = self::fixedSection();
                elseif (abs(($before[$d] ?? 0) - $alloc[$d]) > self::EPS) $depts[$d]['status'] = 'draft';
            }
            DB::table('selection_config_versions')->where('id', $v->id)->update(['allocation' => json_encode($alloc), 'passing' => json_encode($p), 'departments' => json_encode($depts, JSON_UNESCAPED_UNICODE)]);
            Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $selectionId, ['criteria_version' => $v->version, 'allocation' => $alloc, 'passing' => $p], inTrx: true);
            return self::decode(DB::table('selection_config_versions')->where('id', $v->id)->first());
        });
    }

    private static function normalizeCriteria(int $selectionId, string $dept, array $criteria, array $otherDepts): array
    {
        $out = [];
        $keys = [];
        foreach ($otherDepts as $d => $section) if ($d !== $dept) foreach ($section['criteria'] as $c) $keys[$c['key']] = $d;
        foreach (array_values($criteria) as $i => $c) {
            $key = $c['key'] ?? null;
            if (! $key) throw ApiError::field("criteria.$i.key", 'REQUIRED');
            if (isset($keys[$key])) throw ApiError::field("criteria.$i.key", 'DUPLICATE_KEY');
            $keys[$key] = $dept;
            $source = $c['source'] ?? 'manual';
            if ($source !== 'manual' && ! in_array($source, self::BUILT_IN, true)) throw ApiError::field("criteria.$i.source", 'INVALID');
            $weight = (float) ($c['weight'] ?? 0);
            $max = $source === 'manual' ? (float) ($c['max_score'] ?? 0) : 100.0;
            if ($weight < 0) throw ApiError::field("criteria.$i.weight", 'INVALID');
            if ($max <= 0) throw ApiError::field("criteria.$i.max_score", 'REQUIRED');
            $min = isset($c['min_points']) && $c['min_points'] !== null ? (float) $c['min_points'] : null;
            if ($min !== null && $min > $weight + self::EPS) throw ApiError::field("criteria.$i.min_points", 'MINIMUM_ABOVE_WEIGHT');
            $out[] = ['key' => $key, 'name' => $c['name'], 'name_en' => $c['name_en'] ?? null, 'source' => $source, 'weight' => $weight, 'max_score' => $max, 'min_points' => $min, 'enabled' => (bool) ($c['enabled'] ?? true)];
        }
        // Each built-in source is counted once in the whole configuration.
        $sources = [];
        foreach ($otherDepts as $d => $section) if ($d !== $dept) foreach ($section['criteria'] as $c) if ($c['source'] !== 'manual' && $c['enabled']) $sources[$c['source']] = true;
        foreach ($out as $i => $c) {
            if ($c['source'] === 'manual' || ! $c['enabled']) continue;
            if (isset($sources[$c['source']])) throw ApiError::field("criteria.$i.source", 'SOURCE_ALREADY_USED');
            $sources[$c['source']] = true;
        }
        return $out;
    }

    /** A department edits its own categories (order = list order; disabled ones are kept but not counted). */
    public static function setDepartment(array $actx, int $selectionId, string $dept, array $criteria): array
    {
        if (in_array($dept, self::FIXED_PARTS, true)) throw ApiError::forbidden('FIXED_PART', 'Department participation is scored by each department every month; it is not configured here');
        if (! self::canEdit($actx['auth'], $dept)) throw ApiError::forbidden();
        return DB::transaction(function () use ($actx, $selectionId, $dept, $criteria) {
            $v = self::editable($actx, $selectionId);
            $depts = json_decode($v->departments, true);
            $depts[$dept] = ['status' => 'draft', 'criteria' => self::normalizeCriteria($selectionId, $dept, $criteria, $depts)];
            DB::table('selection_config_versions')->where('id', $v->id)->update(['departments' => json_encode($depts, JSON_UNESCAPED_UNICODE)]);
            Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $selectionId, ['criteria_version' => $v->version, 'department' => $dept, 'criteria' => $depts[$dept]['criteria']], inTrx: true);
            return self::decode(DB::table('selection_config_versions')->where('id', $v->id)->first());
        });
    }

    /** Validation errors of a version (empty = complete and consistent). */
    public static function problems(array $v): array
    {
        $errors = [];
        foreach (self::ALLOCATION as $d => $share) {
            if (abs((float) ($v['allocation'][$d] ?? -1) - $share) > self::EPS) $errors[] = ['field' => "allocation.$d", 'code' => 'ALLOCATION_IS_FIXED', 'message' => 'ALLOCATION_IS_FIXED:50/30/10/10'];
        }
        foreach (self::DEPARTMENTS as $d) $errors = array_merge($errors, self::departmentProblems($v, $d));
        return $errors;
    }

    private static function departmentProblems(array $v, string $d): array
    {
        $alloc = (float) ($v['allocation'][$d] ?? 0);
        $enabled = array_filter($v['departments'][$d]['criteria'] ?? [], fn ($c) => $c['enabled']);
        $w = array_sum(array_map(fn ($c) => $c['weight'], $enabled));
        return abs($w - $alloc) > self::EPS ? [['field' => "departments.$d", 'code' => 'WEIGHTS_MUST_TOTAL_ALLOCATION', 'message' => "WEIGHTS_MUST_TOTAL_ALLOCATION:$w/$alloc"]] : [];
    }

    /** A department submits its section; when all sections are in, the version goes to the high-level administrator. */
    public static function submitDepartment(array $actx, int $selectionId, string $dept): array
    {
        if (in_array($dept, self::FIXED_PARTS, true) || ! self::canEdit($actx['auth'], $dept)) throw ApiError::forbidden();
        $complete = false;
        $out = DB::transaction(function () use ($actx, $selectionId, $dept, &$complete) {
            $row = self::editable($actx, $selectionId);
            $v = self::decode($row);
            if ($errors = self::departmentProblems($v, $dept)) throw ApiError::validation($errors);
            $v['departments'][$dept]['status'] = 'submitted';
            $v['departments'][$dept]['submitted_by'] = $actx['auth']->id;
            $v['departments'][$dept]['submitted_at'] = Dates::sql(Dates::now());
            $patch = ['departments' => json_encode($v['departments'], JSON_UNESCAPED_UNICODE)];
            $allIn = ! array_filter(self::DEPARTMENTS, fn ($d) => ($v['departments'][$d]['status'] ?? 'draft') !== 'submitted');
            if ($allIn && ! self::problems($v)) {
                $patch += ['status' => 'submitted', 'submitted_at' => Dates::sql(Dates::now())];
                $complete = true;
            }
            DB::table('selection_config_versions')->where('id', $row->id)->update($patch);
            Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $selectionId, ['criteria_version' => $v['version'], 'department_submitted' => $dept, 'version_submitted' => $complete], inTrx: true);
            return self::decode(DB::table('selection_config_versions')->where('id', $row->id)->first());
        });
        if ($complete) {
            Notifications::createForUsers(Holders::of('selection.finalize'), [
                'type' => 'choir', 'title' => T::t('selection.criteria.submitted.title'),
                'body' => T::t('selection.criteria.submitted.body', ['version' => $out['version']]),
                'entityType' => 'selection', 'entityId' => $selectionId,
                'dedupeKey' => fn ($uid) => "selection:$selectionId:criteria:{$out['version']}:submitted:" . microtime(true) . ":$uid",
            ]);
        }
        return $out;
    }

    /** High-level administrator: approve or reject the complete submitted version. */
    public static function decide(array $actx, int $selectionId, string $decision, ?string $comment): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('selection.finalize')) throw ApiError::forbidden();
        if ($decision === 'reject' && ! trim((string) $comment)) throw ApiError::field('comment', 'REQUIRED');
        $out = DB::transaction(function () use ($actx, $auth, $selectionId, $decision, $comment) {
            $sel = self::selection($selectionId, true);
            $row = self::latest($selectionId, true);
            if (! $row || $row->status !== 'submitted') throw ApiError::conflict('CONFIG_NOT_SUBMITTED', 'There is no submitted version to decide');
            $v = self::decode($row);
            foreach (self::DEPARTMENTS as $d) {
                if ((int) ($v['departments'][$d]['submitted_by'] ?? 0) === $auth->id) throw ApiError::forbidden('SELF_APPROVAL', 'You submitted part of this configuration; another administrator approves it');
            }
            $now = Dates::sql(Dates::now());
            if ($decision === 'reject') {
                foreach (self::DEPARTMENTS as $d) if (! in_array($d, self::FIXED_PARTS, true)) $v['departments'][$d]['status'] = 'draft';
                DB::table('selection_config_versions')->where('id', $row->id)->update(['status' => 'rejected', 'decided_by' => $auth->id, 'decided_at' => $now, 'comment' => $comment, 'departments' => json_encode($v['departments'], JSON_UNESCAPED_UNICODE)]);
            } else {
                if ($errors = self::problems($v)) throw ApiError::validation($errors);
                $hash = hash('sha256', json_encode([$v['allocation'], $v['passing'], $v['departments']], JSON_UNESCAPED_UNICODE));
                DB::table('selection_config_versions')->where(['selection_id' => $selectionId, 'status' => 'approved'])->update(['status' => 'superseded']);
                DB::table('selection_config_versions')->where('id', $row->id)->update(['status' => 'approved', 'decided_by' => $auth->id, 'decided_at' => $now, 'comment' => $comment, 'hash' => $hash]);
                // The approved rules travel with the selection's configuration (and its review hash).
                $cfg = json_decode($sel->config, true) ?: [];
                $cfg['v2'] = ['version_id' => (int) $row->id, 'version' => (int) $row->version, 'hash' => $hash];
                DB::table('holiday_selections')->where('id', $selectionId)->update(['config' => json_encode($cfg, JSON_UNESCAPED_UNICODE)]);
            }
            Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $selectionId, ['criteria_version' => $v['version'], 'decision' => $decision, 'comment' => $comment], inTrx: true);
            return self::decode(DB::table('selection_config_versions')->where('id', $row->id)->first());
        });
        $submitters = array_values(array_filter(array_map(fn ($d) => (int) ($out['departments'][$d]['submitted_by'] ?? 0), self::DEPARTMENTS)));
        Notifications::createForUsers($submitters, [
            'type' => 'choir', 'title' => T::t("selection.criteria.$decision.title"),
            'body' => T::t("selection.criteria.$decision.body", ['version' => $out['version'], 'comment' => $comment ?? '']),
            'entityType' => 'selection', 'entityId' => $selectionId,
            'dedupeKey' => fn ($uid) => "selection:$selectionId:criteria:{$out['version']}:$decision:$uid",
        ]);
        $sel = self::selection($selectionId);
        if ($decision === 'approve' && $sel->status === 'open') Selections::compute($selectionId);
        return $out;
    }

    /** Change approved criteria: a new draft copied from the approved version (which stays in force until the revision is approved). */
    public static function revise(array $actx, int $selectionId): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('selection.finalize') && ! self::editableParts($auth)) throw ApiError::forbidden();
        return DB::transaction(function () use ($actx, $selectionId) {
            $sel = self::selection($selectionId, true);
            if (in_array($sel->status, ['finalized', 'cancelled'], true)) throw ApiError::conflict('SELECTION_LOCKED', 'The criteria of a finalized selection do not change');
            $last = self::latest($selectionId, true);
            if (! $last || $last->status !== 'approved') throw ApiError::conflict('NO_APPROVED_VERSION', 'Only approved criteria are revised');
            $depts = json_decode($last->departments, true);
            foreach (self::DEPARTMENTS as $d) $depts[$d] = in_array($d, self::FIXED_PARTS, true) ? self::fixedSection() : ['status' => 'draft', 'criteria' => $depts[$d]['criteria'] ?? []];
            $id = DB::table('selection_config_versions')->insertGetId([
                'selection_id' => $selectionId, 'version' => $last->version + 1, 'status' => 'draft',
                'allocation' => $last->allocation, 'passing' => $last->passing, 'departments' => json_encode($depts, JSON_UNESCAPED_UNICODE), 'created_by' => $actx['auth']->id,
            ]);
            Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $selectionId, ['criteria_revision' => $last->version + 1], inTrx: true);
            return self::decode(DB::table('selection_config_versions')->where('id', $id)->first());
        });
    }

    // ------------------------------------------------------------------ manual evaluations

    /** The criterion (in the APPROVED version in force) and its department. */
    private static function criterion(int $selectionId, string $key): array
    {
        $v = self::active($selectionId);
        if (! $v) throw ApiError::conflict('NO_APPROVED_VERSION', 'The criteria are not approved yet');
        foreach (self::DEPARTMENTS as $d) foreach ($v['departments'][$d]['criteria'] as $c) if ($c['key'] === $key) return $c + ['department' => $d];
        throw ApiError::notFound('CRITERION_NOT_FOUND', 'Category not found');
    }

    public static function assignEvaluator(array $actx, int $selectionId, string $key, int $userId): array
    {
        $c = self::criterion($selectionId, $key);
        if (! self::canEdit($actx['auth'], $c['department'])) throw ApiError::forbidden();
        if ($c['source'] !== 'manual') throw ApiError::field('criterion_key', 'NOT_MANUAL');
        if (! DB::table('users')->where(['id' => $userId, 'status' => 'active'])->whereNull('deleted_at')->exists()) throw ApiError::field('user_id', 'USER_NOT_FOUND');
        DB::table('selection_evaluators')->insertOrIgnore(['selection_id' => $selectionId, 'criterion_key' => $key, 'user_id' => $userId, 'assigned_by' => $actx['auth']->id]);
        Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $selectionId, ['evaluator' => $userId, 'criterion' => $key]);
        return self::evaluators($selectionId);
    }

    public static function evaluators(int $selectionId): array
    {
        return DB::table('selection_evaluators as e')->join('users as u', 'u.id', '=', 'e.user_id')->where('e.selection_id', $selectionId)
            ->get(['e.criterion_key', 'e.user_id', 'u.full_name'])->all();
    }

    private static function assertEvaluator(AuthContext $auth, int $selectionId, array $c): void
    {
        if (self::canEdit($auth, $c['department'])) return;
        if (! DB::table('selection_evaluators')->where(['selection_id' => $selectionId, 'criterion_key' => $c['key'], 'user_id' => $auth->id])->exists()) {
            throw ApiError::forbidden('NOT_EVALUATOR', 'You do not evaluate this category');
        }
    }

    /** The applicants with their score for one manual category. */
    public static function sheet(AuthContext $auth, int $selectionId, string $key): array
    {
        $c = self::criterion($selectionId, $key);
        self::assertEvaluator($auth, $selectionId, $c);
        $ids = Selections::memberIds($selectionId);
        $rows = DB::table('users as u')->leftJoin('selection_scores as s', fn ($j) => $j->on('s.user_id', '=', 'u.id')->where('s.selection_id', '=', $selectionId)->where('s.criterion_key', '=', $key))
            ->whereIn('u.id', $ids ?: [0])->orderBy('u.full_name')
            ->get(['u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 's.raw_score', 's.participated', 's.status', 's.note', 's.entered_by'])->all();
        MemberIds::decorate($rows);
        foreach ($rows as $r) {
            unset($r->member_no);
            $r->raw_score = $r->raw_score === null ? null : (float) $r->raw_score;
            $r->participated = $r->participated === null ? null : (bool) $r->participated;
        }
        return ['criterion' => $c, 'rows' => $rows];
    }

    /** Evaluator: enter or correct draft / rejected scores (raw ≤ maximum; "did not take part" is an explicit 0). */
    public static function enter(AuthContext $auth, int $selectionId, string $key, array $rows): array
    {
        $c = self::criterion($selectionId, $key);
        self::assertEvaluator($auth, $selectionId, $c);
        if ($c['source'] !== 'manual') throw ApiError::field('criterion_key', 'NOT_MANUAL');
        $sel = self::selection($selectionId);
        if (in_array($sel->status, ['finalized', 'cancelled'], true)) throw ApiError::conflict('SELECTION_LOCKED', 'Results of a finalized selection do not change');
        $members = array_flip(Selections::memberIds($selectionId));
        DB::transaction(function () use ($auth, $selectionId, $key, $rows, $c, $members) {
            foreach ($rows as $r) {
                $uid = (int) $r['user_id'];
                if (! isset($members[$uid])) throw ApiError::field('user_id', 'NOT_AN_APPLICANT');
                $participated = (bool) ($r['participated'] ?? true);
                $raw = $participated ? ($r['raw_score'] ?? null) : null;
                if ($raw !== null && ($raw < 0 || $raw > $c['max_score'] + self::EPS)) throw ApiError::field('raw_score', 'SCORE_OUT_OF_RANGE');
                $cur = DB::table('selection_scores')->where(['selection_id' => $selectionId, 'criterion_key' => $key, 'user_id' => $uid])->lockForUpdate()->first();
                if ($cur && ! in_array($cur->status, ['draft', 'rejected'], true)) throw ApiError::conflict('SCORE_LOCKED', 'This score was already submitted');
                $row = ['raw_score' => $raw, 'participated' => $participated, 'status' => 'draft', 'entered_by' => $auth->id, 'entered_at' => Dates::sql(Dates::now()), 'note' => $r['note'] ?? null];
                DB::table('selection_scores')->upsert([['selection_id' => $selectionId, 'criterion_key' => $key, 'user_id' => $uid] + $row], ['selection_id', 'criterion_key', 'user_id'], array_keys($row));
            }
        });
        return self::sheet($auth, $selectionId, $key);
    }

    public static function submitScores(AuthContext $auth, int $selectionId, string $key): array
    {
        $c = self::criterion($selectionId, $key);
        self::assertEvaluator($auth, $selectionId, $c);
        $n = DB::table('selection_scores')->where(['selection_id' => $selectionId, 'criterion_key' => $key, 'status' => 'draft'])
            ->where(fn ($w) => $w->whereNotNull('raw_score')->orWhere('participated', false))->update(['status' => 'submitted']);
        return ['submitted' => $n];
    }

    /** The department approves or rejects submitted scores — never scores it entered itself. */
    public static function reviewScores(array $actx, int $selectionId, string $key, string $decision, ?array $userIds, ?string $note): array
    {
        $auth = $actx['auth'];
        $c = self::criterion($selectionId, $key);
        if (! self::canEdit($auth, $c['department'])) throw ApiError::forbidden();
        if ($decision === 'reject' && ! trim((string) $note)) throw ApiError::field('note', 'REQUIRED');
        $ids = DB::transaction(function () use ($auth, $selectionId, $key, $decision, $userIds, $note) {
            $q = DB::table('selection_scores')->where(['selection_id' => $selectionId, 'criterion_key' => $key, 'status' => 'submitted'])->lockForUpdate();
            if ($userIds) $q->whereIn('user_id', $userIds);
            $rows = $q->get();
            if (! $rows->count()) throw ApiError::conflict('NOTHING_TO_REVIEW', 'No submitted scores to review');
            if ($rows->contains(fn ($r) => (int) $r->entered_by === $auth->id)) throw ApiError::forbidden('SELF_APPROVAL', 'You cannot review scores you entered');
            DB::table('selection_scores')->whereIn('id', $rows->pluck('id')->all())->update(['status' => $decision === 'approve' ? 'approved' : 'rejected', 'reviewed_by' => $auth->id, 'reviewed_at' => Dates::sql(Dates::now()), 'note' => $note]);
            return $rows->pluck('user_id')->map(fn ($v) => (int) $v)->all();
        });
        Audit::log($actx, Audit::SELECTION_REVIEW, 'selection', $selectionId, ['criterion' => $key, 'scores' => $decision, 'count' => count($ids), 'note' => $note]);
        if ($decision === 'approve' && self::selection($selectionId)->status === 'open') Selections::compute($selectionId, $ids);
        return ['decision' => $decision, 'count' => count($ids)];
    }

    // ------------------------------------------------------------------ scoring

    /**
     * Score one applicant with the approved version. $parts: the existing component values
     * (percent 0–100 or null with a reason) computed by Selections::evaluate.
     */
    public static function score(array $v, int $selectionId, int $userId, array $parts): array
    {
        $manual = DB::table('selection_scores')->where(['selection_id' => $selectionId, 'user_id' => $userId])->get()->keyBy('criterion_key');
        $components = [];
        $departments = [];
        $missing = [];
        $failed = [];
        $total = 0.0;
        foreach (self::DEPARTMENTS as $d) {
            $deptTotal = 0.0;
            $complete = true;
            foreach ($v['departments'][$d]['criteria'] as $c) {
                if (! $c['enabled']) continue;
                $value = null;
                $state = 'counted';
                $participation = null;
                $reason = null;
                if ($c['source'] === 'manual') {
                    $s = $manual->get($c['key']);
                    if ($s && $s->status === 'approved') {
                        $participation = $s->participated ? 'participated' : 'not_participated';
                        $value = $s->participated ? ((float) $s->raw_score / $c['max_score']) * $c['weight'] : 0.0;
                    } else {
                        $state = 'pending';
                        $reason = $s ? "score_{$s->status}" : 'not_evaluated';
                    }
                } else {
                    $p = $parts[$c['source']] ?? ['percent' => null, 'reason' => 'no_data'];
                    if ($p['percent'] === null && ($p['reason'] ?? null) !== 'exempt') {
                        $state = 'missing';
                        $reason = $p['reason'] ?? 'no_data';
                    } else {
                        $percent = (float) ($p['percent'] ?? 100);
                        $value = min($c['weight'], ($percent / 100) * $c['weight']);
                        $participation = $percent > 0 ? 'participated' : 'not_participated';
                    }
                }
                if ($value === null) {
                    $complete = false;
                    $missing[] = ['component' => $c['key'], 'department' => $d, 'reason' => $reason];
                } else {
                    $deptTotal += $value;
                    if ($c['min_points'] !== null && $value + self::EPS < $c['min_points']) $failed[] = ['component' => $c['key'], 'required' => $c['min_points'], 'current' => round($value, 2), 'shortfall' => round($c['min_points'] - $value, 2)];
                }
                $components[$c['key']] = [
                    'name' => $c['name'], 'department' => $d, 'source' => $c['source'], 'weight' => $c['weight'], 'max_score' => $c['max_score'], 'minimum' => $c['min_points'],
                    'raw' => $c['source'] === 'manual' ? ($manual->get($c['key'])?->raw_score !== null ? (float) $manual->get($c['key'])->raw_score : null) : ($parts[$c['source']]['percent'] ?? null),
                    'points' => $value === null ? null : round($value, 2), 'state' => $state, 'participation' => $participation, 'reason' => $reason,
                    'counted' => $value !== null, 'passed' => $value === null || $c['min_points'] === null || $value + self::EPS >= $c['min_points'],
                    'detail' => $c['source'] === 'manual' ? (object) [] : ($parts[$c['source']]['detail'] ?? (object) []),
                ];
            }
            $min = $v['passing']['department_minimums'][$d] ?? null;
            if ($complete && $min !== null && $deptTotal + self::EPS < $min) $failed[] = ['component' => "department:$d", 'required' => $min, 'current' => round($deptTotal, 2), 'shortfall' => round($min - $deptTotal, 2)];
            $departments[$d] = ['allocation' => (float) $v['allocation'][$d], 'score' => round($deptTotal, 2), 'complete' => $complete, 'minimum' => $min];
            $total += $deptTotal;
        }
        $total = min(100.0, $total);
        $complete = ! $missing;
        $minimum = (float) $v['passing']['total_minimum'];
        if ($complete && $total + self::EPS < $minimum) $failed[] = ['component' => 'total', 'required' => $minimum, 'current' => round($total, 2), 'shortfall' => round($minimum - $total, 2)];
        $outcome = ! $complete ? 'pending' : ($failed ? 'not_eligible' : 'eligible');
        return [
            'components' => $components, 'departments' => $departments, 'total' => round($total, 2), 'score_exact' => round($total, 4),
            'total_minimum' => $minimum, 'complete' => $complete, 'outcome' => $outcome, 'failed' => $failed, 'missing' => $missing,
            'config_version_id' => $v['id'], 'config_version' => $v['version'],
        ];
    }

    /**
     * After computing: rank the eligible applicants by the exact score (equal scores share a rank)
     * and apply the quota — within it 'selected', beyond it 'eligible_not_selected' (ties at the
     * limit are all selected). Without a quota every eligible applicant is selected.
     */
    public static function rank(int $selectionId): void
    {
        $v = self::active($selectionId);
        if (! $v) return;
        $quota = $v['passing']['quota'] ?? null;
        DB::table('selection_results')->where('selection_id', $selectionId)->whereIn('outcome', ['selected', 'eligible_not_selected'])->update(['outcome' => 'eligible']);
        DB::table('selection_results')->where('selection_id', $selectionId)->where('outcome', '<>', 'eligible')->update(['rank' => null, 'qualified' => false]);
        $rows = DB::table('selection_results')->where(['selection_id' => $selectionId, 'outcome' => 'eligible'])->orderByDesc('score_exact')->orderBy('id')->get(['id', 'score_exact']);
        $rank = 0;
        $prev = null;
        foreach ($rows as $i => $r) {
            if ($prev === null || abs((float) $r->score_exact - $prev) > self::EPS) {
                $rank = $i + 1;
                $prev = (float) $r->score_exact;
            }
            $selected = $quota === null || $rank <= $quota;
            DB::table('selection_results')->where('id', $r->id)->update(['rank' => $rank, 'outcome' => $selected ? 'selected' : 'eligible_not_selected', 'qualified' => $selected]);
        }
    }
}
