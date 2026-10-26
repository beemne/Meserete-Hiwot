<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\Holders;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Holiday Mezmur service selections — the single place where a member's qualification is
 * calculated (port of selectionService.js). Members are never ranked; each is checked against the
 * selection's own requirements. See the Node file header for the full formula.
 */
final class Selections
{
    public const COMPONENTS = ['course_attendance', 'exam', 'mezmur_attendance', 'contribution', 'participation'];
    public const BONUS_MAX = 30;
    public const CATEGORY_WEREB = 'ለወረብ አገልግሎት የተመረጡ';
    public const CATEGORY_MEZMUR = 'ለመዝሙር አገልግሎት የተመረጡ';
    public const SERVICE_CATEGORIES = [self::CATEGORY_WEREB, self::CATEGORY_MEZMUR];

    public const DEFAULT_DEPARTMENTS = [
        'Hymns and Arts Department',
        'Education and Training Department',
        'Human Resources Management Department',
    ];

    private const DEFAULT_GROUPS = ['youth_adult', 'married'];
    public const DEFAULT_CONFIG = [
        'weights' => ['course_attendance' => 25, 'exam' => 25, 'mezmur_attendance' => 30, 'contribution' => 10, 'participation' => 10],
        'minimums' => ['course_attendance' => 10, 'exam' => 10, 'mezmur_attendance' => 15, 'contribution' => 3, 'participation' => 5],
        'total_minimum' => 43,
        'education' => ['class_ids' => [], 'course_ids' => [], 'teacher_credit' => 25],
        'mezmur' => ['category_ids' => [], 'included_program_ids' => [], 'excluded_program_ids' => []],
        'contribution' => ['late_credit' => 1, 'start_month' => null, 'end_month' => null, 'year' => null],
        'bonus' => ['type' => 'percentage', 'max' => 30, 'points' => 0, 'base_component' => 'service_attendance', 'category_ids' => [], 'program_ids' => []],
        'attendance' => ['present' => 100, 'late' => 100, 'excused' => null, 'absent' => 0, 'program_weights' => []],
    ];
    public const FORMULA = 'attendance % = Σ (program weight × points of the status: present / late / excused / absent) ÷ Σ program weights; base = (sum of component % × weight ÷ 100) ÷ (sum of the counted weights) × 100; bonus = service attendance % × bonus max ÷ 100 (max 30); total = base + bonus; qualified when every counted component reaches its minimum and total ≥ the total minimum.';

    private static array $pending = [];
    private static bool $scheduled = false;

    private static function pct(float|int $a, float|int $b): int|float|null
    {
        return $b > 0 ? Num::round1(($a / $b) * 100) : null;
    }

    private static function parse(mixed $v): mixed
    {
        return is_string($v) ? json_decode($v, true) : $v;
    }

    public static function mergeConfig(?array $c = null): array
    {
        $c ??= [];
        $d = self::DEFAULT_CONFIG;
        $out = array_merge($d, $c);
        foreach (['weights', 'minimums', 'education', 'mezmur', 'contribution', 'bonus', 'attendance'] as $k) {
            $out[$k] = array_merge($d[$k], $c[$k] ?? []);
        }
        return $out;
    }

    private static function validateConfig(array $c): void
    {
        $errors = [];
        $sum = 0;
        foreach (self::COMPONENTS as $k) $sum += (float) ($c['weights'][$k] ?? 0);
        if (abs($sum - 100) > 0.001) $errors[] = ['field' => 'weights', 'code' => 'WEIGHTS_MUST_TOTAL_100', 'message' => 'WEIGHTS_MUST_TOTAL_100'];
        // The fixed split: Education (classes + exams) 50, Mezmur 30, monthly dues 10, department participation 10.
        $w = fn ($k) => (float) ($c['weights'][$k] ?? 0);
        $split = ['education' => $w('course_attendance') + $w('exam'), 'mezmur' => $w('mezmur_attendance'), 'dues' => $w('contribution'), 'participation' => $w('participation')];
        foreach (SelectionCriteria::ALLOCATION as $d => $share) {
            if (abs($split[$d] - $share) > 0.001) {
                $errors[] = ['field' => 'weights', 'code' => 'ALLOCATION_IS_FIXED', 'message' => 'ALLOCATION_IS_FIXED:50/30/10/10'];
                break;
            }
        }
        foreach (self::COMPONENTS as $k) {
            $m = $c['minimums'][$k] ?? null;
            if ($m !== null && $m > $c['weights'][$k]) $errors[] = ['field' => "minimums.$k", 'code' => 'MINIMUM_ABOVE_WEIGHT', 'message' => 'MINIMUM_ABOVE_WEIGHT'];
        }
        $a = $c['attendance'];
        if (($a['late'] ?? 0) > ($a['present'] ?? 100)) $errors[] = ['field' => 'attendance.late', 'code' => 'LATE_ABOVE_PRESENT', 'message' => 'LATE_ABOVE_PRESENT'];
        if (($a['absent'] ?? 0) > ($a['late'] ?? 100)) $errors[] = ['field' => 'attendance.absent', 'code' => 'ABSENT_ABOVE_LATE', 'message' => 'ABSENT_ABOVE_LATE'];
        $bType = $c['bonus']['type'] ?? 'percentage';
        if ($bType === 'fixed') {
            if (($c['bonus']['points'] ?? 0) > self::BONUS_MAX) $errors[] = ['field' => 'bonus.points', 'code' => 'BONUS_ABOVE_MAX', 'message' => 'BONUS_ABOVE_MAX:' . self::BONUS_MAX];
        } else {
            if (($c['bonus']['max'] ?? 0) > self::BONUS_MAX) $errors[] = ['field' => 'bonus.max', 'code' => 'BONUS_ABOVE_MAX', 'message' => 'BONUS_ABOVE_MAX:' . self::BONUS_MAX];
        }
        if ($errors) throw ApiError::validation($errors);
    }

    private static function groupsOf(object $s): array
    {
        return $s->member_groups ? array_values(array_filter(explode(',', $s->member_groups))) : self::DEFAULT_GROUPS;
    }

    private static function serialize(object $s): array
    {
        $out = [
            'id' => $s->id,
            'name' => $s->name,
            'from' => Dates::toDateOnly($s->from_date),
            'to' => Dates::toDateOnly($s->to_date),
            'member_groups' => self::groupsOf($s),
            'config' => self::mergeConfig(self::parse($s->config)),
            'formula' => self::FORMULA,
            'status' => $s->status,
            'is_published' => (bool) ($s->is_published ?? false),
            'published_at' => $s->published_at ?? null,
            'required_departments' => ! empty($s->required_departments) ? (is_array($s->required_departments) ? $s->required_departments : json_decode($s->required_departments, true)) : self::DEFAULT_DEPARTMENTS,
            'created_by_name' => $s->created_by_name ?? null,
            'finalized_by_name' => $s->finalized_by_name ?? null,
            'finalized_at' => $s->finalized_at ?? null,
            'computed_at' => $s->computed_at ?? null,
        ];
        if (isset($s->counts)) $out['counts'] = $s->counts;
        // Department criteria (v2): the approved version in force and the latest one being prepared.
        $latest = DB::table('selection_config_versions')->where('selection_id', $s->id)->orderByDesc('version')->first(['version', 'status']);
        $active = DB::table('selection_config_versions')->where(['selection_id' => $s->id, 'status' => 'approved'])->orderByDesc('version')->first(['id', 'version']);
        $out['criteria'] = ['active_version' => $active ? (int) $active->version : null, 'latest_version' => $latest ? (int) $latest->version : null, 'latest_status' => $latest?->status];
        $out['created_at'] = $s->created_at;
        $out['updated_at'] = $s->updated_at;
        return $out;
    }

