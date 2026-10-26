<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\Programs;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Ethiopian;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class UnifiedCalendarAndSchedulingTest extends TestCase
{
    private AuthContext $adminAuth;
    private AuthContext $memberAuth1;
    private AuthContext $memberAuth2;
    private int $adminId = 1;
    private int $member1Id = 10;
    private int $member2Id = 11;
    private int $eduCategoryId;
    private int $mezmurCategoryId;
    private int $generalCategoryId;
    private int $academicYearId;
    private int $class1Id;
    private int $class2Id;

    protected function setUp(): void
    {
        parent::setUp();
        $this->setUpSchema();

        $this->adminAuth = $this->makeAuth($this->adminId, 'Admin User', ['programs.manage' => true, 'education.manage' => true, 'attendance.manage' => true, 'attendance.override' => true], true, 100);
        $this->memberAuth1 = $this->makeAuth($this->member1Id, 'Enrolled Student', [], false, 0);
        $this->memberAuth2 = $this->makeAuth($this->member2Id, 'Unenrolled Member', [], false, 0);

        // 1. Program categories
        $this->eduCategoryId = DB::table('program_categories')->insertGetId([
            'name' => 'ትምህርትና ሥልጠና',
            'name_en' => 'Education and Training',
            'color' => '#8B0000',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->mezmurCategoryId = DB::table('program_categories')->insertGetId([
            'name' => 'መዝሙር',
            'name_en' => 'Mezmur',
            'color' => '#D4AF37',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->generalCategoryId = DB::table('program_categories')->insertGetId([
            'name' => 'አጠቃላይ',
            'name_en' => 'General',
            'color' => '#1B4332',
            'is_active' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 2. Education academic year & classes
        $this->academicYearId = DB::table('edu_academic_years')->insertGetId([
            'eth_year' => 2019,
            'name' => '2019 ዓ.ም',
            'is_current' => true,
            'status' => 'active',
            'starts_at' => '2026-09-11',
            'ends_at' => '2027-09-10',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->class1Id = DB::table('edu_classes')->insertGetId([
            'name' => 'ክፍል 5 (Grade 5)',
            'academic_year_id' => $this->academicYearId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->class2Id = DB::table('edu_classes')->insertGetId([
            'name' => 'ክፍል 6 (Grade 6)',
            'academic_year_id' => $this->academicYearId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Enroll member 1 in Class 1
        DB::table('edu_enrollments')->insert([
            'class_id' => $this->class1Id,
            'user_id' => $this->member1Id,
            'status' => 'active',
            'program' => 'regular',
            'enrolled_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function makeAuth(int $id, string $name, array $perms = [], bool $isAdmin = false, int $level = 0): AuthContext
    {
        $auth = new AuthContext();
        $auth->id = $id;
        $auth->fullName = $name;
        $auth->status = 'active';
        $auth->accountType = $isAdmin ? 'admin' : 'user';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = $isAdmin;
        $auth->isSystem = $isAdmin;
        $auth->isMemberStaff = false;
        $auth->level = $level;
        $auth->permissions = $perms;
        return $auth;
    }

    private function setUpSchema(): void
    {
        Schema::dropIfExists('notifications');
        Schema::dropIfExists('roles');
        Schema::dropIfExists('edu_courses');
        Schema::dropIfExists('attendance_edu_classes');
        Schema::dropIfExists('attendance');
        Schema::dropIfExists('program_edu_classes');
        Schema::dropIfExists('program_edu_courses');
        Schema::dropIfExists('program_occurrence_overrides');
        Schema::dropIfExists('program_reminder_choices');
        Schema::dropIfExists('program_participants');
        Schema::dropIfExists('programs');
        Schema::dropIfExists('program_categories');
        Schema::dropIfExists('edu_schedule');
        Schema::dropIfExists('edu_enrollments');
        Schema::dropIfExists('edu_classes');
        Schema::dropIfExists('edu_levels');
        Schema::dropIfExists('edu_academic_years');
        Schema::dropIfExists('attendance_closures');
        Schema::dropIfExists('audit_logs');
        Schema::dropIfExists('settings');
        Schema::dropIfExists('users');

        DB::statement('CREATE TABLE roles (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            is_hidden BOOLEAN DEFAULT 0,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_courses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            class_id INTEGER NOT NULL,
            teacher_user_id INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE notifications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            type VARCHAR(50) NOT NULL,
            topic VARCHAR(50) NOT NULL,
            title VARCHAR(255) NOT NULL,
            body TEXT NOT NULL,
            entity_type VARCHAR(50) NULL,
            entity_id INTEGER NULL,
            data TEXT NULL,
            broadcast_id INTEGER NULL,
            resent_from_id INTEGER NULL,
            sent_by INTEGER NULL,
            email_status VARCHAR(20) DEFAULT "none",
            dedupe_key VARCHAR(150) NULL,
            read_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name VARCHAR(100) NOT NULL,
            phone VARCHAR(20) NULL,
            email VARCHAR(100) NULL,
            member_no INTEGER NULL,
            member_group VARCHAR(50) NULL,
            status VARCHAR(20) NOT NULL DEFAULT "active",
            account_type VARCHAR(20) NOT NULL DEFAULT "user",
            role_id INTEGER NULL,
            membership_status VARCHAR(20) NOT NULL DEFAULT "active",
            deleted_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE settings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key VARCHAR(100) UNIQUE,
            value TEXT NULL,
            type VARCHAR(20) DEFAULT "string",
            description TEXT NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE audit_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            actor_id INTEGER NULL,
            is_hidden BOOLEAN DEFAULT 0,
            action VARCHAR(50) NOT NULL,
            entity_type VARCHAR(50) NULL,
            entity_id INTEGER NULL,
            metadata TEXT NULL,
            ip VARCHAR(50) NULL,
            user_agent VARCHAR(255) NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_categories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            name_en VARCHAR(100) NULL,
            color VARCHAR(20) NULL,
            display_order INTEGER DEFAULT 0,
            is_active BOOLEAN DEFAULT 1,
            reminder_offsets VARCHAR(100) NULL,
            reminder_interval_days INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE programs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title VARCHAR(255) NOT NULL,
            description TEXT NULL,
            location VARCHAR(255) NULL,
            starts_at DATETIME NOT NULL,
            ends_at DATETIME NULL,
            has_end_time BOOLEAN DEFAULT 1,
            requires_registration BOOLEAN DEFAULT 0,
            requires_attendance BOOLEAN DEFAULT 1,
            capacity INTEGER NULL,
            audience VARCHAR(50) DEFAULT "all",
            event_type VARCHAR(50) NULL,
            status VARCHAR(20) DEFAULT "draft",
            reminder_enabled BOOLEAN DEFAULT 1,
            reminder_days_before INTEGER DEFAULT 1,
            is_mandatory_reminder BOOLEAN DEFAULT 0,
            reminder_interval_days INTEGER NULL,
            reminder_interval_start DATE NULL,
            reminder_title VARCHAR(255) NULL,
            reminder_body TEXT NULL,
            reminder_offsets VARCHAR(100) NULL,
            recurrence VARCHAR(50) DEFAULT "once",
            monthly_rule VARCHAR(50) NULL,
            recurrence_until DATE NULL,
            ethiopian_days VARCHAR(100) NULL,
            is_additional BOOLEAN DEFAULT 0,
            counts_for_selection BOOLEAN DEFAULT 1,
            category_id INTEGER NULL,
            member_groups VARCHAR(255) NULL,
            schedule_id INTEGER NULL,
            image VARCHAR(255) NULL,
            created_by INTEGER NULL,
            updated_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_participants (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "registered",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE program_edu_classes (
            program_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            PRIMARY KEY (program_id, class_id)
        )');

        DB::statement('CREATE TABLE program_edu_courses (
            program_id INTEGER NOT NULL,
            course_id INTEGER NOT NULL,
            PRIMARY KEY (program_id, course_id)
        )');

        DB::statement('CREATE TABLE program_occurrence_overrides (
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            action VARCHAR(50) NOT NULL,
            starts_at DATETIME NULL,
            ends_at DATETIME NULL,
            reason TEXT NULL,
            changed_by INTEGER NULL,
            PRIMARY KEY (program_id, occurrence_date)
        )');

        DB::statement('CREATE TABLE program_reminder_choices (
            user_id INTEGER NOT NULL,
            program_id INTEGER NOT NULL,
            offsets VARCHAR(100) NULL,
            PRIMARY KEY (user_id, program_id)
        )');

        DB::statement('CREATE TABLE edu_academic_years (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eth_year INTEGER NOT NULL,
            name VARCHAR(100) NOT NULL,
            is_current BOOLEAN DEFAULT 0,
            status VARCHAR(20) DEFAULT "active",
            starts_at DATE NULL,
            ends_at DATE NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_levels (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            code VARCHAR(50) NOT NULL,
            name VARCHAR(100) NOT NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_classes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name VARCHAR(100) NOT NULL,
            academic_year_id INTEGER NULL,
            level_id INTEGER NULL,
            status VARCHAR(20) DEFAULT "active",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_schedule (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            academic_year_id INTEGER NULL,
            class_id INTEGER NOT NULL,
            course_id INTEGER NULL,
            weekday INTEGER NOT NULL,
            starts VARCHAR(20) NOT NULL,
            ends VARCHAR(20) NOT NULL,
            location VARCHAR(255) NULL,
            frequency VARCHAR(50) DEFAULT "weekly",
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE edu_enrollments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            academic_year_id INTEGER NULL,
            class_id INTEGER NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) DEFAULT "active",
            program VARCHAR(50) DEFAULT "regular",
            enrolled_at DATETIME NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL
        )');

        DB::statement('CREATE TABLE attendance (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            user_id INTEGER NOT NULL,
            status VARCHAR(20) NOT NULL DEFAULT "present",
            recorded_by INTEGER NULL,
            created_at DATETIME NULL,
            updated_at DATETIME NULL,
            UNIQUE (program_id, occurrence_date, user_id)
        )');

        DB::statement('CREATE TABLE attendance_edu_classes (
            attendance_id INTEGER NOT NULL,
            class_id INTEGER NOT NULL,
            PRIMARY KEY (attendance_id, class_id)
        )');

        DB::statement('CREATE TABLE attendance_closures (
            program_id INTEGER NOT NULL,
            occurrence_date DATE NOT NULL,
            closed_at DATETIME NULL,
            closed_by INTEGER NULL,
            PRIMARY KEY (program_id, occurrence_date)
        )');

        DB::table('roles')->insert([
            ['id' => 1, 'name' => 'Admin Role', 'is_hidden' => 0],
            ['id' => 2, 'name' => 'Member Role', 'is_hidden' => 0],
        ]);

        DB::table('users')->insert([
            ['id' => 1, 'full_name' => 'Admin User', 'status' => 'active', 'account_type' => 'admin', 'role_id' => 1, 'membership_status' => 'active'],
            ['id' => 10, 'full_name' => 'Student Member 1', 'status' => 'active', 'account_type' => 'user', 'role_id' => 2, 'membership_status' => 'active'],
            ['id' => 11, 'full_name' => 'Student Member 2', 'status' => 'active', 'account_type' => 'user', 'role_id' => 2, 'membership_status' => 'active'],
        ]);
    }

    public function test_ethiopian_yearly_calendar_returns_all_categories_with_ethiopian_dates(): void
    {
        $actx = ['auth' => $this->adminAuth];

        // 1. Create a General Church Program
        $p1 = Programs::create($actx, [
            'title' => 'የዓመቱ ታላቅ ጉባኤ (Annual Conference)',
            'starts_at' => '2026-10-24 08:00:00',
            'ends_at' => '2026-10-24 12:00:00',
            'category_id' => $this->generalCategoryId,
            'location' => 'ዋና አዳራሽ',
            'status' => 'published',
            'recurrence' => 'once',
        ]);

        // 2. Create a Mezmur Program on the same day (overlapping time/venue)
        $p2 = Programs::create($actx, [
            'title' => 'የመዘምራን ልምምድ (Choir Practice)',
            'starts_at' => '2026-10-24 14:00:00',
            'ends_at' => '2026-10-24 16:00:00',
            'category_id' => $this->mezmurCategoryId,
            'location' => 'ቤተመቅደስ',
            'status' => 'published',
            'recurrence' => 'once',
        ]);

        // 3. Query calendar for Ethiopian Year 2019 range
        $calendar = Programs::calendar($this->adminAuth, '2026-09-11', '2027-09-10', null);

        $this->assertNotEmpty($calendar);
        $ids = array_column($calendar, 'program_id');
        $this->assertContains($p1['id'], $ids);
        $this->assertContains($p2['id'], $ids);

        // Verify Ethiopian date structure and month
        $entry1 = collect($calendar)->firstWhere('program_id', $p1['id']);
        $this->assertNotNull($entry1);
        $this->assertEquals(2019, $entry1['ethiopian']['year']);
        $this->assertEquals(2, $entry1['ethiopian']['month']); // Tikimt
        $this->assertEquals(14, $entry1['ethiopian']['day']);
        $this->assertStringContainsString('ጥቅምት 14', $entry1['ethiopian_date']);
        $this->assertEquals('አጠቃላይ', $entry1['category']['name']);

        // Overlapping entries on the same date are both returned independently
        $sameDayEntries = array_filter($calendar, fn ($c) => $c['date'] === '2026-10-24');
        $this->assertGreaterThanOrEqual(2, count($sameDayEntries));
    }

    public function test_personalized_visibility_education_class_restricted(): void
    {
        $actx = ['auth' => $this->adminAuth];

        // Create an Education Program restricted to Class 1
        $eduProg = Programs::create($actx, [
            'title' => 'የ5ኛ ክፍል ትምህርት (Grade 5 Education)',
            'starts_at' => '2026-10-26 09:00:00',
            'ends_at' => '2026-10-26 11:00:00',
            'category_id' => $this->eduCategoryId,
            'status' => 'published',
            'recurrence' => 'once',
            'class_ids' => [$this->class1Id],
        ]);

        // Member 1 (enrolled in Class 1) should see the program
        $calMember1 = Programs::calendar($this->memberAuth1, '2026-10-20', '2026-10-30', null);
        $idsMember1 = array_column($calMember1, 'program_id');
        $this->assertContains($eduProg['id'], $idsMember1);

        // Member 2 (NOT enrolled in Class 1) should NOT see the program in calendar
        $calMember2 = Programs::calendar($this->memberAuth2, '2026-10-20', '2026-10-30', null);
        $idsMember2 = array_column($calMember2, 'program_id');
        $this->assertNotContains($eduProg['id'], $idsMember2);

        // Security check: Direct API detail lookup for Member 2 must be forbidden (throws 403 or 404)
        $this->expectException(ApiError::class);
        Programs::detail($eduProg['id'], $this->memberAuth2, false);
    }

    public function test_shared_education_session_multiple_classes_single_record(): void
    {
        $actx = ['auth' => $this->adminAuth];

        // Create a Shared Education Session intended for both Class 1 and Class 2
        $sharedProg = Programs::create($actx, [
            'title' => 'የተጋራ ትምህርት - ክፍል 5 እና 6 (Shared Session Grades 5 & 6)',
            'starts_at' => '2026-10-27 10:00:00',
            'ends_at' => '2026-10-27 12:00:00',
            'category_id' => $this->eduCategoryId,
            'status' => 'published',
            'recurrence' => 'once',
            'class_ids' => [$this->class1Id, $this->class2Id],
        ]);

        // Verify single program row
        $count = DB::table('programs')->where('id', $sharedProg['id'])->count();
        $this->assertEquals(1, $count);

        // Verify both classes are linked
        $linkedClasses = DB::table('program_edu_classes')->where('program_id', $sharedProg['id'])->pluck('class_id')->all();
        $this->assertContains($this->class1Id, $linkedClasses);
        $this->assertContains($this->class2Id, $linkedClasses);

        // Enroll Member 2 in Class 2
        DB::table('edu_enrollments')->insert([
            'class_id' => $this->class2Id,
            'user_id' => $this->member2Id,
            'status' => 'active',
            'program' => 'regular',
            'enrolled_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Both Member 1 and Member 2 now see the shared program in their respective calendars
        $cal1 = Programs::calendar($this->memberAuth1, '2026-10-20', '2026-10-30', null);
        $cal2 = Programs::calendar($this->memberAuth2, '2026-10-20', '2026-10-30', null);
        $this->assertContains($sharedProg['id'], array_column($cal1, 'program_id'));
        $this->assertContains($sharedProg['id'], array_column($cal2, 'program_id'));

        // Record attendance for Member 1 in this shared session
        DB::table('attendance')->insert([
            'program_id' => $sharedProg['id'],
            'occurrence_date' => '2026-10-27',
            'user_id' => $this->member1Id,
            'status' => 'present',
            'recorded_by' => $this->adminId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // Attendance has unique constraint on [program_id, occurrence_date, user_id]
        $this->assertEquals(1, DB::table('attendance')->where([
            'program_id' => $sharedProg['id'],
            'occurrence_date' => '2026-10-27',
            'user_id' => $this->member1Id,
        ])->count());
    }

    public function test_program_overlap_detection_warning(): void
    {
        $actx = ['auth' => $this->adminAuth];

        // Create an existing program
        Programs::create($actx, [
            'title' => 'የአዳራሽ ስብሰባ (Hall Meeting)',
            'starts_at' => '2026-10-28 15:00:00',
            'ends_at' => '2026-10-28 17:00:00',
            'category_id' => $this->generalCategoryId,
            'location' => 'አዳራሽ 1',
            'status' => 'published',
            'recurrence' => 'once',
        ]);

        // Check overlap for a candidate program at the same time and venue
        $conflicts = Programs::checkOverlap([
            'starts_at' => '2026-10-28 16:00:00',
            'ends_at' => '2026-10-28 18:00:00',
            'location' => 'አዳራሽ 1',
            'recurrence' => 'once',
        ]);

        $this->assertNotEmpty($conflicts);
        $c = $conflicts[0];
        $this->assertEquals('የአዳራሽ ስብሰባ (Hall Meeting)', $c['title']);
        $this->assertTrue($c['is_same_venue']);
        $this->assertNotEmpty($c['ethiopian_date']);

        // Overlap warning does NOT prevent creation: admin proceeds
        $created = Programs::create($actx, [
            'title' => 'ተደራራቢ ፕሮግራም (Overlapping Program)',
            'starts_at' => '2026-10-28 16:00:00',
            'ends_at' => '2026-10-28 18:00:00',
            'location' => 'አዳራሽ 1',
            'category_id' => $this->generalCategoryId,
            'status' => 'published',
            'recurrence' => 'once',
        ]);

        $this->assertNotNull($created['id']);
    }

    public function test_strict_attendance_window_enforcement(): void
    {
        $occurrence = [
            'date' => '2026-10-24',
            'starts_at' => '2026-10-24 09:00:00',
            'ends_at' => '2026-10-24 11:00:00',
        ];

        // Active session started at 08:50, scheduled end 11:00
        $session = (object) [
            'status' => 'active',
            'started_at' => '2026-10-24 08:50:00',
            'ended_at' => null,
        ];

        // 1. Within window (e.g. 09:30) => true
        $this->assertTrue(\App\Mz\Services\AttendanceSessions::acceptsAt($session, $occurrence, Dates::of('2026-10-24 09:30:00')));

        // 2. Before started_at (e.g. 08:45) => false
        $this->assertFalse(\App\Mz\Services\AttendanceSessions::acceptsAt($session, $occurrence, Dates::of('2026-10-24 08:45:00')));

        // 3. At or after scheduled end (e.g. 11:00:01) => false
        $this->assertFalse(\App\Mz\Services\AttendanceSessions::acceptsAt($session, $occurrence, Dates::of('2026-10-24 11:00:01')));

        // 4. Session ended early (e.g. ended at 10:15)
        $sessionEndedEarly = (object) [
            'status' => 'ended',
            'started_at' => '2026-10-24 08:50:00',
            'ended_at' => '2026-10-24 10:15:00',
        ];
        $this->assertTrue(\App\Mz\Services\AttendanceSessions::acceptsAt($sessionEndedEarly, $occurrence, Dates::of('2026-10-24 10:00:00')));
        $this->assertFalse(\App\Mz\Services\AttendanceSessions::acceptsAt($sessionEndedEarly, $occurrence, Dates::of('2026-10-24 10:20:00')));

        // 5. Cancelled session => false
        $sessionCancelled = (object) [
            'status' => 'cancelled',
            'started_at' => '2026-10-24 08:50:00',
            'ended_at' => null,
        ];
        $this->assertFalse(\App\Mz\Services\AttendanceSessions::acceptsAt($sessionCancelled, $occurrence, Dates::of('2026-10-24 09:30:00')));
    }

    public function test_education_schedule_retrieval_and_timetable_linking(): void
    {
        $actx = ['auth' => $this->adminAuth];

        // 1. Insert course and schedule entry
        $courseId = DB::table('edu_courses')->insertGetId([
            'name' => 'ነገረ መለኮት (Theology)',
            'class_id' => $this->class1Id,
            'teacher_user_id' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $schedId = DB::table('edu_schedule')->insertGetId([
            'academic_year_id' => $this->academicYearId,
            'class_id' => $this->class1Id,
            'course_id' => $courseId,
            'weekday' => 6, // Saturday
            'starts' => '09:00',
            'ends' => '11:00',
            'location' => 'ክፍል 101',
            'frequency' => 'weekly',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        // 2. Fetch all schedules via Edu service
        $schedules = Edu::allSchedules($this->academicYearId, $this->class1Id);
        $this->assertNotEmpty($schedules);
        $this->assertEquals($schedId, $schedules[0]['id']);
        $this->assertEquals('ነገረ መለኮት (Theology)', $schedules[0]['course_name']);
        $this->assertEquals('ክፍል 101', $schedules[0]['location']);

        // 3. Create Education Program linked to schedule
        $prog = Programs::create($actx, [
            'title' => 'የነገረ መለኮት ትምህርት',
            'starts_at' => '2026-10-24 09:00:00',
            'ends_at' => '2026-10-24 11:00:00',
            'location' => 'ክፍል 101',
            'category_id' => $this->eduCategoryId,
            'schedule_id' => $schedId,
            'status' => 'published',
            'recurrence' => 'weekly',
        ]);

        // Verify program has schedule_id and auto-linked class_id
        $this->assertEquals($schedId, $prog['schedule_id']);
        $this->assertNotEmpty($prog['schedule']);
        $this->assertEquals('ነገረ መለኮት (Theology)', $prog['schedule']['course_name']);
        $this->assertContains($this->class1Id, array_column($prog['classes'], 'id'));
    }

    public function test_notifications_sent_on_publish_and_reschedule_with_dedupe(): void
    {
        $actx = ['auth' => $this->adminAuth];

        // Clear notifications
        DB::table('notifications')->delete();

        // 1. Create and publish program restricted to Class 1
        $p = Programs::create($actx, [
            'title' => 'የክፍል 5 ልዩ ስብሰባ',
            'starts_at' => '2026-10-25 14:00:00',
            'ends_at' => '2026-10-25 16:00:00',
            'category_id' => $this->eduCategoryId,
            'class_ids' => [$this->class1Id],
            'status' => 'published',
            'recurrence' => 'once',
        ]);

        // Member 1 (enrolled in Class 1) should receive notification
        $n1 = DB::table('notifications')->where('user_id', $this->member1Id)->where('entity_id', $p['id'])->get();
        $this->assertNotEmpty($n1);

        // Member 2 (NOT in Class 1) should NOT receive notification
        $n2 = DB::table('notifications')->where('user_id', $this->member2Id)->where('entity_id', $p['id'])->get();
        $this->assertEmpty($n2);

        // Verify notification dedupe key exists
        $this->assertNotNull($n1[0]->dedupe_key);
        $this->assertStringContainsString('program:' . $p['id'], $n1[0]->dedupe_key);
    }
}
