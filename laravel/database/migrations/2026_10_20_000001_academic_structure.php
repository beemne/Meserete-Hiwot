<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.3+18: Academic structure, exclusivity, and course offerings (F1, F2, F3).
 * Additive only — existing classes, courses, and enrollments keep their data:
 *  - edu_academic_years: Ethiopian calendar academic year (unique eth_year, exactly one is_current=1);
 *  - edu_terms: terms within an academic year (UNIQUE per year);
 *  - edu_levels: Grades 1–12 seeded + custom admin levels (e.g. Adult catechism);
 *  - edu_classes: gains academic_year_id, term_id, level_id, allow_multiple (backfilled from text);
 *  - edu_enrollments: gains academic_year_id, exclusive, and exclusive_key generated unique column;
 *  - edu_courses: gains term_id, member_groups, mode, pass_mark;
 *  - program_edu_courses: links physical courses to scheduled Sunday-school programs.
 */
return new class extends Migration
{
    private const BUILT_IN_GRADES = [
        ['code' => 'G1', 'name' => 'ክፍል 1', 'name_en' => 'Grade 1', 'sort_order' => 1],
        ['code' => 'G2', 'name' => 'ክፍል 2', 'name_en' => 'Grade 2', 'sort_order' => 2],
        ['code' => 'G3', 'name' => 'ክፍል 3', 'name_en' => 'Grade 3', 'sort_order' => 3],
        ['code' => 'G4', 'name' => 'ክፍል 4', 'name_en' => 'Grade 4', 'sort_order' => 4],
        ['code' => 'G5', 'name' => 'ክፍል 5', 'name_en' => 'Grade 5', 'sort_order' => 5],
        ['code' => 'G6', 'name' => 'ክፍል 6', 'name_en' => 'Grade 6', 'sort_order' => 6],
        ['code' => 'G7', 'name' => 'ክፍል 7', 'name_en' => 'Grade 7', 'sort_order' => 7],
        ['code' => 'G8', 'name' => 'ክፍል 8', 'name_en' => 'Grade 8', 'sort_order' => 8],
        ['code' => 'G9', 'name' => 'ክፍል 9', 'name_en' => 'Grade 9', 'sort_order' => 9],
        ['code' => 'G10', 'name' => 'ክፍል 10', 'name_en' => 'Grade 10', 'sort_order' => 10],
        ['code' => 'G11', 'name' => 'ክፍል 11', 'name_en' => 'Grade 11', 'sort_order' => 11],
        ['code' => 'G12', 'name' => 'ክፍል 12', 'name_en' => 'Grade 12', 'sort_order' => 12],
    ];

    public function up(): void
    {
        $t = 'ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci';
        $driver = DB::getDriverName();
        $isSqlite = $driver === 'sqlite';

        // 1. edu_academic_years
        if (! Schema::hasTable('edu_academic_years')) {
            DB::statement("CREATE TABLE edu_academic_years (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                eth_year int NOT NULL UNIQUE,
                name varchar(100) NOT NULL,
                starts_on date DEFAULT NULL,
                ends_on date DEFAULT NULL,
                status enum('planned','active','closed') NOT NULL DEFAULT 'planned',
                is_current tinyint(1) NOT NULL DEFAULT 0,
                created_by int unsigned DEFAULT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_academic_years_status (status),
                KEY edu_academic_years_current (is_current)
            ) $t");
        }

        // 2. edu_terms
        if (! Schema::hasTable('edu_terms')) {
            DB::statement("CREATE TABLE edu_terms (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                academic_year_id int unsigned NOT NULL,
                name varchar(100) NOT NULL,
                sort_order int NOT NULL DEFAULT 0,
                starts_on date DEFAULT NULL,
                ends_on date DEFAULT NULL,
                status enum('planned','active','closed') NOT NULL DEFAULT 'planned',
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                UNIQUE KEY edu_terms_year_name (academic_year_id, name),
                KEY edu_terms_order (academic_year_id, sort_order)
            ) $t");
        }

        // 3. edu_levels
        if (! Schema::hasTable('edu_levels')) {
            DB::statement("CREATE TABLE edu_levels (
                id int unsigned NOT NULL AUTO_INCREMENT PRIMARY KEY,
                code varchar(30) NOT NULL UNIQUE,
                name varchar(100) NOT NULL,
                name_en varchar(100) DEFAULT NULL,
                kind enum('grade','extra') NOT NULL DEFAULT 'grade',
                sort_order int NOT NULL DEFAULT 0,
                is_active tinyint(1) NOT NULL DEFAULT 1,
                built_in tinyint(1) NOT NULL DEFAULT 0,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                updated_at datetime NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
                KEY edu_levels_order (kind, sort_order)
            ) $t");

            $now = now()->format('Y-m-d H:i:s');
            $levels = [];
            foreach (self::BUILT_IN_GRADES as $g) {
                $levels[] = [
                    'code' => $g['code'],
                    'name' => $g['name'],
                    'name_en' => $g['name_en'],
                    'kind' => 'grade',
                    'sort_order' => $g['sort_order'],
                    'is_active' => 1,
                    'built_in' => 1,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
            DB::table('edu_levels')->insert($levels);
        }

        // 4. edu_classes new columns
        if (! Schema::hasColumn('edu_classes', 'academic_year_id')) {
            DB::statement('ALTER TABLE edu_classes
                ADD COLUMN academic_year_id int unsigned DEFAULT NULL AFTER department_id,
                ADD COLUMN term_id int unsigned DEFAULT NULL AFTER academic_year_id,
                ADD COLUMN level_id int unsigned DEFAULT NULL AFTER term_id,
                ADD COLUMN allow_multiple tinyint(1) NOT NULL DEFAULT 0 AFTER level_id,
                ADD KEY edu_classes_academic_year (academic_year_id),
                ADD KEY edu_classes_term (term_id),
                ADD KEY edu_classes_level (level_id)');
        }

        // Backfill academic years from existing distinct text values in edu_classes
        if (Schema::hasTable('edu_classes')) {
            $existingClasses = DB::table('edu_classes')->whereNotNull('academic_year')->get(['id', 'academic_year']);
            $yearMap = [];
            foreach ($existingClasses as $c) {
                if (preg_match('/(\d{4})/', (string) $c->academic_year, $matches)) {
                    $ethYear = (int) $matches[1];
                    if (! isset($yearMap[$ethYear])) {
                        $yearId = DB::table('edu_academic_years')->where('eth_year', $ethYear)->value('id');
                        if (! $yearId) {
                            $yearId = DB::table('edu_academic_years')->insertGetId([
                                'eth_year' => $ethYear,
                                'name' => "{$ethYear} ዓ.ም",
                                'status' => 'active',
                                'is_current' => 1,
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]);
                        }
                        $yearMap[$ethYear] = $yearId;
                    }
                    DB::table('edu_classes')->where('id', $c->id)->whereNull('academic_year_id')->update([
                        'academic_year_id' => $yearMap[$ethYear],
                    ]);
                }
            }
        }

        // 5. edu_enrollments: F2 check existing exclusivity first
        if (Schema::hasTable('edu_enrollments')) {
            // Check if any student currently has duplicate active enrollments in the same class
            // or in classes of the same year
            $conflicts = DB::table('edu_enrollments as e1')
                ->join('edu_enrollments as e2', function ($j) {
                    $j->on('e1.user_id', '=', 'e2.user_id')
                      ->on('e1.id', '<', 'e2.id')
                      ->where('e1.status', '=', 'active')
                      ->where('e2.status', '=', 'active');
                })
                ->join('edu_classes as c1', 'c1.id', '=', 'e1.class_id')
                ->join('edu_classes as c2', 'c2.id', '=', 'e2.class_id')
                ->where('c1.allow_multiple', 0)
                ->where('c2.allow_multiple', 0)
                ->whereNotNull('c1.academic_year_id')
                ->whereColumn('c1.academic_year_id', '=', 'c2.academic_year_id')
                ->pluck('e1.user_id')
                ->unique()
                ->values()
                ->all();

            if (! empty($conflicts)) {
                throw new \RuntimeException('MIGRATION_STOPPED: Students with duplicate active exclusive enrollments found: ' . implode(',', $conflicts));
            }

            if (! Schema::hasColumn('edu_enrollments', 'academic_year_id')) {
                DB::statement('ALTER TABLE edu_enrollments
                    ADD COLUMN academic_year_id int unsigned DEFAULT NULL AFTER class_id,
                    ADD COLUMN exclusive tinyint(1) NOT NULL DEFAULT 1 AFTER program,
                    ADD KEY edu_enrollments_year (academic_year_id)');

                // Backfill academic_year_id and exclusive from edu_classes
                if (! $isSqlite) {
                    DB::statement('UPDATE edu_enrollments e
                        JOIN edu_classes c ON c.id = e.class_id
                        SET e.academic_year_id = c.academic_year_id,
                            e.exclusive = IF(c.allow_multiple = 1, 0, 1)');
                } else {
                    $enrollments = DB::table('edu_enrollments')->get(['id', 'class_id']);
                    foreach ($enrollments as $enr) {
                        $cls = DB::table('edu_classes')->where('id', $enr->class_id)->first(['academic_year_id', 'allow_multiple']);
                        if ($cls) {
                            DB::table('edu_enrollments')->where('id', $enr->id)->update([
                                'academic_year_id' => $cls->academic_year_id,
                                'exclusive' => $cls->allow_multiple == 1 ? 0 : 1,
                            ]);
                        }
                    }
                }
            }

            if (! Schema::hasColumn('edu_enrollments', 'exclusive_key')) {
                $concatExpr = $isSqlite ? "(user_id || ':' || academic_year_id)" : "CONCAT(user_id, ':', academic_year_id)";
                $generatedSql = "ALTER TABLE edu_enrollments ADD COLUMN exclusive_key varchar(64) GENERATED ALWAYS AS (
                    CASE WHEN status = 'active' AND exclusive = 1 AND academic_year_id IS NOT NULL THEN $concatExpr ELSE NULL END
                ) STORED";
                DB::statement($generatedSql);
                DB::statement('ALTER TABLE edu_enrollments ADD UNIQUE KEY edu_enrollments_exclusive_key_unique (exclusive_key)');
            }
        }

        // 6. edu_courses new columns (F3)
        if (! Schema::hasColumn('edu_courses', 'mode')) {
            DB::statement("ALTER TABLE edu_courses
                ADD COLUMN term_id int unsigned DEFAULT NULL AFTER subject_id,
                ADD COLUMN member_groups varchar(500) DEFAULT NULL AFTER term_id,
                ADD COLUMN mode enum('physical','online','hybrid') NOT NULL DEFAULT 'physical' AFTER member_groups,
                ADD COLUMN pass_mark decimal(5,2) NOT NULL DEFAULT 50.00 AFTER mode,
                ADD KEY edu_courses_term (term_id)");
        }

        // 7. program_edu_courses (F3)
        if (! Schema::hasTable('program_edu_courses')) {
            DB::statement("CREATE TABLE program_edu_courses (
                program_id int unsigned NOT NULL,
                course_id int unsigned NOT NULL,
                created_at datetime NOT NULL DEFAULT current_timestamp(),
                PRIMARY KEY (program_id, course_id),
                KEY fk_prog_edu_courses_course (course_id)
            ) $t");
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('program_edu_courses');

        if (Schema::hasColumn('edu_courses', 'mode')) {
            DB::statement('ALTER TABLE edu_courses
                DROP COLUMN term_id,
                DROP COLUMN member_groups,
                DROP COLUMN mode,
                DROP COLUMN pass_mark');
        }

        if (Schema::hasColumn('edu_enrollments', 'exclusive_key')) {
            DB::statement('ALTER TABLE edu_enrollments DROP KEY edu_enrollments_exclusive_key_unique');
            DB::statement('ALTER TABLE edu_enrollments DROP COLUMN exclusive_key');
        }

        if (Schema::hasColumn('edu_enrollments', 'academic_year_id')) {
            DB::statement('ALTER TABLE edu_enrollments
                DROP COLUMN academic_year_id,
                DROP COLUMN exclusive');
        }

        if (Schema::hasColumn('edu_classes', 'academic_year_id')) {
            DB::statement('ALTER TABLE edu_classes
                DROP COLUMN academic_year_id,
                DROP COLUMN term_id,
                DROP COLUMN level_id,
                DROP COLUMN allow_multiple');
        }

        Schema::dropIfExists('edu_terms');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('edu_academic_years');
    }
};
