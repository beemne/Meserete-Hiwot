<?php

use App\Mz\Auth\Tokens;
use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * App sessions no longer time out (members were signed out automatically 30 days after their last
 * refresh). Sessions that are still valid keep going; revoked or already-expired ones are untouched,
 * and the hidden system console keeps its short lifetime.
 * Rollback gives the extended sessions the former 30-day window from now.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::table('refresh_tokens')->where('scope', 'app')->whereNull('revoked_at')
            ->where('expires_at', '>', gmdate('Y-m-d H:i:s'))->update(['expires_at' => Tokens::NO_EXPIRY]);
    }

    public function down(): void
    {
        DB::table('refresh_tokens')->where('scope', 'app')->where('expires_at', Tokens::NO_EXPIRY)
            ->update(['expires_at' => gmdate('Y-m-d H:i:s', time() + 30 * 86400)]);
    }
};