    private static function row(int $id, bool $lock = false): object
    {
        $q = DB::table('holiday_selections as s')->leftJoin('users as c', 'c.id', '=', 's.created_by')->leftJoin('users as f', 'f.id', '=', 's.finalized_by')
            ->where('s.id', $id)->select('s.*', 'c.full_name as created_by_name', 'f.full_name as finalized_by_name');
        if ($lock) $q->lockForUpdate();
        $s = $q->first();
        if (! $s) throw ApiError::notFound('SELECTION_NOT_FOUND', 'Selection not found');
        return $s;
    }

    private static function counts(int $id): array
    {
        $r = DB::table('selection_results')->where('selection_id', $id)->selectRaw("COUNT(*) as total, SUM(CASE WHEN COALESCE(override, IF(qualified, 'qualified', 'not_qualified')) = 'qualified' THEN 1 ELSE 0 END) as qualified, SUM(CASE WHEN JSON_LENGTH(missing) > 0 THEN 1 ELSE 0 END) as with_missing, SUM(CASE WHEN override IS NOT NULL THEN 1 ELSE 0 END) as overridden")->first();
        $total = (int) ($r->total ?? 0);
        $q = (int) ($r->qualified ?? 0);
        return ['total' => $total, 'qualified' => $q, 'not_qualified' => $total - $q, 'with_missing' => (int) ($r->with_missing ?? 0), 'overridden' => (int) ($r->overridden ?? 0)];
    }

    // ------------------------------------------------------------------ CRUD and status
    public static function list(?string $status, array $page): array
    {
        $qb = DB::table('holiday_selections as s')->leftJoin('users as c', 'c.id', '=', 's.created_by')->select('s.*', 'c.full_name as created_by_name')->orderByDesc('s.from_date');
        if ($status) $qb->where('s.status', $status);
        $res = Page::paginate($qb, $page);
        $items = [];
        foreach ($res['items'] as $s) {
            $s->counts = self::counts($s->id);
            $items[] = self::serialize($s);
        }
        return ['items' => $items, 'meta' => $res['meta']];
    }

    public static function get(int $id): array
    {
        $s = self::row($id);
        $s->counts = self::counts($id);
        return self::serialize($s);
    }

    public static function options(): array
    {
        return [
            'categories' => DB::table('program_categories')->select('id', 'name', 'name_en', 'color', 'is_active')->get()->map(function ($c) {
                $c->is_active = (bool) $c->is_active;
                return $c;
            })->all(),
            'classes' => DB::table('edu_classes')->where('status', 'active')->select('id', 'name', 'term')->get()->all(),
            'courses' => DB::table('edu_courses as c')->join('edu_classes as k', 'k.id', '=', 'c.class_id')->where('k.status', 'active')->select('c.id', 'c.name', 'c.class_id', 'k.name as class_name')->get()->all(),
            'programs' => DB::table('programs')->whereIn('status', ['published', 'completed'])->where('requires_attendance', true)->select('id', 'title', 'recurrence', 'category_id', 'is_additional', 'counts_for_selection')->orderBy('title')->get()->map(function ($p) {
                $p->is_additional = (bool) $p->is_additional;
                $p->counts_for_selection = (bool) $p->counts_for_selection;
                return $p;
            })->all(),
            'defaults' => self::DEFAULT_CONFIG,
            'bonus_max' => self::BONUS_MAX,
            'formula' => self::FORMULA,
        ];
    }

    private static function assertPeriod(string $from, string $to): void
    {
        if ($to < $from) throw ApiError::field('to', 'END_BEFORE_START');
    }

    private static function groupsCsv(?array $groups): ?string
    {
        return $groups ? implode(',', array_values(array_unique($groups))) : null;
    }

