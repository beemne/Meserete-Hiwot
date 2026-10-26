<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (!Schema::hasTable('diagnostic_reports')) {
            Schema::create('diagnostic_reports', function (Blueprint $table) {
                $table->id();
                $table->string('report_id', 64)->unique();
                $table->unsignedBigInteger('user_id')->nullable()->index();
                $table->boolean('is_user_report')->default(false)->index();
                $table->string('module', 64)->default('general')->index();
                $table->string('screen', 128)->nullable();
                $table->string('operation', 128)->nullable();
                $table->string('category', 64)->default('error')->index();
                $table->string('severity', 32)->default('error')->index(); // info, warning, error, critical
                $table->text('message');
                $table->mediumText('stack_trace')->nullable();
                $table->string('endpoint', 255)->nullable();
                $table->unsignedSmallInteger('http_status')->nullable();
                $table->string('app_version', 32)->nullable();
                $table->string('platform', 32)->nullable();
                $table->boolean('is_offline')->default(false);
                $table->string('screenshot_path', 255)->nullable();
                $table->text('user_description')->nullable();
                $table->text('reproduce_steps')->nullable();
                $table->string('status', 32)->default('new')->index(); // new, investigating, resolved, dismissed
                $table->text('status_note')->nullable();
                $table->unsignedBigInteger('resolved_by')->nullable();
                $table->timestamp('resolved_at')->nullable();
                $table->unsignedInteger('occurrences')->default(1);
                $table->timestamp('first_seen_at')->nullable();
                $table->timestamp('last_seen_at')->nullable();
                $table->timestamps();
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('diagnostic_reports');
    }
};
