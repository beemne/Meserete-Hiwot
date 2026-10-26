<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasTable('sinksar_daily')) {
            Schema::create('sinksar_daily', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->string('gregorian_date', 10)->unique();
                $table->string('ethiopian_date', 10)->index();
                $table->integer('ethiopian_year')->index();
                $table->integer('ethiopian_month')->index();
                $table->integer('ethiopian_day')->index();
                $table->string('month_name_am', 50)->nullable();
                $table->string('weekday_am', 50)->nullable();
                $table->string('weekday_en', 50)->nullable();
                $table->boolean('is_fasting')->default(false);
                $table->string('fasting_reason', 255)->nullable();
                $table->json('annual_feasts')->nullable();
                $table->json('monthly_feasts')->nullable();
                $table->text('summary')->nullable();
                $table->boolean('full_text_available')->default(false);
                $table->json('raw_payload')->nullable();
                $table->boolean('notification_sent')->default(false)->index();
                $table->timestamp('refreshed_at')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('sinksar_narratives')) {
            Schema::create('sinksar_narratives', function (Blueprint $table) {
                $table->bigIncrements('id');
                $table->integer('ethiopian_month')->index();
                $table->integer('ethiopian_day')->index();
                $table->string('title', 255)->index();
                $table->string('source', 255)->nullable();
                $table->text('summary')->nullable();
                $table->longText('body');
                $table->boolean('verified')->default(false);
                $table->timestamps();
                $table->index(['ethiopian_month', 'ethiopian_day']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('sinksar_narratives');
        Schema::dropIfExists('sinksar_daily');
    }
};