    public static function create(array $actx, array $input): array
    {
        self::assertPeriod($input['from'], $input['to']);
        $cfg = self::mergeConfig($input['config'] ?? null);
        self::validateConfig($cfg);
        $id = DB::table('holiday_selections')->insertGetId([
            'name' => $input['name'],
            'from_date' => $input['from'],
            'to_date' => $input['to'],
            'member_groups' => self::groupsCsv($input['member_groups'] ?? null),
            'config' => json_encode($cfg, JSON_UNESCAPED_UNICODE),
            'status' => 'draft',
            'created_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::SELECTION_CREATE, 'selection', $id, ['name' => $input['name'], 'from' => $input['from'], 'to' => $input['to'], 'config' => $cfg]);
        return self::get($id);
    }

    /** Change name / period / groups / configuration (draft or open). selection.exams alone: only exams_required. */
    public static function update(array $actx, int $id, array $input): array
    {
        $auth = $actx['auth'];
        DB::transaction(function () use ($actx, $auth, $id, $input) {
            $s = self::row($id, true);
            if (! in_array($s->status, ['draft', 'open'], true)) throw ApiError::conflict('SELECTION_LOCKED', 'The configuration is locked once the selection is in review');
            if (! $auth->can('selection.configure')) {
                $keys = array_keys($input);
                $cfgKeys = array_keys($input['config'] ?? []);
                if (array_diff($keys, ['config']) || array_diff($cfgKeys, ['exams_required']) || ! $auth->can('selection.exams')) throw ApiError::forbidden();
            }
            $before = self::mergeConfig(self::parse($s->config));
            $inCfg = $input['config'] ?? [];
            $cfg = self::mergeConfig(array_merge($before, $inCfg, [
                'weights' => array_merge($before['weights'], $inCfg['weights'] ?? []),
                'minimums' => array_merge($before['minimums'], $inCfg['minimums'] ?? []),
                'attendance' => array_merge($before['attendance'], $inCfg['attendance'] ?? []),
            ]));
            self::validateConfig($cfg);
            $from = $input['from'] ?? Dates::toDateOnly($s->from_date);
            $to = $input['to'] ?? Dates::toDateOnly($s->to_date);
            self::assertPeriod($from, $to);
            $patch = ['config' => json_encode($cfg, JSON_UNESCAPED_UNICODE), 'from_date' => $from, 'to_date' => $to];
            if (array_key_exists('name', $input)) $patch['name'] = $input['name'];
            if (array_key_exists('member_groups', $input)) $patch['member_groups'] = self::groupsCsv($input['member_groups']);
            DB::table('holiday_selections')->where('id', $id)->update($patch);
            Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $id, [
                'before' => ['config' => $before, 'from' => Dates::toDateOnly($s->from_date), 'to' => Dates::toDateOnly($s->to_date), 'name' => $s->name],
                'after' => ['config' => $cfg, 'from' => $from, 'to' => $to, 'name' => $patch['name'] ?? $s->name],
                'reason' => $input['reason'] ?? null,
            ], inTrx: true);
        });
        $s = self::row($id);
        if ($s->status === 'open' && ! config('mz.is_test')) {
            app()->terminating(function () use ($id) {
                try {
                    self::compute($id);
                } catch (\Throwable $e) {
                    Log::error('selection recompute failed', ['error' => $e->getMessage()]);
                }
            });
        }
        return self::get($id);
    }

    private const STATUS_FLOW = [
        'open' => [['draft', 'review'], ['selection.configure']],
        'review' => [['open'], ['selection.review', 'selection.configure']],
        'finalized' => [['review'], ['selection.finalize']],
        'cancelled' => [['draft', 'open', 'review'], ['selection.configure']],
    ];

    public static function setStatus(array $actx, int $id, string $status, ?string $reason): array
    {
        [$from, $perms] = self::STATUS_FLOW[$status];
        $ok = false;
        foreach ($perms as $p) if ($actx['auth']->can($p)) $ok = true;
        if (! $ok) throw ApiError::forbidden();
        $s = self::row($id);
        if (! in_array($s->status, $from, true)) throw ApiError::conflict('INVALID_SELECTION_STATUS', "Cannot move a {$s->status} selection to $status");

        // Req 22: Cannot finalize until all currently required departments have approved
        if ($status === 'finalized') {
            $required = ! empty($s->required_departments) ? (is_array($s->required_departments) ? $s->required_departments : json_decode($s->required_departments, true)) : self::DEFAULT_DEPARTMENTS;
            $configHash = md5($s->config);
            $latestReviews = DB::table('selection_reviews')
                ->where('selection_id', $id)
                ->where('config_version', $configHash)
                ->orderByDesc('id')
                ->get();
            $approved = [];
            foreach ($latestReviews as $rev) {
                if (! isset($approved[$rev->department_name])) {
                    $approved[$rev->department_name] = $rev->decision;
                }
            }
            $missing = [];
            foreach ($required as $dept) {
                if (($approved[$dept] ?? null) !== 'approved') {
                    $missing[] = $dept;
                }
            }
            if ($missing) {
                throw ApiError::conflict('PENDING_REVIEWS', 'All required departments must approve before finalization. Missing approvals from: ' . implode(', ', $missing));
            }
        }

        // Department criteria being prepared must be approved before the selection opens.
        if ($status === 'open' && DB::table('selection_config_versions')->where('selection_id', $id)->exists() && ! SelectionCriteria::active($id)) {
            throw ApiError::conflict('CRITERIA_NOT_APPROVED', 'The selection criteria must be approved before the selection opens');
        }
        // An official result never contains an undecided applicant (pending evaluations need an explicit decision).
        if ($status === 'finalized' && SelectionCriteria::active($id)) {
            $pending = DB::table('selection_results')->where(['selection_id' => $id, 'outcome' => 'pending'])->whereNull('override')->count();
            if ($pending) throw ApiError::conflict('RESULTS_PENDING', "$pending applicant(s) still have pending evaluations");
        }
        if ($status === 'review' || $status === 'open') self::compute($id);
        $notified = 0;
        DB::transaction(function () use ($actx, $id, $status, $reason, $s, &$notified) {
            $patch = ['status' => $status];
            if ($status === 'finalized') $patch += ['finalized_by' => $actx['auth']->id, 'finalized_at' => DB::raw('NOW()')];
            DB::table('holiday_selections')->where('id', $id)->update($patch);
            $c = self::counts($id);
            Audit::log($actx, $status === 'finalized' ? Audit::SELECTION_FINALIZE : Audit::SELECTION_STATUS, 'selection', $id, ['from' => $s->status, 'to' => $status, 'counts' => $c, 'reason' => $reason], inTrx: true);
            if ($status === 'finalized') {
                $choirAdmins = array_values(array_unique(array_merge(
                    Holders::of('choir.manage'),
                    Holders::of('selection.finalize')
                )));
                if ($choirAdmins) {
                    $notified += Notifications::createForUsers($choirAdmins, [
                        'type' => 'choir',
                        'title' => 'ምርጫ ጸድቋል / Selection Approved',
                        'body' => "የምርጫው '{$s->name}' ውጤት ጸድቋል:: እባክዎ የአገልግሎት ምድብ መድቡ::",
                        'entityType' => 'selection',
                        'entityId' => $id,
                        'dedupeKey' => fn ($uid) => "selection:$id:finalized_assign:$uid",
                    ]);
                }
            }
        });
        if ($notified) Notifications::kick();
        return self::get($id);
    }

    // ------------------------------------------------------------------ components
    private static function courseParts(int $userId, array $cfg, string $from, string $to): array
    {
        $enrollQ = DB::table('edu_enrollments as e')->join('edu_classes as c', 'c.id', '=', 'e.class_id')->where(['e.user_id' => $userId, 'e.status' => 'active']);
        if ($cfg['education']['class_ids']) $enrollQ->whereIn('c.id', $cfg['education']['class_ids']);
        $classes = $enrollQ->select('c.id', 'c.name', 'e.program')->get()->all();
        $perClass = [];
        foreach ($classes as $c) {
            // Sessions this student was expected at: their scheduled days (regular / distance), until the course ends.
            $dates = Edu::expectedDates((int) $c->id, $c->program, $from, $to);
            $n = count($dates);
            $by = [];
            foreach (DB::table('edu_attendance')->where(['class_id' => $c->id, 'user_id' => $userId])->whereIn('session_date', $dates ?: ['1900-01-01'])->groupBy('status')->selectRaw('status, COUNT(*) as n')->get() as $r) {
                $by[$r->status] = (int) $r->n;
            }
            $total = max(0, $n - ($by['excused'] ?? 0));
            $attended = ($by['present'] ?? 0) + ($by['late'] ?? 0);
            $perClass[] = ['class_id' => $c->id, 'class_name' => $c->name, 'program' => $c->program, 'attended' => $attended, 'total' => $total, 'percent' => self::pct($attended, $total)];
        }
        $attended = array_sum(array_column($perClass, 'attended'));
        $total = array_sum(array_column($perClass, 'total'));
        $classIds = array_map(fn ($c) => $c->id, $classes);
        // The subjects the member actually takes: their classes' subjects minus dropped ones, plus subjects added from elsewhere.
        $addedIds = DB::table('edu_course_enrollments')->where(['user_id' => $userId, 'status' => 'added'])->pluck('course_id')->all();
        $coursesQ = DB::table('edu_courses')->where(fn ($w) => $w->whereIn('class_id', $classIds ?: [0])->orWhereIn('id', $addedIds ?: [0]));
        if ($cfg['education']['class_ids']) $coursesQ->whereIn('class_id', $cfg['education']['class_ids']);
        if ($cfg['education']['course_ids']) $coursesQ->whereIn('id', $cfg['education']['course_ids']);
        $courses = [];
        foreach ($coursesQ->select('id', 'name', 'class_id')->get() as $c) {
            if (! Edu::onRoster($c, $userId)) continue;
            $assessments = DB::table('edu_assessments as a')->where('a.course_id', $c->id)
                ->whereRaw('COALESCE(a.held_on, DATE(a.created_at)) BETWEEN ? AND ?', [$from, $to])
                // Only reviewed marks (approved / published) count; a mark still in review is "missing", never 0.
                ->whereExists(fn ($s) => $s->select(DB::raw(1))->from('edu_scores as s')->whereColumn('s.assessment_id', 'a.id')->whereNotNull('s.score')->whereIn('s.status', EduMarks::FINAL))
                ->leftJoin('edu_scores as m', fn ($j) => $j->on('m.assessment_id', '=', 'a.id')->where('m.user_id', '=', $userId)->whereIn('m.status', EduMarks::FINAL))
                ->select('a.id', 'a.title', 'a.max_score', 'm.score')->get()->all();
            if (! $assessments) continue;
            $obtained = array_sum(array_map(fn ($a) => (float) ($a->score ?? 0), $assessments));
            $max = array_sum(array_map(fn ($a) => (float) $a->max_score, $assessments));
            $courses[] = ['course_id' => $c->id, 'course_name' => $c->name, 'obtained' => Num::round1($obtained), 'max' => Num::round1($max), 'percent' => self::pct($obtained, $max), 'missing_scores' => array_values(array_map(fn ($a) => $a->title, array_filter($assessments, fn ($a) => $a->score === null)))];
        }
        $obtained = array_sum(array_column($courses, 'obtained'));
        $max = array_sum(array_column($courses, 'max'));
        return [
            'enrolled' => count($classes) > 0,
            'attendance' => ['percent' => self::pct($attended, $total), 'detail' => ['attended' => $attended, 'total' => $total, 'classes' => $perClass]],
            'exam' => ['percent' => self::pct($obtained, $max), 'detail' => ['obtained' => Num::round1($obtained), 'max' => Num::round1($max), 'courses' => $courses]],
        ];
    }

    private static function countsFor(array $cfg, array $o): bool
    {
        if (! $o['is_additional']) return true;
        if (in_array($o['program_id'], $cfg['mezmur']['included_program_ids'], true)) return true;
        if (in_array($o['program_id'], $cfg['mezmur']['excluded_program_ids'], true)) return false;
        return $o['counts_for_selection'];
    }

    /**
     * Attendance % with the selection's points: Σ weight × points(status) ÷ Σ weight, over the
     * present / late / excused / absent occurrences.
     */
    private static function pointsPercent(array $occ, array $points, float|int $policyExcused): int|float|null
    {
        $weights = [];
        foreach ($points['program_weights'] ?? [] as $w) $weights[(int) $w['program_id']] = (float) $w['weight'];
        $byStatus = [
            'present' => (float) ($points['present'] ?? 100),
            'late' => (float) ($points['late'] ?? 100),
            'excused' => isset($points['excused']) ? (float) $points['excused'] : (float) $policyExcused * 100,
            'absent' => (float) ($points['absent'] ?? 0),
        ];
        $score = 0.0;
        $total = 0.0;
        foreach ($occ as $o) {
            if (! isset($byStatus[$o['status']])) continue;
            $w = $weights[(int) $o['program_id']] ?? 1.0;
            $score += $w * $byStatus[$o['status']] / 100;
            $total += $w;
        }
        return $total > 0 ? Num::clean(floor(($score / $total) * 1000 + 0.5) / 10) : null;
    }

    private static function attendancePart(int $userId, string $from, string $to, array $categoryIds, array $programIds, ?\Closure $filter, \DateTimeInterface $now, ?array $points = null): array
    {
        if (! $categoryIds && ! $programIds) return ['percent' => null, 'detail' => ['configured' => false]];
        $weight = Settings::permissionPolicy()['weight'];
        $q = ['from' => $from, 'to' => $to];
        if ($categoryIds) $q['categoryIds'] = $categoryIds;
        if ($programIds) $q['programIds'] = $programIds;
        $occ = array_values(array_filter(Attendance::memberOccurrences($userId, $q, $now), fn ($o) => ! in_array($o['status'], ['upcoming', 'today'], true)));
        $excluded = [];
        if ($filter) {
            foreach ($occ as $o) {
                if (! $filter($o)) $excluded[] = ['program_id' => $o['program_id'], 'title' => $o['title'], 'date' => $o['date']];
            }
            $occ = array_values(array_filter($occ, $filter));
        }
        $s = Attendance::statsOf($occ, $weight);
        if ($points !== null) $s['percentage'] = self::pointsPercent($occ, $points, $weight);
        $additional = [];
        foreach ($occ as $o) {
            if ($o['is_additional']) $additional[$o['program_id']] = ['program_id' => $o['program_id'], 'title' => $o['title']];
        }
        $exProg = [];
        foreach ($excluded as $e) $exProg[$e['program_id']] = ['program_id' => $e['program_id'], 'title' => $e['title']];
        return [
            'percent' => $s['percentage'],
            'detail' => ['attended' => $s['attended'], 'late' => $s['late'], 'excused' => $s['excused'], 'absent' => $s['absent'], 'total' => $s['total_programs'], 'excused_weight' => Num::clean($weight), 'additional_counted' => array_values($additional), 'excluded_sessions' => count($excluded), 'excluded_programs' => array_values($exProg), 'points' => $points],
        ];
    }

    /** One member's evaluation for a selection (not stored). */
    public static function evaluate(object $sel, int $userId, ?\DateTimeInterface $now = null): array
    {
        $now ??= Dates::now();
        $cfg = self::mergeConfig(self::parse($sel->config));
        $user = DB::table('users')->where('id', $userId)->whereNull('deleted_at')->first(['id', 'full_name', 'created_at', 'member_group']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        $joined = Dates::localDateOf($user->created_at);
        $from = max(Dates::toDateOnly($sel->from_date), $joined);
        $to = min(Dates::toDateOnly($sel->to_date), Dates::todayLocal($now));
        $missing = [];
        $parts = [];
        $bonus = ['type' => 'percentage', 'max' => 0, 'base_component' => null, 'percent' => null, 'points' => 0, 'detail' => ['configured' => false]];
        if ($from > $to) {
            foreach (self::COMPONENTS as $k) $parts[$k] = ['percent' => null, 'reason' => 'not_member_yet', 'detail' => (object) []];
        } else {
            $edu = self::courseParts($userId, $cfg, $from, $to);

            // Req 21: Assigned Education and Training teachers receive configured Education attendance credit (default 25%)
            $isTeacher = DB::table('edu_course_teachers as ct')
                ->join('edu_courses as co', 'co.id', '=', 'ct.course_id')
                ->join('edu_classes as c', 'c.id', '=', 'co.class_id')
                ->where(['ct.user_id' => $userId, 'ct.status' => 'active'])
                ->where('c.status', 'active')
                ->exists();
            $teacherCredit = (float) ($cfg['education']['teacher_credit'] ?? 25);
            if ($isTeacher && $teacherCredit > 0) {
                $rawAtt = $edu['attendance']['percent'] ?? 0;
                $creditedAtt = min(100.0, Num::round1($rawAtt + $teacherCredit));
                $parts['course_attendance'] = [
                    'percent' => $creditedAtt,
                    'reason' => null,
                    'detail' => array_merge($edu['attendance']['detail'], [
                        'is_teacher' => true,
                        'teacher_credit' => $teacherCredit,
                        'raw_attendance_percent' => $rawAtt,
                    ]),
                ];
            } else {
                $parts['course_attendance'] = [
                    'percent' => $edu['attendance']['percent'],
                    'reason' => ! $edu['enrolled'] ? 'not_enrolled' : ($edu['attendance']['percent'] === null ? 'no_sessions' : null),
                    'detail' => $edu['attendance']['detail'],
                ];
            }

            // Req 19: Exam weight determines whether exam results are required (weight > 0 = required)
            $examWeight = Num::clean((float) ($cfg['weights']['exam'] ?? 0));
            if ($examWeight > 0) {
                $parts['exam'] = [
                    'percent' => $edu['exam']['percent'],
                    'reason' => ! $edu['enrolled'] ? 'not_enrolled' : ($edu['exam']['percent'] === null ? 'no_exam' : null),
                    'detail' => $edu['exam']['detail'],
                ];
                if ($parts['exam']['percent'] === null) {
                    $missing[] = ['component' => 'exam', 'reason' => $parts['exam']['reason']];
                }
            } else {
                $parts['exam'] = [
                    'percent' => null,
                    'reason' => 'exam_not_required',
                    'detail' => $edu['exam']['detail'],
                ];
            }

            $mez = self::attendancePart($userId, $from, $to, $cfg['mezmur']['category_ids'], [], fn ($o) => self::countsFor($cfg, $o), $now, $cfg['attendance']);

            // Req 21: Service bonus applied ONLY to Mezmur attendance component and ONLY when member has 100% of Mezmur attendance requirement
            $bonusCfg = $cfg['bonus'] ?? [];
            $bonusType = $bonusCfg['type'] ?? 'percentage';
            $bonusMax = Num::clean(min(self::BONUS_MAX, (float) ($bonusCfg['max'] ?? 30)));
            $bonusBaseKey = $bonusCfg['base_component'] ?? 'service_attendance';
            $bonus = [
                'type' => $bonusType,
                'max' => $bonusMax,
                'base_component' => $bonusBaseKey,
                'percent' => null,
                'points' => 0,
                'detail' => ['configured' => false],
            ];
            if ($from <= $to) {
                $b = self::attendancePart($userId, $from, $to, $bonusCfg['category_ids'] ?? [], $bonusCfg['program_ids'] ?? [], null, $now, $cfg['attendance']);
                if ($bonusType === 'fixed') {
                    $fixedPts = Num::clean(min(self::BONUS_MAX, (float) ($bonusCfg['points'] ?? 0)));
                    $bPoints = ($b['percent'] !== null && $b['percent'] > 0) ? $fixedPts : 0;
                    $bonus = [
                        'type' => 'fixed',
                        'max' => $bonusMax,
                        'base_component' => $bonusBaseKey,
                        'percent' => $b['percent'],
                        'points' => $bPoints,
                        'detail' => $b['detail'],
                    ];
                } else {
                    $basePercent = $b['percent'];
                    if ($bonusBaseKey === 'course_attendance' && isset($parts['course_attendance'])) {
                        $basePercent = $parts['course_attendance']['percent'];
                    } elseif ($bonusBaseKey === 'exam' && isset($parts['exam'])) {
                        $basePercent = $parts['exam']['percent'];
                    }
                    $bPoints = $basePercent === null ? 0 : Num::clean(min($bonusMax, Num::round1(($basePercent / 100) * $bonusMax)));
                    $bonus = [
                        'type' => 'percentage',
                        'max' => $bonusMax,
                        'base_component' => $bonusBaseKey,
                        'percent' => $basePercent,
                        'points' => $bPoints,
                        'detail' => $b['detail'],
                    ];
                }
            }

            $mezPercent = $mez['percent'];
            $eligibleForBonus = ($mezPercent !== null && $mezPercent >= 100.0);
            $rawBonusPoints = $eligibleForBonus ? $bonus['points'] : 0;
            $mezWeight = Num::clean((float) ($cfg['weights']['mezmur_attendance'] ?? 30));
            $baseMezPts = $mezPercent !== null ? ($mezPercent / 100) * $mezWeight : 0;
            // Cap the final Mezmur attendance component at 100% only (cannot exceed weight capacity)
            $maxPossibleBonus = max(0, $mezWeight - $baseMezPts);
            $bonusPointsAwarded = min($rawBonusPoints, $maxPossibleBonus);

            $parts['mezmur_attendance'] = [
                'percent' => $mezPercent,
                'bonus_points' => $bonusPointsAwarded,
                'eligible_for_bonus' => $eligibleForBonus,
                'reason' => ($mez['detail']['configured'] ?? null) === false ? 'not_configured' : ($mezPercent === null ? 'no_sessions' : null),
                'detail' => array_merge($mez['detail'], [
                    'bonus' => $bonus,
                    'bonus_points_awarded' => $bonusPointsAwarded,
                    'eligible_for_bonus' => $eligibleForBonus,
                ]),
            ];

            // Req 20: Contribution scoring within inclusive selection period (paid months / total months * 100)
            $ethYear = $cfg['contribution']['year'] ?? Ethiopian::parsePeriod(Ethiopian::periodOfDate($from))['year'];
            $startMonth = $cfg['contribution']['start_month'] ?? null;
            $endMonth = $cfg['contribution']['end_month'] ?? null;
            // The approved department criteria may set this selection's own monthly range (dues + participation).
            $monthRange = SelectionCriteria::monthRange((int) $sel->id);
            if ($monthRange) {
                $startPeriod = $monthRange['from'];
                $endPeriod = $monthRange['to'];
            } elseif ($startMonth !== null && $endMonth !== null) {
                $startPeriod = is_numeric($startMonth) ? Ethiopian::period((int) $ethYear, (int) $startMonth) : (string) $startMonth;
                $endPeriod = is_numeric($endMonth) ? Ethiopian::period((int) $ethYear, (int) $endMonth) : (string) $endMonth;
            } else {
                $startPeriod = Ethiopian::periodOfDate($from);
                $endPeriod = Ethiopian::periodOfDate($to);
            }

            $m = Payments::monthsOf($userId, $startPeriod, $endPeriod);
            if ($m['exempt']) {
                $parts['contribution'] = [
                    'percent' => 100,
                    'reason' => 'exempt',
                    'detail' => [
                        'exempt' => true,
                        'period' => ['from' => $startPeriod, 'to' => $endPeriod],
                        'total_months' => 0,
                        'paid_months' => 0,
                        'unpaid_months' => 0,
                        'months' => [],
                    ],
                ];
            } else {
                $periodMonths = Ethiopian::monthsBetween($startPeriod, $endPeriod);
                $totalMonths = count($periodMonths);
                $monthsMap = [];
                foreach ($m['months'] as $mo) {
                    $monthsMap[$mo['period']] = $mo;
                }
                $paidCount = 0;
                $monthsDetail = [];
                foreach ($periodMonths as $pm) {
                    $mo = $monthsMap[$pm] ?? null;
                    $isPaid = $mo && in_array($mo['status'], ['paid', 'late'], true);
                    if ($isPaid) $paidCount++;
                    $monthsDetail[] = [
                        'period' => $pm,
                        'status' => $mo ? $mo['status'] : 'unpaid',
                        'paid' => $isPaid,
                        'paid_on' => $mo['paid_on'] ?? null,
                        'required' => $mo['required'] ?? null,
                    ];
                }
                $unpaidCount = $totalMonths - $paidCount;
                $contribPercent = $totalMonths > 0 ? Num::clean(floor(($paidCount / $totalMonths) * 1000 + 0.5) / 10) : null;
                $parts['contribution'] = [
                    'percent' => $contribPercent,
                    'reason' => $totalMonths === 0 ? 'nothing_due' : null,
                    'detail' => [
                        'exempt' => false,
                        'period' => ['from' => $startPeriod, 'to' => $endPeriod],
                        'total_months' => $totalMonths,
                        'paid_months' => $paidCount,
                        'unpaid_months' => $unpaidCount,
                        'months' => $monthsDetail,
                    ],
                ];
            }

            $part = Departments::participationAverage($userId, $monthRange['from'] ?? Ethiopian::periodOfDate($from), $monthRange['to'] ?? Ethiopian::periodOfDate($to));
            $parts['participation'] = [
                'percent' => $part['percent'],
                'reason' => ! $part['in_department'] ? 'not_in_department' : ($part['percent'] === null ? 'no_scores' : null),
                'detail' => ['average' => $part['average'], 'max_score' => $part['max_score'], 'months' => $part['months'], 'missing' => $part['missing']],
            ];
            if ($part['missing']) {
                $missing[] = ['component' => 'participation', 'reason' => 'missing_months', 'periods' => array_map(fn ($m) => ['period' => $m['period'], 'department_id' => $m['department_id']], $part['missing'])];
            }
        }
        // Department criteria (v2): the approved version decides, from the same component values.
        if ($v2 = SelectionCriteria::active((int) $sel->id)) {
            $s = SelectionCriteria::score($v2, (int) $sel->id, $userId, $parts);
            return [
                'user_id' => $userId, 'full_name' => $user->full_name, 'period' => ['from' => $from, 'to' => $to],
                'components' => $s['components'], 'departments' => $s['departments'], 'base_score' => $s['total'], 'bonus' => $bonus, 'total' => $s['total'],
                'total_minimum' => $s['total_minimum'], 'qualified' => $s['outcome'] === 'eligible', 'failed' => $s['failed'], 'missing' => $s['missing'],
                'outcome' => $s['outcome'], 'score_exact' => $s['score_exact'], 'config_version_id' => $s['config_version_id'], 'config_version' => $s['config_version'],
            ];
        }
        $components = [];
        $failed = [];
        $points = 0;
        $counted = 0;
        foreach (self::COMPONENTS as $k) {
            $weight = Num::clean((float) ($cfg['weights'][$k] ?? 0));
            $minimum = $cfg['minimums'][$k] ?? null;
            $p = $parts[$k];
            $included = $weight > 0 && $p['percent'] !== null;
            $pts = $included ? Num::round1(($p['percent'] / 100) * $weight) : null;
            if ($k === 'mezmur_attendance' && $included && ! empty($p['bonus_points'])) {
                $pts = Num::clean(min($weight, Num::round1($pts + $p['bonus_points'])));
            }
            $compPercent = $p['percent'];
            if ($k === 'mezmur_attendance' && $included && $pts !== null && $weight > 0) {
                $compPercent = min(100.0, Num::round1(($pts / $weight) * 100));
            }
            $passed = ! $included || $minimum === null || $pts >= $minimum;
            if ($included) {
                $points += $pts;
                $counted += $weight;
                if (! $passed) $failed[] = ['component' => $k, 'required' => $minimum, 'current' => $pts, 'shortfall' => Num::round1($minimum - $pts)];
            } elseif ($weight > 0 && ($p['reason'] ?? null) && ! in_array($p['reason'], ['exam_not_required', 'exempt'], true)) {
                $missing[] = ['component' => $k, 'reason' => $p['reason']];
            }
            $components[$k] = ['weight' => $weight, 'minimum' => $minimum, 'percent' => $compPercent, 'points' => $pts, 'counted' => $included, 'passed' => $passed, 'reason' => $p['reason'] ?? null, 'detail' => $p['detail']];
        }
        $base = $counted > 0 ? Num::round1(($points / $counted) * 100) : 0;
        $total = Num::round1($base);
        if ($total < $cfg['total_minimum']) $failed[] = ['component' => 'total', 'required' => $cfg['total_minimum'], 'current' => $total, 'shortfall' => Num::round1($cfg['total_minimum'] - $total)];
        if ($counted == 0) $missing[] = ['component' => 'all', 'reason' => 'no_data'];
        return [
            'user_id' => $userId,
            'full_name' => $user->full_name,
            'period' => ['from' => $from, 'to' => $to],
            'components' => $components,
            'base_score' => $base,
            'bonus' => $bonus,
            'total' => $total,
            'total_minimum' => $cfg['total_minimum'],
            'qualified' => $counted > 0 && ! $failed,
            'failed' => $failed,
            'missing' => $missing,
        ];
    }

    private static function membersOf(object $sel, ?array $userIds): array
    {
        $q = MemberIds::memberAccounts(DB::table('users as u'))->where(['u.status' => 'active', 'u.membership_status' => 'active'])->whereIn('u.member_group', self::groupsOf($sel));
        if ($userIds !== null) $q->whereIn('u.id', $userIds ?: [0]);
        return $q->pluck('u.id')->all();
    }

    /** The applicants of a selection (its member groups, active members). */
    public static function memberIds(int $id): array
    {
        return array_map('intval', self::membersOf(self::row($id), null));
    }

    /** (Re)compute and store the results of a draft / open selection (or entering review). */
    public static function compute(int $id, ?array $userIds = null): array
    {
        $sel = self::row($id);
        if (in_array($sel->status, ['finalized', 'cancelled'], true)) throw ApiError::conflict('SELECTION_LOCKED', 'Results of a finalized selection do not change');
        $ids = self::membersOf($sel, $userIds);
        $now = Dates::now();
        foreach ($ids as $uid) {
            $r = self::evaluate($sel, $uid, $now);
            $values = [
                'components' => json_encode($r['components'] + ['_bonus' => $r['bonus'], '_period' => $r['period']] + (isset($r['departments']) ? ['_departments' => $r['departments']] : []), JSON_UNESCAPED_UNICODE),
                'outcome' => $r['outcome'] ?? null,
                'score_exact' => $r['score_exact'] ?? null,
                'config_version_id' => $r['config_version_id'] ?? null,
                'base_score' => $r['base_score'],
                'bonus' => $r['bonus']['points'],
                'total' => $r['total'],
                'qualified' => $r['qualified'],
                'failed' => json_encode($r['failed'], JSON_UNESCAPED_UNICODE),
                'missing' => json_encode($r['missing'], JSON_UNESCAPED_UNICODE),
                'computed_at' => Dates::sql($now),
            ];
            DB::table('selection_results')->upsert([['selection_id' => $id, 'user_id' => $uid] + $values], ['selection_id', 'user_id'], array_keys($values));
        }
        if ($userIds === null) {
            DB::table('selection_results')->where('selection_id', $id)->whereNotIn('user_id', $ids ?: [0])->delete();
            DB::table('holiday_selections')->where('id', $id)->update(['computed_at' => Dates::sql($now)]);
        }
        SelectionCriteria::rank($id);
        return ['computed' => count($ids)];
    }

    /** Recompute open selections for members whose data changed (after the response; off in tests). */
    public static function scheduleRecompute(array $userIds): void
    {
        if (config('mz.is_test') || ! $userIds) return;
        foreach ($userIds as $u) self::$pending[(int) $u] = true;
        if (self::$scheduled) return;
        self::$scheduled = true;
        app()->terminating(function () {
            self::$scheduled = false;
            $ids = array_keys(self::$pending);
            self::$pending = [];
            try {
                foreach (DB::table('holiday_selections')->where('status', 'open')->pluck('id') as $sid) self::compute($sid, $ids);
            } catch (\Throwable $e) {
                Log::error('selection recompute failed', ['error' => $e->getMessage()]);
            }
        });
    }

    public static function recomputeOpen(): array
    {
        $computed = 0;
        foreach (DB::table('holiday_selections')->where('status', 'open')->pluck('id') as $sid) $computed += self::compute($sid)['computed'];
        return ['computed' => $computed];
    }

    // ------------------------------------------------------------------ results
    private static function serializeResult(object $r): array
    {
        // A pending evaluation is never reported as a failure.
        $final = $r->override ?? (($r->outcome ?? null) === 'pending' ? 'pending' : ($r->qualified ? 'qualified' : 'not_qualified'));
        $components = self::parse($r->components) ?? [];
        $bonusDetail = $components['_bonus'] ?? null;
        $period = $components['_period'] ?? null;
        $departments = $components['_departments'] ?? null;
        unset($components['_bonus'], $components['_period'], $components['_departments']);
        return [
            'user_id' => $r->user_id,
            'full_name' => $r->full_name,
            'member_id' => MemberIds::format($r->member_no ?? null, $r->member_group ?? null),
            'member_group' => $r->member_group,
            'service_category' => $r->service_category ?? null,
            'service_rank' => isset($r->service_rank) ? (int) $r->service_rank : null,
            'category_assigned_by' => $r->category_assigned_by ?? null,
            'category_assigned_at' => $r->category_assigned_at ?? null,
            'components' => (object) $components,
            'bonus_detail' => $bonusDetail,
            'period' => $period,
            'base_score' => Num::n($r->base_score),
            'bonus' => Num::n($r->bonus),
            'total' => Num::n($r->total),
            'qualified' => (bool) $r->qualified,
            'failed' => self::parse($r->failed) ?? [],
            'missing' => self::parse($r->missing) ?? [],
            'override' => $r->override ?? null,
            'override_reason' => $r->override_reason ?? null,
            'overridden_by_name' => $r->overridden_by_name ?? null,
            'overridden_at' => $r->overridden_at ?? null,
            'result' => $final,
            'outcome' => $r->outcome ?? null,
            'rank' => isset($r->rank) ? (int) $r->rank : null,
            'score_exact' => isset($r->score_exact) ? (float) $r->score_exact : null,
            'config_version_id' => isset($r->config_version_id) ? (int) $r->config_version_id : null,
            'departments' => $departments,
            'computed_at' => $r->computed_at,
        ];
    }

    /** Results in alphabetical order — never ranked by score before finalization and category assignment. */
    public static function results(int $id, array $f, array $page): array
    {
        self::row($id);
        $qb = DB::table('selection_results as r')->join('users as u', 'u.id', '=', 'r.user_id')->leftJoin('users as o', 'o.id', '=', 'r.overridden_by')
            ->where('r.selection_id', $id)->orderBy('u.full_name')->select('r.*', 'u.full_name', 'u.member_no', 'u.member_group', 'o.full_name as overridden_by_name');
        $finalExpr = "COALESCE(r.override, IF(r.qualified, 'qualified', 'not_qualified'))";
        if (! empty($f['result'])) $qb->whereRaw("$finalExpr = ?", [$f['result']]);
        if (! empty($f['missing'])) $qb->whereRaw('JSON_LENGTH(r.missing) > 0');
        if (! empty($f['category'])) $qb->where('r.service_category', $f['category']);
        MemberIds::search($qb, $f['q'] ?? null, 'u', false);
        $res = Page::paginate($qb, $page);
        return ['items' => array_map(fn ($r) => self::serializeResult($r), $res['items']), 'meta' => $res['meta'] + ['counts' => self::counts($id)]];
    }

    public static function result(int $id, int $userId): array
    {
        $sel = self::row($id);
        $r = DB::table('selection_results as r')->join('users as u', 'u.id', '=', 'r.user_id')->leftJoin('users as o', 'o.id', '=', 'r.overridden_by')
            ->where(['r.selection_id' => $id, 'r.user_id' => $userId])->first(['r.*', 'u.full_name', 'u.member_no', 'u.member_group', 'o.full_name as overridden_by_name']);
        if ($r) return ['selection' => self::serialize($sel)] + self::serializeResult($r);
        // Not computed yet (e.g. a draft): evaluate live without storing.
        $live = self::evaluate($sel, $userId);
        return ['selection' => self::serialize($sel)] + array_merge($live, ['bonus' => $live['bonus']['points'], 'bonus_detail' => $live['bonus'], 'override' => null, 'result' => $live['qualified'] ? 'qualified' : 'not_qualified', 'live' => true]);
    }

    /** An exception for one member (review; after finalization only with selection.finalize). */
    public static function override(array $actx, int $id, int $userId, string $decision, string $reason): array
    {
        $sel = self::row($id);
        if ($sel->status === 'finalized') {
            if (! $actx['auth']->can('selection.finalize')) throw ApiError::forbidden();
        } elseif ($sel->status !== 'review') {
            throw ApiError::conflict('INVALID_SELECTION_STATUS', 'Exceptions are recorded during review');
        }
        $r = DB::table('selection_results')->where(['selection_id' => $id, 'user_id' => $userId])->first();
        if (! $r) throw ApiError::notFound('RESULT_NOT_FOUND', 'No result for this member');
        $patch = ['override' => $decision === 'clear' ? null : $decision, 'override_reason' => $reason, 'overridden_by' => $actx['auth']->id, 'overridden_at' => Dates::sql(Dates::now())];
        DB::table('selection_results')->where('id', $r->id)->update($patch);
        Audit::log($actx, Audit::SELECTION_OVERRIDE, 'selection', $id, ['user_id' => $userId, 'calculated' => $r->qualified ? 'qualified' : 'not_qualified', 'previous_override' => $r->override, 'decision' => $decision, 'reason' => $reason, 'after_finalization' => $sel->status === 'finalized']);
        return self::result($id, $userId);
    }

    /** Req 23: The member's own view: ONLY finalized and published results are exposed. Draft results are private. */
    public static function forMember(int $userId): array
    {
        $sel = DB::table('holiday_selections')
            ->where('status', 'finalized')
            ->where('is_published', true)
            ->orderByDesc('to_date')
            ->first(['id', 'status', 'is_published']);

        if (! $sel) return ['selection' => null];

        try {
            $r = self::result($sel->id, $userId);
        } catch (ApiError $e) {
            if ($e->errorCode === 'USER_NOT_FOUND') return ['selection' => null];
            throw $e;
        }

        return $r;
    }

    // ------------------------------------------------------------------ Req 22: Multi-department reviews
    public static function reviews(int $id): array
    {
        self::row($id);
        return DB::table('selection_reviews as r')
            ->leftJoin('users as u', 'u.id', '=', 'r.reviewer_id')
            ->where('r.selection_id', $id)
            ->select('r.*', 'u.full_name as reviewer_name')
            ->orderByDesc('r.created_at')
            ->get()
            ->all();
    }

    public static function submitReview(array $actx, int $id, array $input): array
    {
        $auth = $actx['auth'];
        $s = self::row($id, true);
        if (! in_array($s->status, ['review', 'open'], true)) {
            throw ApiError::conflict('INVALID_STATUS', 'Reviews are submitted during the review stage');
        }
        $deptName = $input['department_name'] ?? null;
        $deptId = $input['department_id'] ?? null;
        if (! $deptName && $deptId) {
            $dept = DB::table('departments')->where('id', $deptId)->first();
            $deptName = $dept?->name_en ?? $dept?->name;
        }
        if (! $deptName) throw ApiError::validation([['field' => 'department_name', 'code' => 'REQUIRED']]);

        $decision = $input['decision']; // 'approved' | 'rejected'
        $comments = $input['comments'] ?? null;
        $configHash = md5($s->config);

        DB::table('selection_reviews')->insert([
            'selection_id' => $id,
            'department_id' => $deptId,
            'department_name' => $deptName,
            'reviewer_id' => $auth->id,
            'decision' => $decision,
            'comments' => $comments,
            'config_version' => $configHash,
            'created_at' => Dates::sql(Dates::now()),
            'updated_at' => Dates::sql(Dates::now()),
        ]);

        // A rejection returns the selection for correction
        if ($decision === 'rejected') {
            DB::table('holiday_selections')->where('id', $id)->update(['status' => 'open']);
        }

        Audit::log($actx, Audit::SELECTION_STATUS, 'selection_review', $id, [
            'department' => $deptName,
            'decision' => $decision,
            'comments' => $comments,
        ]);

        return self::reviews($id);
    }

    public static function setRequiredDepartments(array $actx, int $id, array $departments): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('selection.configure')) throw ApiError::forbidden();
        $departments = array_values(array_unique(array_filter(array_map('trim', $departments))));
        if (! $departments) throw ApiError::validation([['field' => 'departments', 'code' => 'REQUIRED']]);
        DB::table('holiday_selections')->where('id', $id)->update(['required_departments' => json_encode($departments, JSON_UNESCAPED_UNICODE)]);
        Audit::log($actx, Audit::SELECTION_UPDATE, 'selection', $id, ['required_departments' => $departments]);
        return self::get($id);
    }

