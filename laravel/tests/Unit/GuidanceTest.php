<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\GuidanceService;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class GuidanceTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // 1. Run migrations for guidance system on test database
        $migration = require __DIR__ . '/../../database/migrations/2026_10_14_000001_create_guidance_system_tables.php';
        $migration->up();

        // 2. Seed default guidance articles
        $seeder = new \Database\Seeders\GuidanceSeeder();
        $seeder->run();
    }

    private function createAuthContext(int $id, bool $isAdmin, array $permissions = [], array $departments = []): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $isAdmin ? 'Admin User' : 'Test Member';
        $auth->status = 'active';
        $auth->accountType = $isAdmin ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->deviceId = 'test-device';
        $auth->mustChangePassword = false;
        $auth->isAdmin = $isAdmin;
        $auth->isSystem = false;
        $auth->isMemberStaff = false;
        $auth->role = $isAdmin ? ['id' => 1, 'slug' => 'superadmin', 'name' => 'Superadmin', 'level' => 100] : null;
        $auth->level = $isAdmin ? 100 : 0;
        $auth->departments = $departments;
        $auth->permissions = array_fill_keys($permissions, true);
        return $auth;
    }

    public function test_guidance_categories_and_roles(): void
    {
        $member = $this->createAuthContext(10, false);
        $articles = GuidanceService::listForUser($member);
        $this->assertIsArray($articles);
        $this->assertNotEmpty($articles);

        // Regular member should not see admin-only articles
        foreach ($articles as $a) {
            $this->assertNotSame('admin', $a['target_role']);
            $this->assertSame('published', $a['status']);
        }

        // Admin should see admin articles when holding relevant permissions
        $admin = $this->createAuthContext(1, true, ['guidance.manage', 'users.view', 'programs.manage']);
        $adminArticles = GuidanceService::listForUser($admin);
        $adminOnlyFound = false;
        foreach ($adminArticles as $a) {
            if ($a['target_role'] === 'admin') {
                $adminOnlyFound = true;
                break;
            }
        }
        $this->assertTrue($adminOnlyFound, 'Admin should be able to see admin-targeted guidance articles');
    }

    public function test_contextual_guidance_lookup(): void
    {
        $article = GuidanceService::getForScreen(null, '/programs');
        $this->assertNotNull($article);
        $this->assertSame('/programs', $article['target_screen']);
        $this->assertNotEmpty($article['title']);
        $this->assertIsArray($article['steps']);
        $this->assertIsArray($article['faq_items']);
    }

    public function test_article_by_slug_retrieval(): void
    {
        $article = GuidanceService::getBySlugOrId(null, 'welcome-onboarding');
        $this->assertSame('welcome-onboarding', $article['slug']);
        $this->assertSame('welcome_tour', $article['tour_id']);
        $this->assertNotEmpty($article['steps']);
    }

    public function test_tour_progress_tracking_and_reset(): void
    {
        $user = $this->createAuthContext(42, false);

        // Initially no progress
        $progress = GuidanceService::getTourProgress($user);
        $this->assertIsArray($progress);

        // Save progress for welcome tour
        $saved = GuidanceService::saveTourProgress($user, 'welcome_tour', true, false);
        $this->assertSame('welcome_tour', $saved['tour_id']);
        $this->assertTrue($saved['completed']);
        $this->assertFalse($saved['dismissed']);

        // Check progress list
        $progress = GuidanceService::getTourProgress($user);
        $this->assertCount(1, $progress);
        $this->assertSame('welcome_tour', $progress[0]['tour_id']);
        $this->assertTrue($progress[0]['completed']);

        // Reset progress
        GuidanceService::resetTourProgress($user, 'welcome_tour');
        $progressAfterReset = GuidanceService::getTourProgress($user);
        $this->assertEmpty($progressAfterReset);
    }

    public function test_admin_article_crud_and_permissions(): void
    {
        $admin = $this->createAuthContext(1, true, ['guidance.manage']);
        $member = $this->createAuthContext(2, false);

        // Member should be forbidden from admin list
        try {
            GuidanceService::adminList($member);
            $this->fail('Member should not be allowed to list admin guidance');
        } catch (ApiError $e) {
            $this->assertSame(403, $e->status);
        }

        // Admin can create a new guidance article
        $created = GuidanceService::create($admin, [
            'slug' => 'test-guide',
            'category' => 'general',
            'title' => 'Test Guidance Article',
            'summary' => 'Short summary for testing',
            'content' => 'Full test article content here.',
            'target_role' => 'all',
            'status' => 'draft',
        ]);

        $this->assertSame('test-guide', $created['slug']);
        $this->assertSame('draft', $created['status']);

        // Member cannot see draft article
        try {
            GuidanceService::getBySlugOrId($member, 'test-guide');
            $this->fail('Member should not view draft guidance article');
        } catch (ApiError $e) {
            $this->assertSame(404, $e->status);
        }

        // Admin can publish the article
        $published = GuidanceService::publish($admin, $created['id']);
        $this->assertSame('published', $published['status']);

        // Now member CAN see it
        $viewed = GuidanceService::getBySlugOrId($member, 'test-guide');
        $this->assertSame('test-guide', $viewed['slug']);

        // Admin can retire it
        $retired = GuidanceService::retire($admin, $created['id']);
        $this->assertSame('retired', $retired['status']);

        // Admin can delete it
        GuidanceService::delete($admin, $created['id']);
        $this->expectException(ApiError::class);
        GuidanceService::getBySlugOrId($admin, 'test-guide');
    }
}
