<?php

use App\Mz\Auth\Tokens;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Signed-in accounts stay signed in: every live session (app and system console) loses its expiry
 * date, including sessions issued with the former 30-day / 12-hour limits. Signed-out (revoked)
 * sessions are untouched. Rollback is not possible without knowing the former dates: nothing.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::table('refresh_tokens')->whereNull('revoked_at')->where('expires_at', '<>', Tokens::NO_EXPIRY)->update(['expires_at' => Tokens::NO_EXPIRY]);
    }

    public function down(): void
    {
    }
};