    // ------------------------------------------------------------------ Req 24: Category Assignment & Ranking
    public static function assignCategories(array $actx, int $id, array $assignments): array
    {
        $s = self::row($id);
        if ($s->status !== 'finalized') {
            throw ApiError::conflict('NOT_FINALIZED', 'Service categories can only be assigned after selection is finalized');
        }
        $auth = $actx['auth'];
        if (! $auth->can('selection.finalize') && ! $auth->can('choir.manage') && ! $auth->can('choir.assign')) {
            throw ApiError::forbidden();
        }

        $results = DB::table('selection_results')->where('selection_id', $id)->get()->keyBy('user_id');
        $now = Dates::sql(Dates::now());

        DB::transaction(function () use ($assignments, $results, $id, $auth, $now, $actx) {
            foreach ($assignments as $a) {
                $uid = (int) $a['user_id'];
                $cat = $a['category'] ?? null;
                if ($cat !== null && ! in_array($cat, self::SERVICE_CATEGORIES, true)) {
                    throw ApiError::validation([['field' => 'category', 'code' => 'INVALID_CATEGORY', 'message' => 'Must be one of: ' . implode(', ', self::SERVICE_CATEGORIES)]]);
                }
                $r = $results->get($uid);
                if (! $r) throw ApiError::notFound('MEMBER_NOT_IN_SELECTION', "User $uid not in selection");
                $qualified = ($r->override ?? ($r->qualified ? 'qualified' : 'not_qualified')) === 'qualified';
                if (! $qualified) throw ApiError::conflict('MEMBER_NOT_QUALIFIED', "User $uid is not qualified for selection");

                DB::table('selection_results')
                    ->where(['selection_id' => $id, 'user_id' => $uid])
                    ->update([
                        'service_category' => $cat,
                        'service_rank' => $cat === null ? null : $r->service_rank,
                        'category_assigned_by' => $cat === null ? null : $auth->id,
                        'category_assigned_at' => $cat === null ? null : $now,
                    ]);
            }

            self::rankCategories($id);
            Audit::log($actx, Audit::CHOIR_SELECT, 'selection', $id, ['count' => count($assignments)], inTrx: true);
        });

        return self::rankedCategories($id);
    }

