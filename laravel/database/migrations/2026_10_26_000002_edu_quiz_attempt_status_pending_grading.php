<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Add 'pending_grading' to edu_quiz_attempts.status enum so attempts awaiting
 * teacher short-answer evaluation can be tracked with status='pending_grading'.
 */
return new class extends Migration
{
    public function up(): void
    {
        $driver = DB::getDriverName();
        if ($driver === 'mysql' && Schema::hasTable('edu_quiz_attempts')) {
            DB::statement("ALTER TABLE edu_quiz_attempts MODIFY COLUMN status ENUM('in_progress','submitted','pending_grading','graded') NOT NULL DEFAULT 'in_progress'");
        }
    }

    public function down(): void
    {
        $driver = DB::getDriverName();
        if ($driver === 'mysql' && Schema::hasTable('edu_quiz_attempts')) {
            // Only revert if no records have status 'pending_grading', or update them first
            DB::table('edu_quiz_attempts')->where('status', 'pending_grading')->update(['status' => 'submitted']);
            DB::statement("ALTER TABLE edu_quiz_attempts MODIFY COLUMN status ENUM('in_progress','submitted','graded') NOT NULL DEFAULT 'in_progress'");
        }
    }
};
