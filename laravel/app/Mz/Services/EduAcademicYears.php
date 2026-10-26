<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

/**
 * Academic calendar service: Ethiopian calendar academic years, configurable terms, and grade levels.
 * Part of Release 1.5.3+18 (F1).
 */
final class EduAcademicYears
{
    // =========================================================================
    // Academic Years
    // =========================================================================

    public static function listYears(array $filters = []): array
    {
        $qb = DB::table('edu_academic_years')->orderByDesc('eth_year');

        if (! empty($filters['status'])) {
            $qb->where('status', $filters['status']);
        }
        if (isset($filters['is_current'])) {
            $qb->where('is_current', (int) $filters['is_current']);
        }

        $years = $qb->get()->map(fn ($y) => self::serializeYear($y))->all();
        if (empty($years)) {
            return [];
        }

        $yearIds = array_column($years, 'id');
        $terms = DB::table('edu_terms')
            ->whereIn('academic_year_id', $yearIds)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->groupBy('academic_year_id');

        $classCounts = DB::table('edu_classes')
            ->whereIn('academic_year_id', $yearIds)
            ->select('academic_year_id', DB::raw('COUNT(*) as total'))
            ->groupBy('academic_year_id')
            ->pluck('total', 'academic_year_id')
            ->all();

        foreach ($years as &$y) {
            $y['terms'] = isset($terms[$y['id']])
                ? $terms[$y['id']]->map(fn ($t) => self::serializeTerm($t))->all()
                : [];
            $y['class_count'] = (int) ($classCounts[$y['id']] ?? 0);
        }

        return $years;
    }

    public static function getYear(int $id): array
    {
        $y = DB::table('edu_academic_years')->where('id', $id)->first();
        if (! $y) {
            throw ApiError::notFound('YEAR_NOT_FOUND', 'Academic year not found');
        }

        $out = self::serializeYear($y);
        $out['terms'] = DB::table('edu_terms')
            ->where('academic_year_id', $id)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn ($t) => self::serializeTerm($t))
            ->all();
        $out['class_count'] = (int) DB::table('edu_classes')->where('academic_year_id', $id)->count();