    public static function rankCategories(int $id): void
    {
        DB::table('selection_results')
            ->where('selection_id', $id)
            ->whereNull('service_category')
            ->update(['service_rank' => null]);

        foreach (self::SERVICE_CATEGORIES as $cat) {
            $members = DB::table('selection_results')
                ->where('selection_id', $id)
                ->where('service_category', $cat)
                ->orderByDesc('total')
                ->orderBy('id')
                ->get();

            $currentRank = 0;
            $prevScore = null;
            $index = 0;
            foreach ($members as $m) {
                $index++;
                if ($prevScore === null || (float) $m->total < (float) $prevScore) {
                    $currentRank = $index;
                    $prevScore = $m->total;
                }
                DB::table('selection_results')->where('id', $m->id)->update(['service_rank' => $currentRank]);
            }
        }
    }

    public static function rankedCategories(int $id): array
    {
        self::row($id);
        $out = [];
        foreach (self::SERVICE_CATEGORIES as $cat) {
            $rows = DB::table('selection_results as r')
                ->join('users as u', 'u.id', '=', 'r.user_id')
                ->where('r.selection_id', $id)
                ->where('r.service_category', $cat)
                ->orderBy('r.service_rank')
                ->orderBy('u.full_name')
                ->select('r.*', 'u.full_name', 'u.member_no', 'u.member_group')
                ->get();
            $out[$cat] = array_map(fn ($r) => self::serializeResult($r), $rows->all());
        }
        return $out;
    }

