<?php

namespace Tests\Unit;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Edu;
use App\Mz\Services\EduAcademicYears;
use App\Mz\Services\EduRegistration;
use App\Mz\Services\MemberGroups;
use App\Mz\Support\ApiError;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class EduAcademicStructureTest extends TestCase
{
    private array $actx;

    protected function setUp(): void
    {
        parent::setUp();

        $this->setUpSchema();
        MemberGroups::forget();

        $auth = new AuthContext();
        $auth->id = 1;
        $auth->fullName = 'Admin User';
        $auth->status = 'active';
        $auth->accountType = 'admin';
        $auth->tokenVersion = 1;
        $auth->mustChangePassword = false;
        $auth->isAdmin = true;
        $auth->isSystem = true;
        $auth->isMemberStaff = false;
        $auth->level = 100;
        $auth->permissions = ['education.manage' => true, 'education.register' => true];
        $this->actx = ['auth' => $auth];
    }

    private function setUpSchema(): void
    {
        if (! Schema::hasTable('member_groups')) {
            Schema::create('member_groups', function ($table) {
                $table->id();
                $table->string('key')->unique();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->text('description')->nullable();
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('built_in')->default(false);
                $table->timestamps();
            });
            DB::table('member_groups')->insert([
                ['key' => 'youth_adult', 'name' => 'ወጣት እና አዋቂ', 'name_en' => 'Youth and Adult', 'sort_order' => 1, 'is_active' => 1, 'built_in' => 1],
                ['key' => 'children', 'name' => 'ሕፃናት', 'name_en' => 'Children', 'sort_order' => 2, 'is_active' => 1, 'built_in' => 1],
            ]);
        }

        if (! Schema::hasTable('roles')) {
            Schema::create('roles', function ($table) {
                $table->id();
                $table->string('slug')->unique();
                $table->string('name');
                $table->integer('level')->default(0);
                $table->boolean('is_hidden')->default(false);
                $table->boolean('is_active')->default(true);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('users')) {
            Schema::create('users', function ($table) {
                $table->id();
                $table->string('full_name');
                $table->string('phone')->nullable();
                $table->string('member_no')->nullable();
                $table->string('member_group')->default('youth_adult');
                $table->unsignedInteger('role_id')->nullable();
                $table->string('status')->default('active');
                $table->string('account_type')->default('user');
                $table->softDeletes();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_academic_years')) {
            Schema::create('edu_academic_years', function ($table) {
                $table->id();
                $table->integer('eth_year')->unique();
                $table->string('name');
                $table->date('starts_on')->nullable();
                $table->date('ends_on')->nullable();
                $table->string('status')->default('planned');
                $table->boolean('is_current')->default(false);
                $table->unsignedInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_terms')) {
            Schema::create('edu_terms', function ($table) {
                $table->id();
                $table->unsignedInteger('academic_year_id');
                $table->string('name');
                $table->integer('sort_order')->default(0);
                $table->date('starts_on')->nullable();
                $table->date('ends_on')->nullable();
                $table->string('status')->default('planned');
                $table->timestamps();
                $table->unique(['academic_year_id', 'name']);
            });
        }

        if (! Schema::hasTable('edu_levels')) {
            Schema::create('edu_levels', function ($table) {
                $table->id();
                $table->string('code')->unique();
                $table->string('name');
                $table->string('name_en')->nullable();
                $table->string('kind')->default('grade');
                $table->integer('sort_order')->default(0);
                $table->boolean('is_active')->default(true);
                $table->boolean('built_in')->default(false);
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_classes')) {
            Schema::create('edu_classes', function ($table) {
                $table->id();
                $table->string('name');
                $table->text('description')->nullable();
                $table->string('term')->nullable();
                $table->string('academic_year')->nullable();
                $table->string('semester')->nullable();
                $table->unsignedInteger('department_id')->nullable();
                $table->unsignedInteger('academic_year_id')->nullable();
                $table->unsignedInteger('term_id')->nullable();
                $table->unsignedInteger('level_id')->nullable();
                $table->boolean('allow_multiple')->default(false);
                $table->string('streams')->nullable();
                $table->dateTime('registration_opens_at')->nullable();
                $table->dateTime('registration_closes_at')->nullable();
                $table->boolean('allow_regular')->default(true);
                $table->boolean('allow_distance')->default(true);
                $table->integer('capacity')->nullable();
                $table->string('status')->default('active');
                $table->unsignedInteger('created_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_courses')) {
            Schema::create('edu_courses', function ($table) {
                $table->id();
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('subject_id')->nullable();
                $table->unsignedInteger('term_id')->nullable();
                $table->string('name');
                $table->string('code')->nullable();
                $table->text('description')->nullable();
                $table->unsignedInteger('teacher_user_id')->nullable();
                $table->string('member_groups')->nullable();
                $table->string('mode')->default('physical');
                $table->decimal('pass_mark', 5, 2)->default(50.00);
                $table->string('status')->default('active');
                $table->integer('progress')->default(0);
                $table->date('completed_at')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_enrollments')) {
            Schema::create('edu_enrollments', function ($table) {
                $table->id();
                $table->unsignedInteger('class_id');
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('academic_year_id')->nullable();
                $table->string('program')->default('regular');
                $table->string('stream')->nullable();
                $table->boolean('exclusive')->default(true);
                $table->string('status')->default('active');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_course_enrollments')) {
            Schema::create('edu_course_enrollments', function ($table) {
                $table->id();
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('course_id');
                $table->string('status');
                $table->unsignedInteger('changed_by')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_assessments')) {
            Schema::create('edu_assessments', function ($table) {
                $table->id();
                $table->unsignedInteger('course_id');
                $table->string('title');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_scores')) {
            Schema::create('edu_scores', function ($table) {
                $table->id();
                $table->unsignedInteger('assessment_id');
                $table->unsignedInteger('user_id');
                $table->decimal('score', 8, 2)->nullable();
                $table->string('status')->default('draft');
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('edu_journey')) {
            Schema::create('edu_journey', function ($table) {
                $table->id();
                $table->unsignedInteger('user_id');
                $table->string('event');
                $table->unsignedInteger('class_id')->nullable();
                $table->unsignedInteger('course_id')->nullable();
                $table->unsignedInteger('assessment_id')->nullable();
                $table->string('ref_type')->nullable();
                $table->unsignedInteger('ref_id')->nullable();
                $table->string('old_value')->nullable();
                $table->string('new_value')->nullable();
                $table->unsignedInteger('actor_id')->nullable();
                $table->text('reason')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('programs')) {
            Schema::create('programs', function ($table) {
                $table->id();
                $table->string('title');
                $table->string('program_type')->default('regular');
                $table->string('schedule')->nullable();
                $table->string('recurrence')->nullable();
                $table->timestamps();
            });
        }

        if (! Schema::hasTable('program_edu_courses')) {
            Schema::create('program_edu_courses', function ($table) {
                $table->unsignedInteger('program_id');
                $table->unsignedInteger('course_id');
                $table->timestamps();
                $table->primary(['program_id', 'course_id']);
            });
        }

        if (! Schema::hasTable('audit_logs')) {
            Schema::create('audit_logs', function ($table) {
                $table->id();
                $table->unsignedInteger('actor_id')->nullable();
                $table->boolean('is_hidden')->default(false);
                $table->string('action');
                $table->string('entity_type')->nullable();
                $table->unsignedInteger('entity_id')->nullable();
                $table->text('metadata')->nullable();
                $table->string('ip')->nullable();
                $table->string('user_agent')->nullable();
                $table->timestamps();
            });
        }

        DB::table('audit_logs')->delete();

        DB::table('edu_academic_years')->delete();
        DB::table('edu_terms')->delete();
        DB::table('edu_levels')->delete();
        DB::table('edu_classes')->delete();
        DB::table('edu_courses')->delete();
        DB::table('edu_enrollments')->delete();
        DB::table('edu_course_enrollments')->delete();
        DB::table('edu_assessments')->delete();
        DB::table('edu_scores')->delete();
        DB::table('edu_journey')->delete();
        DB::table('users')->delete();
        DB::table('programs')->delete();
        DB::table('program_edu_courses')->delete();
    }

    public function test_academic_year_crud_and_single_current(): void
    {
        $year1 = EduAcademicYears::createYear($this->actx, [
            'eth_year' => 2019,
            'name' => '2019 ዓ.ም',
            'starts_on' => '2026-09-11',
            'ends_on' => '2027-09-10',
            'status' => 'active',
            'is_current' => true,
        ]);

        $this->assertSame(2019, $year1['eth_year']);
        $this->assertTrue($year1['is_current']);

        $year2 = EduAcademicYears::createYear($this->actx, [
            'eth_year' => 2020,
            'name' => '2020 ዓ.ም',
            'starts_on' => '2027-09-11',
            'ends_on' => '2028-09-10',
            'status' => 'planned',
            'is_current' => true,
        ]);

        $this->assertTrue($year2['is_current']);
        // Year 1 is no longer current
        $freshYear1 = EduAcademicYears::getYear($year1['id']);
        $this->assertFalse($freshYear1['is_current']);

        // Switch back via setCurrent
        EduAcademicYears::setCurrent($this->actx, $year1['id']);
        $this->assertTrue(EduAcademicYears::getYear($year1['id'])['is_current']);
        $this->assertFalse(EduAcademicYears::getYear($year2['id'])['is_current']);
    }

    public function test_duplicate_academic_year_eth_year_rejected(): void
    {
        EduAcademicYears::createYear($this->actx, [
            'eth_year' => 2019,
            'name' => '2019 ዓ.ም',
        ]);

        $this->expectException(ApiError::class);
        $this->expectExceptionMessage('Academic year already exists');

        EduAcademicYears::createYear($this->actx, [
            'eth_year' => 2019,
            'name' => 'Duplicate 2019',
        ]);
    }

    public function test_closing_academic_year_checks_open_marks(): void
    {
        $year = EduAcademicYears::createYear($this->actx, [
            'eth_year' => 2019,
            'name' => '2019 ዓ.ም',
            'status' => 'active',
        ]);

        $classId = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 5',
            'academic_year_id' => $year['id'],
            'status' => 'active',
        ]);
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'name' => 'Liturgy',
        ]);
        $assessmentId = DB::table('edu_assessments')->insertGetId([
            'course_id' => $courseId,
            'title' => 'Midterm',
        ]);
        // Insert an un-published score
        DB::table('edu_scores')->insert([
            'assessment_id' => $assessmentId,
            'user_id' => 10,
            'score' => 85,
            'status' => 'submitted', // not published
        ]);

        $this->expectException(ApiError::class);
        $this->expectExceptionMessage('Cannot close academic year');

        EduAcademicYears::closeYear($this->actx, $year['id']);
    }

    public function test_term_crud_and_uniqueness_per_year(): void
    {
        $year = EduAcademicYears::createYear($this->actx, [
            'eth_year' => 2019,
            'name' => '2019 ዓ.ም',
            'starts_on' => '2026-09-11',
            'ends_on' => '2027-09-10',
        ]);

        $term1 = EduAcademicYears::createTerm($this->actx, $year['id'], [
            'name' => 'Term I',
            'sort_order' => 1,
            'starts_on' => '2026-09-11',
            'ends_on' => '2027-01-30',
        ]);
        $this->assertSame('Term I', $term1['name']);

        // Duplicate name in same year should fail
        try {
            EduAcademicYears::createTerm($this->actx, $year['id'], [
                'name' => 'Term I',
            ]);
            $this->fail('Expected TERM_EXISTS');
        } catch (ApiError $e) {
            $this->assertSame('TERM_EXISTS', $e->errorCode);
        }

        // Term outside year dates should fail
        try {
            EduAcademicYears::createTerm($this->actx, $year['id'], [
                'name' => 'Term Outside',
                'starts_on' => '2025-01-01', // Before year starts_on
            ]);
            $this->fail('Expected TERM_OUTSIDE_YEAR');
        } catch (ApiError $e) {
            $this->assertSame('VALIDATION_ERROR', $e->errorCode);
        }
    }

    public function test_built_in_levels_cannot_be_deleted(): void
    {
        $builtInId = DB::table('edu_levels')->insertGetId([
            'code' => 'G1',
            'name' => 'ክፍል 1',
            'name_en' => 'Grade 1',
            'kind' => 'grade',
            'sort_order' => 1,
            'built_in' => 1,
        ]);

        try {
            EduAcademicYears::deleteLevel($this->actx, $builtInId);
            $this->fail('Expected BUILT_IN_LEVEL error');
        } catch (ApiError $e) {
            $this->assertSame('BUILT_IN_LEVEL', $e->errorCode);
        }

        // Custom level can be created and deleted
        $custom = EduAcademicYears::createLevel($this->actx, [
            'code' => 'ADULT_CATECHISM',
            'name' => 'የአዋቂዎች ትምህርት',
            'name_en' => 'Adult Catechism',
            'kind' => 'extra',
            'sort_order' => 20,
        ]);
        $this->assertSame('ADULT_CATECHISM', $custom['code']);

        EduAcademicYears::deleteLevel($this->actx, $custom['id']);
        $this->assertNull(DB::table('edu_levels')->where('id', $custom['id'])->first());
    }

    public function test_assignable_excludes_already_enrolled_and_other_exclusive_classes(): void
    {
        $year = EduAcademicYears::createYear($this->actx, ['eth_year' => 2019, 'name' => '2019 ዓ.ም']);

        $classA = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 5A',
            'academic_year_id' => $year['id'],
            'allow_multiple' => 0, // exclusive
            'status' => 'active',
        ]);
        $classB = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 5B',
            'academic_year_id' => $year['id'],
            'allow_multiple' => 0, // exclusive
            'status' => 'active',
        ]);

        $u1 = DB::table('users')->insertGetId(['full_name' => 'Abebe Bikila', 'phone' => '0911000001', 'status' => 'active', 'account_type' => 'user']);
        $u2 = DB::table('users')->insertGetId(['full_name' => 'Belay Zeleke', 'phone' => '0911000002', 'status' => 'active', 'account_type' => 'user']);
        $u3 = DB::table('users')->insertGetId(['full_name' => 'Chala Tafa', 'phone' => '0911000003', 'status' => 'active', 'account_type' => 'user']);

        // Enroll u1 in Class A
        DB::table('edu_enrollments')->insert([
            'class_id' => $classA,
            'user_id' => $u1,
            'academic_year_id' => $year['id'],
            'exclusive' => 1,
            'status' => 'active',
        ]);

        // Check assignable for Class A: u1 is already enrolled, should see u2 and u3
        $assignableA = EduRegistration::assignable($classA, null, null, ['page' => 1, 'limit' => 20]);
        $idsA = array_column($assignableA['items'], 'id');
        $this->assertNotContains($u1, $idsA);
        $this->assertContains($u2, $idsA);
        $this->assertContains($u3, $idsA);

        // Check assignable for Class B: u1 is active in another exclusive class for 2019, should NOT appear!
        $assignableB = EduRegistration::assignable($classB, null, null, ['page' => 1, 'limit' => 20]);
        $idsB = array_column($assignableB['items'], 'id');
        $this->assertNotContains($u1, $idsB);
        $this->assertContains($u2, $idsB);
        $this->assertContains($u3, $idsB);
    }

    public function test_exclusive_assignment_and_conflict_handling(): void
    {
        $year = EduAcademicYears::createYear($this->actx, ['eth_year' => 2019, 'name' => '2019 ዓ.ም']);

        $classA = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 5A',
            'academic_year_id' => $year['id'],
            'allow_multiple' => 0,
            'status' => 'active',
        ]);
        $classB = DB::table('edu_classes')->insertGetId([
            'name' => 'Grade 5B',
            'academic_year_id' => $year['id'],
            'allow_multiple' => 0,
            'status' => 'active',
        ]);

        $u1 = DB::table('users')->insertGetId(['full_name' => 'Dawit Tsige', 'phone' => '0911000004', 'status' => 'active', 'account_type' => 'user']);
        $u2 = DB::table('users')->insertGetId(['full_name' => 'Ephrem Tamiru', 'phone' => '0911000005', 'status' => 'active', 'account_type' => 'user']);

        // Assign u1 to Class A
        $resA = EduRegistration::assign($this->actx, $classA, [
            'user_ids' => [$u1],
            'program' => 'regular',
        ]);
        $this->assertSame(1, $resA['assigned_count']);
        $this->assertSame('assigned', $resA['results'][0]['status']);

        // Attempting to assign u1 to Class B should report in_other_class
        $resB = EduRegistration::assign($this->actx, $classB, [
            'user_ids' => [$u1, $u2],
            'program' => 'regular',
        ]);
        $this->assertSame(1, $resB['assigned_count']); // only u2 was assigned
        $resultsMap = [];
        foreach ($resB['results'] as $r) {
            $resultsMap[$r['user_id']] = $r;
        }
        $this->assertSame('in_other_class', $resultsMap[$u1]['status']);
        $this->assertSame('Grade 5A', $resultsMap[$u1]['class_name']);
        $this->assertSame('assigned', $resultsMap[$u2]['status']);
    }

    public function test_transfer_student_between_classes_with_journey_history(): void
    {
        $year = EduAcademicYears::createYear($this->actx, ['eth_year' => 2019, 'name' => '2019 ዓ.ም']);

        $classA = DB::table('edu_classes')->insertGetId(['name' => 'Grade 5A', 'academic_year_id' => $year['id'], 'allow_multiple' => 0, 'status' => 'active']);
        $classB = DB::table('edu_classes')->insertGetId(['name' => 'Grade 5B', 'academic_year_id' => $year['id'], 'allow_multiple' => 0, 'status' => 'active']);

        $u1 = DB::table('users')->insertGetId(['full_name' => 'Fasil Demoz', 'phone' => '0911000006', 'status' => 'active', 'account_type' => 'user']);

        EduRegistration::assign($this->actx, $classA, ['user_ids' => [$u1], 'program' => 'regular']);
        $enr = DB::table('edu_enrollments')->where(['class_id' => $classA, 'user_id' => $u1, 'status' => 'active'])->first();

        // Transfer to Class B
        $transferRes = EduRegistration::transfer($this->actx, $enr->id, $classB, 'Moving to afternoon section');
        $this->assertSame('transferred', $transferRes['status']);

        // Old enrollment is withdrawn
        $oldFresh = DB::table('edu_enrollments')->where('id', $enr->id)->first();
        $this->assertSame('withdrawn', $oldFresh->status);

        // New enrollment in Class B is active
        $newEnr = DB::table('edu_enrollments')->where(['class_id' => $classB, 'user_id' => $u1, 'status' => 'active'])->first();
        $this->assertNotNull($newEnr);

        // Journey history contains 'withdrawn' and 'class_changed'
        $journey = DB::table('edu_journey')->where('user_id', $u1)->pluck('event')->all();
        $this->assertContains('withdrawn', $journey);
        $this->assertContains('class_changed', $journey);
    }

    public function test_course_roster_filtered_by_member_groups(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Multi-group Class', 'status' => 'active']);

        $uYouth = DB::table('users')->insertGetId(['full_name' => 'Youth Member', 'member_group' => 'youth_adult', 'status' => 'active']);
        $uChild = DB::table('users')->insertGetId(['full_name' => 'Child Member', 'member_group' => 'children', 'status' => 'active']);

        DB::table('edu_enrollments')->insert([
            ['class_id' => $classId, 'user_id' => $uYouth, 'status' => 'active'],
            ['class_id' => $classId, 'user_id' => $uChild, 'status' => 'active'],
        ]);

        // Course restricted to youth_adult
        $courseId = DB::table('edu_courses')->insertGetId([
            'class_id' => $classId,
            'name' => 'Advanced Dogma',
            'member_groups' => 'youth_adult',
            'mode' => 'physical',
            'pass_mark' => 60,
        ]);
        $course = DB::table('edu_courses')->where('id', $courseId)->first();

        $rosterUserIds = Edu::rosterQuery($course)->pluck('u.id')->map(fn ($x) => (int) $x)->all();
        $this->assertContains($uYouth, $rosterUserIds);
        $this->assertNotContains($uChild, $rosterUserIds);
    }

    public function test_course_program_linking_and_detail(): void
    {
        $classId = DB::table('edu_classes')->insertGetId(['name' => 'Grade 6', 'status' => 'active']);
        $programId = DB::table('programs')->insertGetId(['title' => 'Sunday School Morning Service', 'program_type' => 'regular']);

        $course = Edu::createCourse($this->actx, $classId, [
            'name' => 'Church History',
            'mode' => 'physical',
            'pass_mark' => 55,
            'program_ids' => [$programId],
        ]);

        $this->assertSame('Church History', $course['name']);
        $this->assertSame('physical', $course['mode']);
        $this->assertEquals(55.0, $course['pass_mark']);
        $this->assertNotEmpty($course['programs']);
        $this->assertSame('Sunday School Morning Service', $course['programs'][0]->title);
    }
}
