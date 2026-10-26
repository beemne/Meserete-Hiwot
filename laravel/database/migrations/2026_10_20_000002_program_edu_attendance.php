<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.3+19: Class attendance through programs (F4) and attendance scoring intervals (F6).
 *  - program_edu_classes: links programs to edu_classes (many-to-many);
 *  - attendance_edu_classes: links attendance records to classes for enrolled students;
 *  - edu.attendance_cutover: setting date when class attendance moves to programs;
 *  - attendance_sync_conflicts: supports legacy_class conflicts with nullable program_id and class_id;
 *  - selection_config_versions: adds nullable config column for versioned attendance rules.
 */
return new class extends Migration
{
    public function up(): void
    {
        $driver = DB::getDriverName();
        $isSqlite = $driver === 'sqlite';

        // 1. program_edu_classes (F4)
        if (! Schema::hasTable('program_edu_classes')) {
            Schema::create('program_edu_classes', function (Blueprint $table) {
                $table->unsignedInteger('program_id');
                $table->unsignedInteger('class_id');
                $table->timestamp('created_at')->useCurrent();
                $table->primary(['program_id', 'class_id']);
                $table->index('class_id', 'idx_prog_edu_classes_class');
            });
        }

        // 2. attendance_edu_classes (F4)
        if (! Schema::hasTable('attendance_edu_classes')) {
            Schema::create('attendance_edu_classes', function (Blueprint $table) {
                $table->unsignedBigInteger('attendance_id');
                $table->unsignedInteger('class_id');
                $table->timestamp('created_at')->useCurrent();
                $table->primary(['attendance_id', 'class_id']);
                $table->index('class_id', 'idx_att_edu_classes_class');
            });
        }

        // 3. Setting edu.attendance_cutover (F4 / D5)
        if (Schema::hasTable('settings') && ! DB::table('settings')->where('key', 'edu.attendance_cutover')->exists()) {
            DB::table('settings')->insert([
                'key' => 'edu.attendance_cutover',
                'value' => json_encode('2026-10-20'),
                'updated_by' => null,
            ]);
        }

        // 4. attendance_sync_conflicts support for legacy_class (F4)
        if (Schema::hasTable('attendance_sync_conflicts')) {
            if (! Schema::hasColumn('attendance_sync_conflicts', 'class_id')) {
                Schema::table('attendance_sync_conflicts', function (Blueprint $table) {
                    $table->unsignedInteger('class_id')->nullable()->after('program_id');
                    $table->index('class_id', 'idx_att_sync_conflicts_class');
                });
            }

            if (! $isSqlite) {
                DB::statement("ALTER TABLE attendance_sync_conflicts MODIFY COLUMN program_id int unsigned NULL");
                DB::statement("ALTER TABLE attendance_sync_conflicts MODIFY COLUMN kind enum('record','session_start','session_end','legacy_class') NOT NULL");
            }
        }

        // 5. selection_config_versions config column (F6)
        if (Schema::hasTable('selection_config_versions')) {
            if (! Schema::hasColumn('selection_config_versions', 'config')) {
                Schema::table('selection_config_versions', function (Blueprint $table) {
                    $table->longText('config')->nullable()->after('departments');
                });
            }

            if (! $isSqlite) {
                DB::statement("ALTER TABLE selection_config_versions MODIFY COLUMN allocation longtext NULL");
                DB::statement("ALTER TABLE selection_config_versions MODIFY COLUMN passing longtext NULL");
                DB::statement("ALTER TABLE selection_config_versions MODIFY COLUMN departments longtext NULL");
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('attendance_edu_classes');
        Schema::dropIfExists('program_edu_classes');

        if (Schema::hasTable('settings')) {
            DB::table('settings')->where('key', 'edu.attendance_cutover')->delete();
        }

        if (Schema::hasTable('attendance_sync_conflicts') && Schema::hasColumn('attendance_sync_conflicts', 'class_id')) {
            Schema::table('attendance_sync_conflicts', function (Blueprint $table) {
                $table->dropIndex('idx_att_sync_conflicts_class');
                $table->dropColumn('class_id');
            });
        }

        if (Schema::hasTable('selection_config_versions') && Schema::hasColumn('selection_config_versions', 'config')) {
            Schema::table('selection_config_versions', function (Blueprint $table) {
                $table->dropColumn('config');
            });
        }
    }
};
