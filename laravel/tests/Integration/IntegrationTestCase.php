<?php

namespace Tests\Integration;

use App\Mz\Auth\Tokens;
use App\Mz\Support\Crypto;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Workflow tests against a real MySQL / MariaDB copy of the schema (the services use MySQL-only
 * SQL, so SQLite cannot run them). Each test runs in a transaction that is rolled back.
 *
 * Set up once:  create database `mh_app_test` from hersolot_mh_prod.sql, then
 *               DB_DATABASE=mh_app_test php artisan migrate --force
 * Run:          php vendor/bin/phpunit --testsuite Integration
 * Skipped (not failed) when that database cannot be reached. Override with MZ_IT_DB / MZ_IT_HOST /
 * MZ_IT_USER / MZ_IT_PASSWORD.
 */
abstract class IntegrationTestCase extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        config([
            'database.default' => 'mysql',
            'database.connections.mysql.host' => getenv('MZ_IT_HOST') ?: '127.0.0.1',
            'database.connections.mysql.database' => getenv('MZ_IT_DB') ?: 'mh_app_test',
            'database.connections.mysql.username' => getenv('MZ_IT_USER') ?: 'root',
            'database.connections.mysql.password' => getenv('MZ_IT_PASSWORD') ?: '',
        ]);
        DB::purge('mysql');
        try {
            DB::connection()->getPdo();
        } catch (\Throwable $e) {
            $this->markTestSkipped('Integration database unavailable: ' . $e->getMessage());
        }
        DB::beginTransaction();
    }

    protected function tearDown(): void
    {
        if (DB::transactionLevel() > 0) DB::rollBack();
        parent::tearDown();
    }

    /** A member account (optionally holding direct permission grants, i.e. member staff). */
    protected function member(array $permissions = [], array $attrs = []): object
    {
        $id = DB::table('users')->insertGetId($attrs + [
            'full_name' => 'IT Member ' . Crypto::uuid(),
            'phone' => '09' . random_int(10000000, 99999999),
            'password_hash' => 'x',
            'account_type' => 'user',
            'status' => 'active',
            'membership_status' => 'active',
            'member_group' => 'youth_adult',
            'device_id' => 'it-device-' . Crypto::uuid(),
        ]);
        foreach ($permissions as $key) $this->grant($id, $key);
        return DB::table('users')->where('id', $id)->first();
    }

    protected function grant(int $userId, string $key): void
    {
        $pid = DB::table('permissions')->where('key', $key)->value('id');
        $this->assertNotNull($pid, "permission $key missing from the permissions table");
        DB::table('user_permissions')->insertOrIgnore(['user_id' => $userId, 'permission_id' => $pid]);
    }

    /** Signed request as $user (access token bound to the user's trusted device). */
    protected function as(object $user, string $method, string $uri, array $data = []): TestResponse
    {
        $token = Tokens::signAccess($user, 'app', $user->device_id)['token'];
        return $this->json($method, '/api/v1/' . ltrim($uri, '/'), $data, ['Authorization' => "Bearer $token"]);
    }

    /** A published one-off program starting $hoursFromNow hours from now. */
    protected function program(array $attrs = [], int $hoursFromNow = 72): object
    {
        $start = gmdate('Y-m-d H:i:s', time() + $hoursFromNow * 3600);
        $end = gmdate('Y-m-d H:i:s', time() + ($hoursFromNow + 2) * 3600);
        $id = DB::table('programs')->insertGetId($attrs + ['title' => 'IT Program', 'starts_at' => $start, 'ends_at' => $end, 'status' => 'published', 'requires_attendance' => 1, 'audience' => 'all']);
        return DB::table('programs')->where('id', $id)->first();
    }
}
