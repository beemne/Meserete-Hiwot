<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Baseline: the complete schema of the Node.js backend after its last knex migration
 * (20261005000001_member_ids_chat.js) plus its reference data (roles, permissions, departments,
 * settings…). database/baseline/*.sql were dumped from a database migrated by the Node backend.
 *
 *  - Empty database → the schema and reference data are created.
 *  - Database already used by the Node.js backend → nothing is changed (data is kept). It must be
 *    at the last knex migration; run `npm run migrate` in the Node backend once if it is not.
 */
return new class extends Migration
{
    public const LAST_KNEX = '20261005000001_member_ids_chat.js';

    public function up(): void
    {
        if (Schema::hasTable('users')) {
            if (Schema::hasTable('knex_migrations')) {
                $done = DB::table('knex_migrations')->where('name', self::LAST_KNEX)->exists();
                if (! $done) {
                    throw new RuntimeException('This database is behind the Node.js backend schema. Run `npm run migrate` in the Node backend first (needs ' . self::LAST_KNEX . ').');
                }
            }
            return;
        }
        $dir = database_path('baseline');
        DB::unprepared(file_get_contents("$dir/schema.sql"));
        DB::unprepared(file_get_contents("$dir/reference_data.sql"));
    }

    public function down(): void
    {
        // The baseline is never rolled back automatically (it would drop every table and its data).
    }
};