    public static function publish(array $actx, int $id): array
    {
        $auth = $actx['auth'];
        if (! $auth->can('selection.finalize')) throw ApiError::forbidden();
        $s = self::row($id);
        if ($s->status !== 'finalized') {
            throw ApiError::conflict('NOT_FINALIZED', 'Only finalized selections can be published');
        }
        DB::table('holiday_selections')->where('id', $id)->update([
            'is_published' => true,
            'published_at' => Dates::sql(Dates::now()),
            'published_by' => $auth->id,
        ]);

        $results = DB::table('selection_results')->where('selection_id', $id)->select('user_id', 'qualified', 'override', 'outcome')->get();
        $qualified = $results->filter(fn ($r) => ($r->override ?? ($r->qualified ? 'qualified' : 'not_qualified')) === 'qualified')->pluck('user_id')->all();
        // Eligible but beyond the quota is told apart from not eligible.
        $waiting = $results->filter(fn ($r) => ! $r->override && $r->outcome === 'eligible_not_selected')->pluck('user_id')->all();
        $notQualified = array_values(array_diff($results->pluck('user_id')->all(), $qualified, $waiting));
        $notified = 0;
        foreach ([[$qualified, 'selection.final.qualified'], [$waiting, 'selection.final.eligible_not_selected'], [$notQualified, 'selection.final.not_qualified']] as [$ids, $key]) {
            if ($ids) {
                $notified += Notifications::createForUsers($ids, [
                    'type' => 'choir',
                    'title' => T::t('selection.final.title'),
                    'body' => T::t($key, ['name' => $s->name]),
                    'entityType' => 'selection',
                    'entityId' => $id,
                    'dedupeKey' => fn ($uid) => "selection:$id:published:$uid",
                ]);
            }
        }
        if ($notified) Notifications::kick();

        Audit::log($actx, Audit::SELECTION_STATUS, 'selection', $id, ['op' => 'publish']);
        return self::get($id);
    }