        return $out;
    }

    public static function createYear(array $actx, array $in): array
    {
        $ethYear = (int) $in['eth_year'];
        if (DB::table('edu_academic_years')->where('eth_year', $ethYear)->exists()) {
            throw ApiError::conflict('YEAR_EXISTS', 'Academic year already exists');
        }

        $isCurrent = ! empty($in['is_current']) ? 1 : 0;

        $id = DB::transaction(function () use ($actx, $ethYear, $in, $isCurrent) {
            if ($isCurrent) {
                DB::table('edu_academic_years')->where('is_current', 1)->update(['is_current' => 0]);
            }

            $yearId = DB::table('edu_academic_years')->insertGetId([
                'eth_year' => $ethYear,
                'name' => $in['name'] ?? "{$ethYear} ዓ.ም",
                'starts_on' => $in['starts_on'] ?? null,
                'ends_on' => $in['ends_on'] ?? null,
                'status' => $in['status'] ?? 'planned',
                'is_current' => $isCurrent,
                'created_by' => $actx['auth']->id ?? null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_academic_year', $yearId, ['create' => $in], inTrx: true);

            return $yearId;
        });

        return self::getYear($id);
    }

    public static function updateYear(array $actx, int $id, array $in): array
    {
        $existing = DB::table('edu_academic_years')->where('id', $id)->first();
        if (! $existing) {
            throw ApiError::notFound('YEAR_NOT_FOUND', 'Academic year not found');
        }

        if (isset($in['eth_year']) && (int) $in['eth_year'] !== (int) $existing->eth_year) {
            if (DB::table('edu_academic_years')->where('eth_year', (int) $in['eth_year'])->where('id', '!=', $id)->exists()) {
                throw ApiError::conflict('YEAR_EXISTS', 'Academic year already exists');
            }
        }

        DB::transaction(function () use ($actx, $id, $in) {
            $updates = [];
            foreach (['eth_year', 'name', 'starts_on', 'ends_on', 'status'] as $field) {
                if (array_key_exists($field, $in)) {
                    $updates[$field] = $in[$field];
                }
            }

            if (array_key_exists('is_current', $in)) {
                $isCurrent = ! empty($in['is_current']) ? 1 : 0;
                if ($isCurrent) {
                    DB::table('edu_academic_years')->where('id', '!=', $id)->where('is_current', 1)->update(['is_current' => 0]);
                }
                $updates['is_current'] = $isCurrent;
            }

            if (! empty($updates)) {
                $updates['updated_at'] = now();
                DB::table('edu_academic_years')->where('id', $id)->update($updates);
            }

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_academic_year', $id, ['update' => $in], inTrx: true);
        });

        return self::getYear($id);
    }

    public static function setCurrent(array $actx, int $id): array
    {
        DB::transaction(function () use ($actx, $id) {
            $year = DB::table('edu_academic_years')->where('id', $id)->lockForUpdate()->first();
            if (! $year) {
                throw ApiError::notFound('YEAR_NOT_FOUND', 'Academic year not found');
            }

            DB::table('edu_academic_years')->where('is_current', 1)->update(['is_current' => 0]);
            DB::table('edu_academic_years')->where('id', $id)->update([
                'is_current' => 1,
                'status' => $year->status === 'closed' ? 'active' : $year->status,
                'updated_at' => now(),
            ]);

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_academic_year', $id, ['action' => 'set_current'], inTrx: true);
        });

        return self::getYear($id);
    }

    public static function closeYear(array $actx, int $id): array
    {
        $year = DB::table('edu_academic_years')->where('id', $id)->first();
        if (! $year) {
            throw ApiError::notFound('YEAR_NOT_FOUND', 'Academic year not found');
        }

        // Check if there are unpublished assessment marks in this year
        $openMarks = DB::table('edu_scores as s')
            ->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')
            ->join('edu_courses as co', 'co.id', '=', 'a.course_id')
            ->join('edu_classes as c', 'c.id', '=', 'co.class_id')
            ->where('c.academic_year_id', $id)
            ->where('s.status', '!=', 'published')
            ->count();

        if ($openMarks > 0) {
            throw ApiError::conflict('YEAR_HAS_OPEN_MARKS', "Cannot close academic year: {$openMarks} assessment mark(s) are not published yet");
        }

        DB::transaction(function () use ($actx, $id) {
            DB::table('edu_academic_years')->where('id', $id)->update([
                'status' => 'closed',
                'is_current' => 0,
                'updated_at' => now(),
            ]);

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_academic_year', $id, ['action' => 'close'], inTrx: true);
        });

        return self::getYear($id);
    }

    public static function deleteYear(array $actx, int $id): void
    {
        $year = DB::table('edu_academic_years')->where('id', $id)->first();
        if (! $year) {
            throw ApiError::notFound('YEAR_NOT_FOUND', 'Academic year not found');
        }

        $classCount = DB::table('edu_classes')->where('academic_year_id', $id)->count();
        if ($classCount > 0) {
            throw ApiError::conflict('HAS_RECORDS', 'Cannot delete academic year used by classes; archive instead');
        }

        DB::transaction(function () use ($actx, $id) {
            DB::table('edu_terms')->where('academic_year_id', $id)->delete();
            DB::table('edu_academic_years')->where('id', $id)->delete();
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_academic_year', $id, ['action' => 'delete'], inTrx: true);
        });
    }

    // =========================================================================
    // Terms
    // =========================================================================

    public static function listTerms(int $yearId): array
    {
        return DB::table('edu_terms')
            ->where('academic_year_id', $yearId)
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn ($t) => self::serializeTerm($t))
            ->all();
    }

    public static function createTerm(array $actx, int $yearId, array $in): array
    {
        $year = DB::table('edu_academic_years')->where('id', $yearId)->first();
        if (! $year) {
            throw ApiError::notFound('YEAR_NOT_FOUND', 'Academic year not found');
        }

        $name = trim($in['name'] ?? '');
        if ($name === '') {
            throw ApiError::field('name', 'REQUIRED');
        }

        if (DB::table('edu_terms')->where('academic_year_id', $yearId)->where('name', $name)->exists()) {
            throw ApiError::conflict('TERM_EXISTS', 'Term with this name already exists in this academic year');
        }

        // Validate term dates against academic year dates if both exist
        self::assertTermDatesWithinYear($year, $in['starts_on'] ?? null, $in['ends_on'] ?? null);

        $termId = DB::transaction(function () use ($actx, $yearId, $name, $in) {
            $id = DB::table('edu_terms')->insertGetId([
                'academic_year_id' => $yearId,
                'name' => $name,
                'sort_order' => (int) ($in['sort_order'] ?? 0),
                'starts_on' => $in['starts_on'] ?? null,
                'ends_on' => $in['ends_on'] ?? null,
                'status' => $in['status'] ?? 'planned',
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_term', $id, ['create' => $in], inTrx: true);

            return $id;
        });

        $term = DB::table('edu_terms')->where('id', $termId)->first();

        return self::serializeTerm($term);
    }

    public static function updateTerm(array $actx, int $id, array $in): array
    {
        $term = DB::table('edu_terms')->where('id', $id)->first();
        if (! $term) {
            throw ApiError::notFound('TERM_NOT_FOUND', 'Term not found');
        }

        $year = DB::table('edu_academic_years')->where('id', $term->academic_year_id)->first();

        if (isset($in['name']) && trim($in['name']) !== $term->name) {
            $name = trim($in['name']);
            if (DB::table('edu_terms')->where('academic_year_id', $term->academic_year_id)->where('name', $name)->where('id', '!=', $id)->exists()) {
                throw ApiError::conflict('TERM_EXISTS', 'Term with this name already exists in this academic year');
            }
        }

        $startsOn = array_key_exists('starts_on', $in) ? $in['starts_on'] : $term->starts_on;
        $endsOn = array_key_exists('ends_on', $in) ? $in['ends_on'] : $term->ends_on;
        if ($year) {
            self::assertTermDatesWithinYear($year, $startsOn, $endsOn);
        }

        DB::transaction(function () use ($actx, $id, $in) {
            $updates = [];
            foreach (['name', 'sort_order', 'starts_on', 'ends_on', 'status'] as $f) {
                if (array_key_exists($f, $in)) {
                    $updates[$f] = $in[$f];
                }
            }
            if (! empty($updates)) {
                $updates['updated_at'] = now();
                DB::table('edu_terms')->where('id', $id)->update($updates);
            }
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_term', $id, ['update' => $in], inTrx: true);
        });

        $updated = DB::table('edu_terms')->where('id', $id)->first();

        return self::serializeTerm($updated);
    }

    public static function deleteTerm(array $actx, int $id): void
    {
        $term = DB::table('edu_terms')->where('id', $id)->first();
        if (! $term) {
            throw ApiError::notFound('TERM_NOT_FOUND', 'Term not found');
        }

        $classesCount = DB::table('edu_classes')->where('term_id', $id)->count();
        $coursesCount = DB::table('edu_courses')->where('term_id', $id)->count();
        if ($classesCount > 0 || $coursesCount > 0) {
            throw ApiError::conflict('HAS_RECORDS', 'Cannot delete term used by classes or courses');
        }

        DB::transaction(function () use ($actx, $id) {
            DB::table('edu_terms')->where('id', $id)->delete();
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_term', $id, ['action' => 'delete'], inTrx: true);
        });
    }

    private static function assertTermDatesWithinYear(object $year, ?string $startsOn, ?string $endsOn): void
    {
        if ($year->starts_on && $startsOn && $startsOn < $year->starts_on) {
            throw ApiError::validation([['field' => 'starts_on', 'code' => 'TERM_OUTSIDE_YEAR', 'message' => 'Term start date cannot precede academic year start date']]);
        }
        if ($year->ends_on && $endsOn && $endsOn > $year->ends_on) {
            throw ApiError::validation([['field' => 'ends_on', 'code' => 'TERM_OUTSIDE_YEAR', 'message' => 'Term end date cannot exceed academic year end date']]);
        }
        if ($startsOn && $endsOn && $startsOn > $endsOn) {
            throw ApiError::validation([['field' => 'ends_on', 'code' => 'DATE_RANGE_INVALID', 'message' => 'Term end date cannot precede start date']]);
        }
    }

    // =========================================================================
    // Levels (Grades 1–12 + custom levels)
    // =========================================================================

    public static function listLevels(): array
    {
        $levels = DB::table('edu_levels')
            ->orderBy('kind')
            ->orderBy('sort_order')
            ->orderBy('id')
            ->get()
            ->map(fn ($l) => self::serializeLevel($l))
            ->all();

        if (empty($levels)) {
            return [];
        }

        $levelIds = array_column($levels, 'id');
        $counts = DB::table('edu_classes')
            ->whereIn('level_id', $levelIds)
            ->select('level_id', DB::raw('COUNT(*) as total'))
            ->groupBy('level_id')
            ->pluck('total', 'level_id')
            ->all();

        foreach ($levels as &$lvl) {
            $lvl['class_count'] = (int) ($counts[$lvl['id']] ?? 0);
        }

        return $levels;
    }

    public static function createLevel(array $actx, array $in): array
    {
        $code = strtoupper(trim($in['code'] ?? ''));
        if ($code === '') {
            throw ApiError::field('code', 'REQUIRED');
        }

        if (DB::table('edu_levels')->where('code', $code)->exists()) {
            throw ApiError::conflict('LEVEL_EXISTS', 'A level with this code already exists');
        }

        $name = trim($in['name'] ?? '');
        if ($name === '') {
            throw ApiError::field('name', 'REQUIRED');
        }

        $id = DB::transaction(function () use ($actx, $code, $name, $in) {
            $levelId = DB::table('edu_levels')->insertGetId([
                'code' => $code,
                'name' => $name,
                'name_en' => ! empty($in['name_en']) ? trim($in['name_en']) : null,
                'kind' => in_array($in['kind'] ?? '', ['grade', 'extra'], true) ? $in['kind'] : 'extra',
                'sort_order' => (int) ($in['sort_order'] ?? 0),
                'is_active' => isset($in['is_active']) ? ((int) $in['is_active'] ? 1 : 0) : 1,
                'built_in' => 0,
                'created_at' => now(),
                'updated_at' => now(),
            ]);

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_level', $levelId, ['create' => $in], inTrx: true);

            return $levelId;
        });

        $level = DB::table('edu_levels')->where('id', $id)->first();

        return self::serializeLevel($level);
    }

    public static function updateLevel(array $actx, int $id, array $in): array
    {
        $level = DB::table('edu_levels')->where('id', $id)->first();
        if (! $level) {
            throw ApiError::notFound('LEVEL_NOT_FOUND', 'Level not found');
        }

        if (isset($in['code'])) {
            $code = strtoupper(trim($in['code']));
            if ($code !== $level->code) {
                if ($level->built_in) {
                    throw ApiError::forbidden('BUILT_IN_LEVEL', 'Cannot change code of built-in grade level');
                }
                if (DB::table('edu_levels')->where('code', $code)->where('id', '!=', $id)->exists()) {
                    throw ApiError::conflict('LEVEL_EXISTS', 'A level with this code already exists');
                }
            }
        }

        DB::transaction(function () use ($actx, $id, $in, $level) {
            $updates = [];
            foreach (['name', 'name_en', 'kind', 'sort_order', 'is_active'] as $f) {
                if (array_key_exists($f, $in)) {
                    $updates[$f] = $in[$f];
                }
            }
            if (isset($in['code']) && ! $level->built_in) {
                $updates['code'] = strtoupper(trim($in['code']));
            }

            if (! empty($updates)) {
                $updates['updated_at'] = now();
                DB::table('edu_levels')->where('id', $id)->update($updates);
            }

            Audit::log($actx, Audit::EDU_UPDATE, 'edu_level', $id, ['update' => $in], inTrx: true);
        });

        $updated = DB::table('edu_levels')->where('id', $id)->first();

        return self::serializeLevel($updated);
    }

    public static function deleteLevel(array $actx, int $id): void
    {
        $level = DB::table('edu_levels')->where('id', $id)->first();
        if (! $level) {
            throw ApiError::notFound('LEVEL_NOT_FOUND', 'Level not found');
        }

        if ($level->built_in) {
            throw ApiError::forbidden('BUILT_IN_LEVEL', 'Built-in grade levels cannot be deleted');
        }

        $classCount = DB::table('edu_classes')->where('level_id', $id)->count();
        if ($classCount > 0) {
            throw ApiError::conflict('HAS_RECORDS', 'Cannot delete level used by classes');
        }

        DB::transaction(function () use ($actx, $id) {
            DB::table('edu_levels')->where('id', $id)->delete();
            Audit::log($actx, Audit::EDU_UPDATE, 'edu_level', $id, ['action' => 'delete'], inTrx: true);
        });
    }

    // =========================================================================
    // Helpers & Serialization
    // =========================================================================

    public static function serializeYear(object $y): array
    {
        return [
            'id' => (int) $y->id,
            'eth_year' => (int) $y->eth_year,
            'name' => $y->name,
            'starts_on' => $y->starts_on,
            'ends_on' => $y->ends_on,
            'status' => $y->status,
            'is_current' => (bool) $y->is_current,
            'created_at' => $y->created_at,
            'updated_at' => $y->updated_at,
        ];
    }

    public static function serializeTerm(object $t): array
    {
        return [
            'id' => (int) $t->id,
            'academic_year_id' => (int) $t->academic_year_id,
            'name' => $t->name,
            'sort_order' => (int) $t->sort_order,
            'starts_on' => $t->starts_on,
            'ends_on' => $t->ends_on,
            'status' => $t->status,
        ];
    }

    public static function serializeLevel(object $l): array
    {
        return [
            'id' => (int) $l->id,
            'code' => $l->code,
            'name' => $l->name,
            'name_en' => $l->name_en,
            'kind' => $l->kind,
            'sort_order' => (int) $l->sort_order,
            'is_active' => (bool) $l->is_active,
            'built_in' => (bool) $l->built_in,
        ];
    }
}
