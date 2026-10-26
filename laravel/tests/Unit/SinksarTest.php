<?php

namespace Tests\Unit;

use App\Mz\Services\Sinksar;
use App\Mz\Support\EthiopianCalendar;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class SinksarTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();
    }

    private function setUpSchema(): void
    {
        if (!Schema::hasTable('sinksar_daily')) {
            Schema::create('sinksar_daily', function ($table) {
                $table->id();
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
                $table->text('annual_feasts')->nullable();
                $table->text('monthly_feasts')->nullable();
                $table->text('summary')->nullable();
                $table->boolean('full_text_available')->default(false);
                $table->text('raw_payload')->nullable();
                $table->boolean('notification_sent')->default(false)->index();
                $table->timestamp('refreshed_at')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('sinksar_narratives')) {
            Schema::create('sinksar_narratives', function ($table) {
                $table->id();
                $table->integer('ethiopian_month')->index();
                $table->integer('ethiopian_day')->index();
                $table->string('title', 255)->index();
                $table->string('source', 255)->nullable();
                $table->text('summary')->nullable();
                $table->longText('body');
                $table->boolean('verified')->default(false);
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('user_preferences')) {
            Schema::create('user_preferences', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id')->unique();
                $table->boolean('notifications_enabled')->default(true);
                $table->text('notification_topics')->nullable();
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('notifications')) {
            Schema::create('notifications', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('type');
                $table->string('title');
                $table->text('body');
                $table->string('entity_type')->nullable();
                $table->unsignedBigInteger('entity_id')->nullable();
                $table->text('data')->nullable();
                $table->string('channel')->default('default');
                $table->boolean('is_read')->default(false);
                $table->timestamps();
            });
        }

        if (!Schema::hasTable('user_fcm_tokens')) {
            Schema::create('user_fcm_tokens', function ($table) {
                $table->id();
                $table->unsignedBigInteger('user_id');
                $table->string('token', 255)->unique();
                $table->string('platform', 32)->default('android');
                $table->timestamps();
            });
        }
    }

    public function test_ethiopian_calendar_conversion_golden_vectors(): void
    {
        // 1. Ethiopian New Year 2019 E.C. is 2026-09-11 Gregorian
        $newYear = EthiopianCalendar::fromGregorian(2026, 9, 11);
        $this->assertEquals(2019, $newYear['year']);
        $this->assertEquals(1, $newYear['month']);
        $this->assertEquals(1, $newYear['day']);
        $this->assertEquals('መስከረም', $newYear['month_am']);

        // 2. Inverse to Gregorian matches 2026-09-11
        $greg = EthiopianCalendar::toGregorian(2019, 1, 1);
        $this->assertEquals('2026-09-11', $greg->format('Y-m-d'));

        // 3. Tikimt 15, 2019 E.C. is 2026-10-25 Gregorian
        $tikimt15 = EthiopianCalendar::fromGregorian(2026, 10, 25);
        $this->assertEquals(2019, $tikimt15['year']);
        $this->assertEquals(2, $tikimt15['month']);
        $this->assertEquals(15, $tikimt15['day']);
        $this->assertEquals('ጥቅምት', $tikimt15['month_am']);

        $greg2 = EthiopianCalendar::toGregorian(2019, 2, 15);
        $this->assertEquals('2026-10-25', $greg2->format('Y-m-d'));

        // 4. Pagume days in leap year vs normal year
        $this->assertTrue(EthiopianCalendar::isLeapYear(2019));
        $this->assertEquals(6, EthiopianCalendar::daysInMonth(2019, 13));

        $this->assertFalse(EthiopianCalendar::isLeapYear(2020));
        $this->assertEquals(5, EthiopianCalendar::daysInMonth(2020, 13));
    }

    public function test_sinksar_for_today_caches_and_distinguishes_commemorations(): void
    {
        Http::fake([
            'https://eotcdev-api.natinael-96.workers.dev/v1/sinksar/*' => Http::response([
                'date' => [
                    'gregorian' => '2026-10-25',
                    'ethiopic' => '2019-02-15',
                ],
                'annualFeasts' => [
                    'heading' => 'ጥቅምት ፲፭ ቀን የሚከበሩ ዓመታዊ የቅዱሳን በዓላት',
                    'items' => [
                        ['id' => '1', 'title' => '፲፪ቱ ቅዱሳን ሐዋርያት', 'sourceText' => '፩.፲፪ቱ ቅዱሳን ሐዋርያት'],
                        ['id' => '2', 'title' => 'ቅዱስ ቢላሞን ሰማዕት', 'sourceText' => '፪.ቅዱስ ቢላሞን ሰማዕት'],
                    ],
                ],
                'monthlyFeasts' => [
                    'heading' => 'ወርኀዊ በዓላት',
                    'items' => [
                        ['id' => 'm1', 'title' => 'ቅዱስ ቂርቆስና እናቱ ኢየሉጣ', 'sourceText' => '፩.ቅዱስ ቂርቆስና እናቱ ኢየሉጣ'],
                    ],
                ],
                'fullTextAvailable' => false,
                'fasting' => [
                    'isFasting' => false,
                    'reason' => 'Not a fasting day',
                ],
            ], 200),
        ]);

        $data = Sinksar::forDate('2026-10-25');

        $this->assertEquals('2026-10-25', $data['gregorian_date']);
        $this->assertEquals('2019-02-15', $data['ethiopian_date']);
        $this->assertEquals('ጥቅምት', $data['month_name_am']);
        $this->assertEquals(15, $data['ethiopian_day']);
        $this->assertEquals('፲፪ቱ ቅዱሳን ሐዋርያት', $data['featured_title']);
        $this->assertCount(2, $data['annual_feasts']);
        $this->assertCount(1, $data['monthly_feasts']);
        $this->assertFalse($data['has_narratives']);

        $this->assertDatabaseHas('sinksar_daily', [
            'gregorian_date' => '2026-10-25',
            'ethiopian_date' => '2019-02-15',
        ]);
    }

    public function test_sinksar_offline_fallback_when_upstream_unreachable(): void
    {
        Http::fake([
            'https://eotcdev-api.natinael-96.workers.dev/v1/sinksar/*' => Http::response(null, 500),
        ]);

        $data = Sinksar::forDate('2026-10-25');

        $this->assertEquals('2026-10-25', $data['gregorian_date']);
        $this->assertEquals('2019-02-15', $data['ethiopian_date']);
        $this->assertNotEmpty($data['monthly_feasts']);
        $this->assertEquals('ቅዱስ ቂርቆስና እናቱ ኢየሉጣ', $data['monthly_feasts'][0]['title']);
        $this->assertNotEmpty($data['featured_title']);
    }

    public function test_sinksar_narratives_linking(): void
    {
        DB::table('sinksar_narratives')->insert([
            'ethiopian_month' => 2,
            'ethiopian_day' => 15,
            'title' => 'ገድለ ቅዱስ ቢላሞን ሰማዕት',
            'source' => 'መጽሐፈ ስንክሳር ዘጥቅምት',
            'summary' => 'ስለ ቅዱስ ቢላሞን ሰማዕትነት የተጻፈ ታሪክ',
            'body' => 'በስመ አብ ወወልድ ወመንፈስ ቅዱስ አሐዱ አምላክ አመ ፲ወ፭ ለጥቅምት በዛቲ ዕለት ተዝካረ ሰማዕትነቱ ለቅዱስ ቢላሞን...',
            'verified' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $data = Sinksar::forDate('2026-10-25');
        $this->assertTrue($data['has_narratives']);
        $this->assertCount(1, $data['narratives']);
        $this->assertEquals('ገድለ ቅዱስ ቢላሞን ሰማዕት', $data['narratives'][0]['title']);
    }

    public function test_send_test_notification_to_caller_only(): void
    {
        $adminId = DB::table('users')->insertGetId([
            'full_name' => 'Admin Tester',
            'phone' => '+251911000001',
            'status' => 'active',
        ]);
        $otherId = DB::table('users')->insertGetId([
            'full_name' => 'Other Member',
            'phone' => '+251911000002',
            'status' => 'active',
        ]);

        // Register token for admin and other user
        DB::table('user_fcm_tokens')->insert([
            ['user_id' => $adminId, 'token' => 'fcm-token-admin-1', 'platform' => 'android', 'created_at' => now(), 'updated_at' => now()],
            ['user_id' => $otherId, 'token' => 'fcm-token-other-2', 'platform' => 'android', 'created_at' => now(), 'updated_at' => now()],
        ]);

        $auth = new \App\Mz\Auth\AuthContext();
        $auth->id = $adminId;
        $auth->fullName = 'Admin Tester';
        $auth->status = 'active';
        $auth->accountType = 'admin';
        $auth->isAdmin = true;
        $auth->isSystem = false;
        $auth->role = ['id' => 2, 'slug' => 'high_admin', 'name' => 'ከፍተኛ አስተዳዳሪ', 'level' => 50];

        $res = Sinksar::sendTestNotification($auth, '2026-10-25');

        $this->assertEquals('submitted', $res['status']);
        $this->assertEquals($adminId, $res['recipient_user_id']);
        $this->assertEquals(1, $res['devices_targeted']);
        $this->assertEquals('sinksar', $res['channel']);

        // Verify only admin received the in-app notification record
        $this->assertEquals(1, DB::table('notifications')->where('user_id', $adminId)->count());
        $this->assertEquals(0, DB::table('notifications')->where('user_id', $otherId)->count());
    }
}

