<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

/**
 * Selection reports built from the STORED results (the authoritative records), never from a
 * separate calculation. The Mezmur report has one row per applicant of the selection cycle, one
 * column per Mezmur category actually configured (participation: Participated / Not participated /
 * Pending) and the pass / fail result — "Pending" while an evaluation is missing, and marked
 * provisional until the selection is finalized.
 */
final class SelectionReports
{
    private const PARTICIPATION = ['participated' => 'Participated', 'not_participated' => 'Not participated', 'pending' => 'Pending'];

    /** The Mezmur categories of the selection: from the approved criteria, or the former Mezmur attendance component. */
    public static function mezmurCategories(int $selectionId): array
    {
        $v = SelectionCriteria::active($selectionId);
        if ($v) {
            return array_values(array_map(fn ($c) => ['key' => $c['key'], 'name' => $c['name'], 'weight' => $c['weight']], array_filter($v['departments']['mezmur']['criteria'], fn ($c) => $c['enabled'])));
        }
        return [['key' => 'mezmur_attendance', 'name' => 'Mezmur attendance', 'weight' => null]];
    }

    private static function participation(array $component): string
    {
        if (isset($component['participation'])) return $component['participation'] ?? 'pending';
        if (isset($component['state']) && $component['state'] !== 'counted') return 'pending';
        // Former components: a percentage of attendance.
        $p = $component['percent'] ?? null;
        if ($p === null) return 'pending';
        return $p > 0 ? 'participated' : 'not_participated';
    }

    /** Pass / Fail / Pending from the final decision (an override wins). */
    private static function result(object $r): string
    {
        if ($r->override) return $r->override === 'qualified' ? 'Pass' : 'Fail';
        if ($r->outcome === 'pending') return 'Pending';
        if ($r->outcome !== null) return in_array($r->outcome, ['selected', 'eligible_not_selected', 'eligible'], true) ? 'Pass' : 'Fail';
        return $r->qualified ? 'Pass' : 'Fail';
    }

    private static function selectionStatus(object $r): string
    {
        if ($r->override) return $r->override === 'qualified' ? 'Selected (exception)' : 'Not selected (exception)';
        return match ($r->outcome) {
            'selected' => 'Selected',
            'eligible_not_selected' => 'Eligible – not selected',
            'not_eligible' => 'Not eligible',
            'pending' => 'Pending',
            'eligible' => 'Eligible',
            default => $r->qualified ? 'Selected' : 'Not selected',
        };
    }

    public static function mezmurExport(AuthContext $auth, array $f): array
    {
        if (empty($f['selection_id'])) throw ApiError::field('selection_id', 'REQUIRED');
        $sel = DB::table('holiday_selections')->where('id', $f['selection_id'])->first();
        if (! $sel) throw ApiError::notFound('SELECTION_NOT_FOUND', 'Selection not found');
        $final = $sel->status === 'finalized';
        $cats = self::mezmurCategories((int) $sel->id);
        $qb = DB::table('selection_results as r')->join('users as u', 'u.id', '=', 'r.user_id')->where('r.selection_id', $sel->id)
            ->select('r.*', 'u.full_name', 'u.member_no', 'u.member_group')->orderBy('u.member_no')->orderBy('u.full_name');
        if (! empty($f['q'])) MemberIds::search($qb, $f['q']);
        $rows = [];
        foreach ($qb->get() as $r) {
            $comp = json_decode($r->components, true) ?: [];
            $result = self::result($r);
            if (! empty($f['result']) && strtolower($result) !== $f['result']) continue;
            $row = [
                'applicant_id' => MemberIds::format($r->member_no, $r->member_group) ?? (string) $r->user_id,
                'full_name' => $r->full_name,
                'mezmur_subtotal' => isset($comp['_departments']['mezmur']) ? $comp['_departments']['mezmur']['score'] . ' / ' . $comp['_departments']['mezmur']['allocation'] : '—',
                'total' => $r->outcome === 'pending' ? '—' : (float) $r->total,
                'result' => $final || $result === 'Pending' ? $result : "Provisional: $result",
                'selection_status' => $final ? self::selectionStatus($r) : 'Pending final approval',
                'rank' => $r->rank ?? '—',
            ];
            foreach ($cats as $c) {
                $p = isset($comp[$c['key']]) ? self::participation($comp[$c['key']]) : 'pending';
                $row['p_' . $c['key']] = self::PARTICIPATION[$p];
                $row['s_' . $c['key']] = $comp[$c['key']]['points'] ?? null;
            }
            $rows[] = $row;
        }
        $layout = ($f['layout'] ?? 'wide') === 'long' ? 'long' : 'wide';
        if ($layout === 'wide') {
            $cols = [['Applicant ID', 'applicant_id'], ['Name', 'full_name']];
            foreach ($cats as $c) $cols[] = [$c['name'], 'p_' . $c['key']];
            $cols = array_merge($cols, [['Mezmur subtotal', 'mezmur_subtotal'], ['Final score', 'total'], ['Final result', 'result'], ['Selection status', 'selection_status'], ['Rank', 'rank']]);
            $data = $rows;
        } else {
            $cols = [['Applicant ID', 'applicant_id'], ['Name', 'full_name'], ['Category', 'category'], ['Participation', 'participation'], ['Points', 'points'], ['Weight', 'weight'], ['Final result', 'result']];
            $data = [];
            foreach ($rows as $row) foreach ($cats as $c) {
                $data[] = ['applicant_id' => $row['applicant_id'], 'full_name' => $row['full_name'], 'category' => $c['name'], 'participation' => $row['p_' . $c['key']],
                    'points' => $row['s_' . $c['key']] ?? '—', 'weight' => $c['weight'] ?? '—', 'result' => $row['result']];
            }
        }
        $counts = array_count_values(array_map(fn ($r) => preg_replace('/^Provisional: /', '', $r['result']), $rows));
        return [
            'title' => 'Mezmur selection report — ' . $sel->name,
            'range' => null,
            'period_label' => 'Selection cycle: ' . $sel->name . ' (' . Dates::toDateOnly($sel->from_date) . ' – ' . Dates::toDateOnly($sel->to_date) . ')',
            'summary' => [
                ['Selection cycle', $sel->name], ['Status', $final ? 'Finalized (official)' : 'Not finalized (provisional)'], ['Applicants', count($rows)],
                ['Pass', $counts['Pass'] ?? 0], ['Fail', $counts['Fail'] ?? 0], ['Pending', $counts['Pending'] ?? 0], ['Mezmur categories', implode(', ', array_column($cats, 'name'))],
            ],
            'tables' => [ReportExport::table($layout === 'wide' ? 'Applicants' : 'Applicants by category', $cols, $data)],
        ];
    }
}
