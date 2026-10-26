<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Unified Education Attendance Architecture:
 *  - programs.schedule_id: persistent relationship to edu_schedule (source of truth timetable entry)
 *  - program_categories.is_education: flags Education & Training category for timetable workflows
 */
return new class extends Migration
{
    public function up(): void
    {
        $driver = DB::getDriverName();
        $isSqlite = $driver === 'sqlite';

        // 1. programs.schedule_id
        if (Schema::hasTable('programs') && ! Schema::hasColumn('programs', 'schedule_id')) {
            Schema::table('programs', function (Blueprint $table) use ($isSqlite) {
                $table->unsignedInteger('schedule_id')->nullable()->after('category_id');
                $table->index('schedule_id', 'programs_schedule_id_index');
                if (! $isSqlite && Schema::hasTable('edu_schedule')) {
                    $table->foreign('schedule_id', 'programs_schedule_id_foreign')
                        ->references('id')
                        ->on('edu_schedule')
                        ->onDelete('set null');
                }
            });
        }

        // 2. program_categories.is_education
        if (Schema::hasTable('program_categories') && ! Schema::hasColumn('program_categories', 'is_education')) {
            Schema::table('program_categories', function (Blueprint $table) {
                $table->boolean('is_education')->default(false)->after('color');
                $table->index('is_education', 'program_categories_is_education_index');
            });

            // Flag Education and Training categories
            DB::table('program_categories')
                ->where('id', 2)
                ->orWhere('name', 'like', '%ትምህርት%')
                ->orWhere('name_en', 'like', '%Education%')
                ->update(['is_education' => 1]);
        }
    }

    public function down(): void
    {
        $driver = DB::getDriverName();
        $isSqlite = $driver === 'sqlite';

        if (Schema::hasTable('programs') && Schema::hasColumn('programs', 'schedule_id')) {
            Schema::table('programs', function (Blueprint $table) use ($isSqlite) {
                if (! $isSqlite) {
                    $table->dropForeign('programs_schedule_id_foreign');
                }
                $table->dropIndex('programs_schedule_id_index');
                $table->dropColumn('schedule_id');
            });
        }

        if (Schema::hasTable('program_categories') && Schema::hasColumn('program_categories', 'is_education')) {
            Schema::table('program_categories', function (Blueprint $table) {
                $table->dropIndex('program_categories_is_education_index');
                $table->dropColumn('is_education');
            });
        }
    }
};
