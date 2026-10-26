<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('programs')) {
            DB::statement("ALTER TABLE programs MODIFY recurrence enum('once','weekly','monthly','twice_monthly','ethiopian_days') NOT NULL DEFAULT 'once'");
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('programs')) {
            DB::statement("ALTER TABLE programs MODIFY recurrence enum('once','weekly','monthly','ethiopian_days') NOT NULL DEFAULT 'once'");
        }
    }
};