    // ------------------------------------------------------------------ Req 25: Member feedback
    public static function submitFeedback(array $actx, int $id, string $comments): array
    {
        $auth = $actx['auth'];
        $s = self::row($id);
        if ($s->status !== 'finalized' || empty($s->is_published)) {
            throw ApiError::conflict('NOT_PUBLISHED', 'Feedback can only be submitted for finalized and published selections');
        }
        $fid = DB::table('selection_feedback')->insertGetId([
            'selection_id' => $id,
            'user_id' => $auth->id,
            'comments' => $comments,
            'status' => 'submitted',
            'created_at' => Dates::sql(Dates::now()),
            'updated_at' => Dates::sql(Dates::now()),
        ]);

        $finalizerIds = array_filter([$s->finalized_by, $s->created_by]);
        $reviewerIds = DB::table('selection_reviews')->where('selection_id', $id)->pluck('reviewer_id')->all();
        $notifyIds = array_values(array_unique(array_filter(array_merge($finalizerIds, $reviewerIds))));

        if ($notifyIds) {
            Notifications::createForUsers($notifyIds, [
                'type' => 'choir',
                'title' => 'አዲስ አስተያየት / New Selection Feedback',
                'body' => "አባል {$auth->fullName} በምርጫ '{$s->name}' ላይ አስተያየት ሰጥተዋል::",
                'entityType' => 'selection',
                'entityId' => $id,
                'dedupeKey' => fn ($uid) => "selection:$id:feedback:$fid:$uid",
            ]);
            Notifications::kick();
        }

        Audit::log($actx, Audit::CHOIR_POLICY, 'selection_feedback', $fid, ['selection_id' => $id, 'user_id' => $auth->id]);
        return ['id' => $fid, 'status' => 'submitted', 'message' => 'Feedback submitted successfully'];
    }

    public static function feedbackList(int $id): array
    {
        self::row($id);
        return DB::table('selection_feedback as f')
            ->join('users as u', 'u.id', '=', 'f.user_id')
            ->where('f.selection_id', $id)
            ->select('f.*', 'u.full_name', 'u.member_no', 'u.member_group')
            ->orderByDesc('f.created_at')
            ->get()
            ->all();
    }
}
