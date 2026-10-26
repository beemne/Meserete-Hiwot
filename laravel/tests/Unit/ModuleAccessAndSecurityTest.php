<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Professions;
use App\Mz\Services\Settings;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class ModuleAccessAndSecurityTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('settings')) {
            Schema::create('settings', function ($table) {
                $table->string('key')->primary();
                $table->text('value')->nullable();
                $table->unsignedBigInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }
    }

    private function createAuth(int $id, bool $isAdmin, array $permissions = [], int $level = 0, bool $isSystem = false): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = 'Test User';
        $auth->status = 'active';
        $auth->accountType = $isAdmin ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->deviceId = 'test-device';
        $auth->mustChangePassword = false;
        $auth->isAdmin = $isAdmin;
        $auth->isSystem = $isSystem;
        $auth->isMemberStaff = false;
        $auth->role = $isAdmin ? ['id' => 1, 'slug' => 'superadmin', 'name' => 'Superadmin', 'level' => $level] : null;
        $auth->level = $level;
        $auth->departments = [];
        $auth->permissions = array_fill_keys($permissions, true);
        return $auth;
    }

    public function test_default_module_policy(): void
    {
        $policy = Settings::MODULES_POLICY_DEFAULT;
        $this->assertTrue($policy['mezmur_enabled']);
        $this->assertTrue($policy['education_enabled']);
        $this->assertIsArray($policy['group_overrides']);
        $this->assertIsArray($policy['user_overrides']);
    }

    public function test_resolve_module_access_default(): void
    {
        $access = Settings::resolveModuleAccess(null, null);
        $this->assertIsArray($access);
        $this->assertArrayHasKey('mezmur', $access);
        $this->assertArrayHasKey('education', $access);
        $this->assertTrue($access['mezmur']);
        $this->assertTrue($access['education']);
    }

    public function test_resolve_module_access_with_user_override(): void
    {
        Settings::put('modules.policy', [
            'mezmur_enabled' => true,
            'education_enabled' => true,
            'group_overrides' => [],
            'user_overrides' => [
                '42' => [
                    'mezmur_enabled' => true,
                    'education_enabled' => false,
                ],
            ],
        ], 1);

        $access42 = Settings::resolveModuleAccess(42, null);
        $this->assertTrue($access42['mezmur']);
        $this->assertFalse($access42['education']);

        // Other users still get global default
        $accessOther = Settings::resolveModuleAccess(99, null);
        $this->assertTrue($accessOther['mezmur']);
        $this->assertTrue($accessOther['education']);
    }

    public function test_professions_can_manage_authorization(): void
    {
        $regularUser = $this->createAuth(10, false);
        $this->expectException(ApiError::class);
        Professions::assertCanManage($regularUser);
    }

    public function test_professions_can_manage_allowed_for_admin(): void
    {
        $adminUser = $this->createAuth(1, true, ['users.manage', 'settings.manage'], 100);
        Professions::assertCanManage($adminUser);
        $this->assertTrue(true);
    }
}
