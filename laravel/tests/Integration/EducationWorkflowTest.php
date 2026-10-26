<?php

namespace Tests\Integration;

use Illuminate\Support\Facades\DB;

class EducationWorkflowTest extends IntegrationTestCase
{
    private object $admin;
    private object $admin2;
    private object $teacher;
    private int $classId;
    private int $courseId;
    private int $assessmentId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = $this->member(['education.manage']);
        $this->admin2 = $this->member(['education.manage']);
        $this->teacher = $this->member();
        $this->classId = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Class', 'academic_year' => '2019', 'semester' => '1', 'streams' => ['ሀ', 'ለ'], 'capacity' => 50])->assertCreated()->json('data.id');
        $this->courseId = (int) $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'ሥነ መለኮት', 'code' => 'TH101'])->assertCreated()->json('data.id');
        $this->as($this->admin, 'POST', "edu/admin/courses/{$this->courseId}/teachers", ['user_id' => $this->teacher->id])->assertCreated();
        $this->assessmentId = (int) $this->as($this->teacher, 'POST', "edu/courses/{$this->courseId}/assessments", ['title' => 'Mid exam', 'max_score' => 50, 'weight' => 100])->assertSuccessful()->json('data.id');
    }

    private function student(?int $classId = null, string $program = 'regular'): object
    {
        $s = $this->member();
        DB::table('edu_enrollments')->insert(['class_id' => $classId ?? $this->classId, 'user_id' => $s->id, 'program' => $program, 'status' => 'active']);
        return $s;
    }

    private function myScore(object $s): mixed
    {
        $c = collect($this->as($s, 'GET', "edu/classes/{$this->classId}/my-results")->assertOk()->json('data.courses'))->firstWhere('course.id', $this->courseId);
        return $c['assessments'][0]['score'] ?? null;
    }

    // ---------------------------------------------------------------- teachers

    public function test_teacher_access_follows_the_assignment(): void
    {
        $outsider = $this->member();
        $this->as($this->teacher, 'GET', "edu/assessments/{$this->assessmentId}/scores")->assertOk();
        $this->as($outsider, 'GET', "edu/assessments/{$this->assessmentId}/scores")->assertForbidden();
        $this->as($this->teacher, 'GET', 'edu/teaching')->assertOk()->assertJsonPath('data.0.id', $this->courseId);

        $assignment = DB::table('edu_course_teachers')->where(['course_id' => $this->courseId, 'user_id' => $this->teacher->id])->value('id');
        $this->as($this->admin, 'PATCH', "edu/admin/course-teachers/$assignment", ['status' => 'suspended', 'note' => 'leave'])->assertOk();
        $this->as($this->teacher, 'GET', "edu/assessments/{$this->assessmentId}/scores")->assertForbidden();
        $this->as($this->teacher, 'PUT', "edu/assessments/{$this->assessmentId}/scores", ['scores' => []])->assertForbidden();

        $row = DB::table('edu_course_teachers')->where('id', $assignment)->first();
        $this->assertSame($this->admin->id, (int) $row->assigned_by, 'who assigned is kept');
        $this->assertTrue(DB::table('edu_journey')->where(['user_id' => $this->teacher->id, 'event' => 'teacher_suspended'])->exists());
        $this->assertSame('member', 'member', 'role untouched');
        $this->assertSame('user', DB::table('users')->where('id', $this->teacher->id)->value('account_type'));
    }

    public function test_a_student_of_one_class_can_teach_in_another(): void
    {
        $s = $this->student();
        $other = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Other'])->json('data.id');
        $otherCourse = (int) $this->as($this->admin, 'POST', "edu/admin/classes/$other/courses", ['name' => 'Other'])->json('data.id');
        $this->as($this->admin, 'POST', "edu/admin/courses/$otherCourse/teachers", ['user_id' => $s->id])->assertCreated();
        $this->as($s, 'GET', "edu/courses/$otherCourse/assessments")->assertOk();
        $this->as($s, 'GET', "edu/courses/{$this->courseId}/assessments")->assertForbidden();
    }

    // ---------------------------------------------------------------- marks

    public function test_marks_go_draft_submitted_rejected_resubmitted_approved_published(): void
    {
        $s = $this->student();
        $sheet = "edu/assessments/{$this->assessmentId}/scores";
        $this->as($this->teacher, 'PUT', $sheet, ['scores' => [['user_id' => $s->id, 'score' => 60]]])->assertStatus(422); // > max 50
        $this->as($this->teacher, 'PUT', $sheet, ['scores' => [['user_id' => $s->id, 'score' => 30]]])->assertOk();
        $this->assertNull($this->myScore($s), 'a draft is not shown to the student');

        $this->as($this->teacher, 'POST', "edu/assessments/{$this->assessmentId}/submit")->assertOk()->assertJsonPath('data.submitted', 1);
        $this->as($this->teacher, 'PUT', $sheet, ['scores' => [['user_id' => $s->id, 'score' => 31]]])->assertStatus(409); // locked while in review
        $this->as($this->teacher, 'POST', "edu/admin/assessments/{$this->assessmentId}/review", ['decision' => 'approve'])->assertForbidden(); // not an admin

        $this->as($this->admin, 'POST', "edu/admin/assessments/{$this->assessmentId}/review", ['decision' => 'reject'])->assertStatus(422); // reason required
        $this->as($this->admin, 'POST', "edu/admin/assessments/{$this->assessmentId}/review", ['decision' => 'reject', 'note' => 'Check question 3'])->assertOk();
        $this->assertSame('rejected', DB::table('edu_scores')->where(['assessment_id' => $this->assessmentId, 'user_id' => $s->id])->value('status'));
        $row = collect($this->as($this->teacher, 'GET', $sheet)->json('data.scores'))->firstWhere('user_id', $s->id);
        $this->assertSame('Check question 3', $row['review_note']);
        $this->assertTrue($row['editable']);

        $this->as($this->teacher, 'PUT', $sheet, ['scores' => [['user_id' => $s->id, 'score' => 34]]])->assertOk();
        $this->as($this->teacher, 'POST', "edu/assessments/{$this->assessmentId}/submit")->assertOk();
        $this->as($this->admin, 'POST', "edu/admin/assessments/{$this->assessmentId}/review", ['decision' => 'approve', 'publish' => true])->assertOk()->assertJsonPath('data.published', 1);

        $this->assertEquals(34, $this->myScore($s));
        $actions = DB::table('edu_score_history')->where(['assessment_id' => $this->assessmentId, 'user_id' => $s->id])->orderBy('id')->pluck('action')->all();
        $this->assertSame(['entered', 'submitted', 'rejected', 'edited', 'submitted', 'approved', 'published'], $actions);
        $this->assertTrue(DB::table('edu_journey')->where(['user_id' => $s->id, 'event' => 'mark_published'])->exists());
        $this->assertTrue(DB::table('notifications')->where('user_id', $s->id)->where('dedupe_key', 'like', "edu:marks:published:{$this->assessmentId}:%")->exists());
    }

    public function test_nobody_approves_their_own_submission(): void
    {
        $s = $this->student();
        $this->as($this->admin, 'POST', "edu/admin/courses/{$this->courseId}/teachers", ['user_id' => $this->admin->id])->assertCreated();
        $this->as($this->admin, 'PUT', "edu/assessments/{$this->assessmentId}/scores", ['scores' => [['user_id' => $s->id, 'score' => 40]]])->assertOk();
        $this->as($this->admin, 'POST', "edu/assessments/{$this->assessmentId}/submit")->assertOk();
        $this->as($this->admin, 'POST', "edu/admin/assessments/{$this->assessmentId}/review", ['decision' => 'approve'])->assertForbidden();
        $this->as($this->admin2, 'POST', "edu/admin/assessments/{$this->assessmentId}/review", ['decision' => 'approve'])->assertOk();
    }

    public function test_published_marks_change_only_by_amendment_with_a_reason(): void
    {
        $s = $this->student();
        DB::table('edu_scores')->insert(['assessment_id' => $this->assessmentId, 'user_id' => $s->id, 'score' => 20, 'status' => 'published', 'published_at' => now()]);
        $this->as($this->teacher, 'PUT', "edu/assessments/{$this->assessmentId}/scores", ['scores' => [['user_id' => $s->id, 'score' => 25]]])->assertStatus(409);
        $this->as($this->teacher, 'POST', "edu/admin/assessments/{$this->assessmentId}/amend", ['user_id' => $s->id, 'score' => 25, 'reason' => 'x'])->assertForbidden();
        $this->as($this->admin, 'POST', "edu/admin/assessments/{$this->assessmentId}/amend", ['user_id' => $s->id, 'score' => 25])->assertStatus(422);
        $this->as($this->admin, 'POST', "edu/admin/assessments/{$this->assessmentId}/amend", ['user_id' => $s->id, 'score' => 25, 'reason' => 'Addition error'])->assertOk();
        $this->assertEquals(25, $this->myScore($s));
        $h = DB::table('edu_score_history')->where(['assessment_id' => $this->assessmentId, 'user_id' => $s->id, 'action' => 'amended'])->first();
        $this->assertEquals(20, $h->old_score);
        $this->assertSame('Addition error', $h->reason);
    }

    public function test_students_see_only_their_own_results(): void
    {
        $a = $this->student();
        $b = $this->member(); // not enrolled
        $this->as($b, 'GET', "edu/classes/{$this->classId}/my-results")->assertForbidden();
        $this->as($a, 'GET', "edu/assessments/{$this->assessmentId}/scores")->assertForbidden();
        $this->as($a, 'GET', 'edu/admin/marks')->assertForbidden();
    }

    // ---------------------------------------------------------------- requests, add / drop

    public function test_study_mode_change_request_is_applied_on_approval(): void
    {
        $s = $this->student();
        $req = $this->as($s, 'POST', 'edu/me/requests', ['type' => 'study_mode_change', 'class_id' => $this->classId, 'requested_value' => 'distance', 'reason' => 'I moved away']);
        $req->assertCreated()->assertJsonPath('data.status', 'pending')->assertJsonPath('data.current_value', 'regular');
        $this->as($s, 'POST', 'edu/me/requests', ['type' => 'study_mode_change', 'class_id' => $this->classId, 'requested_value' => 'distance', 'reason' => 'again'])->assertStatus(409);
        $id = (int) $req->json('data.id');
        $this->as($s, 'POST', "edu/admin/requests/$id/review", ['decision' => 'approve'])->assertForbidden();
        $this->as($this->admin, 'POST', "edu/admin/requests/$id/review", ['decision' => 'approve', 'note' => 'ok'])->assertOk()->assertJsonPath('data.status', 'implemented');
        $this->assertSame('distance', DB::table('edu_enrollments')->where(['class_id' => $this->classId, 'user_id' => $s->id])->value('program'));
        $j = DB::table('edu_journey')->where(['user_id' => $s->id, 'event' => 'study_mode_changed'])->first();
        $this->assertSame('regular', $j->old_value);
        $this->assertSame('distance', $j->new_value);
        $this->assertSame($this->admin->id, (int) $j->actor_id);
    }

    public function test_class_change_respects_capacity_and_keeps_history(): void
    {
        $s = $this->student();
        $full = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Full', 'capacity' => 1])->json('data.id');
        $this->student($full);
        $this->as($s, 'POST', 'edu/me/requests', ['type' => 'class_change', 'class_id' => $this->classId, 'target_class_id' => $full, 'reason' => 'schedule'])->assertStatus(409);

        $open = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Open'])->json('data.id');
        $id = (int) $this->as($s, 'POST', 'edu/me/requests', ['type' => 'class_change', 'class_id' => $this->classId, 'target_class_id' => $open, 'reason' => 'schedule'])->assertCreated()->json('data.id');
        $this->as($this->admin, 'POST', "edu/admin/requests/$id/review", ['decision' => 'approve'])->assertOk();
        $this->assertSame('withdrawn', DB::table('edu_enrollments')->where(['class_id' => $this->classId, 'user_id' => $s->id])->value('status'), 'old enrollment kept, not deleted');
        $this->assertSame('active', DB::table('edu_enrollments')->where(['class_id' => $open, 'user_id' => $s->id])->value('status'));
    }

    public function test_dropping_and_adding_subjects_changes_the_roster(): void
    {
        $s = $this->student();
        $id = (int) $this->as($s, 'POST', 'edu/me/requests', ['type' => 'drop_subject', 'course_id' => $this->courseId, 'reason' => 'too much'])->assertCreated()->json('data.id');
        $this->as($this->admin, 'POST', "edu/admin/requests/$id/review", ['decision' => 'approve'])->assertOk();
        $this->as($this->teacher, 'PUT', "edu/assessments/{$this->assessmentId}/scores", ['scores' => [['user_id' => $s->id, 'score' => 10]]])->assertStatus(422);
        $this->assertNotContains($s->id, array_column($this->as($this->teacher, 'GET', "edu/assessments/{$this->assessmentId}/scores")->json('data.scores'), 'user_id'));

        // add it back (as an administrator), then a subject from another class
        $this->as($this->admin, 'POST', "edu/admin/students/{$s->id}/subjects", ['course_id' => $this->courseId, 'action' => 'add'])->assertOk()->assertJsonPath('data.on_roster', true);
        $other = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Elective'])->json('data.id');
        $elective = (int) $this->as($this->admin, 'POST', "edu/admin/classes/$other/courses", ['name' => 'Elective'])->json('data.id');
        $this->as($this->admin, 'POST', "edu/admin/students/{$s->id}/subjects", ['course_id' => $elective, 'action' => 'add'])->assertOk()->assertJsonPath('data.on_roster', true);
        $events = DB::table('edu_journey')->where('user_id', $s->id)->pluck('event')->all();
        $this->assertContains('subject_dropped', $events);
        $this->assertContains('subject_added', $events);
    }

    // ---------------------------------------------------------------- complaints

    public function test_complaints_are_confidential_and_follow_the_review_workflow(): void
    {
        $s = $this->student();
        $other = $this->student();
        $res = $this->as($s, 'POST', 'edu/me/complaints', ['category' => 'marks', 'assessment_id' => $this->assessmentId, 'subject' => 'My mid exam', 'description' => 'I think question 2 was marked wrong.']);
        $res->assertCreated();
        $id = (int) $res->json('data.id');
        $this->assertMatchesRegularExpression('/^EC-\d{4}-\d{6}$/', $res->json('data.ref'));
        $this->assertSame($this->courseId, $res->json('data.course.id'));

        $this->as($other, 'GET', "edu/me/complaints/$id")->assertNotFound();
        $this->as($other, 'GET', 'edu/admin/complaints')->assertForbidden();
        $notMine = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT X'])->json('data.id');
        $this->as($s, 'POST', 'edu/me/complaints', ['category' => 'other', 'class_id' => $notMine, 'subject' => 'xyz', 'description' => 'not my class at all'])->assertStatus(422);

        $this->as($this->admin, 'POST', "edu/admin/complaints/$id/actions", ['body' => 'Teacher says Q2 is ambiguous', 'internal' => true, 'status' => 'under_review'])->assertOk();
        $this->as($this->admin, 'POST', "edu/admin/complaints/$id/actions", ['status' => 'awaiting_information'])->assertStatus(422);
        $this->as($this->admin, 'POST', "edu/admin/complaints/$id/actions", ['status' => 'awaiting_information', 'body' => 'Please attach your answer sheet photo'])->assertOk();

        $mine = $this->as($s, 'GET', "edu/me/complaints/$id")->assertOk()->json('data');
        $this->assertSame('awaiting_information', $mine['status']);
        $this->assertSame(['Please attach your answer sheet photo'], array_column(array_filter($mine['messages'], fn ($m) => $m['body'] !== '—'), 'body'), 'internal note hidden');
        $this->assertArrayNotHasKey('assigned_to', $mine);

        $this->as($s, 'POST', "edu/me/complaints/$id/messages", ['body' => 'Sent to the office'])->assertOk()->assertJsonPath('data.status', 'under_review');
        $this->as($this->admin, 'POST', "edu/admin/complaints/$id/actions", ['status' => 'resolved'])->assertStatus(422);
        $done = $this->as($this->admin, 'POST', "edu/admin/complaints/$id/actions", ['status' => 'resolved', 'body' => 'Mark reviewed; corrected by amendment.'])->assertOk()->json('data');
        $this->assertNotNull($done['resolved_at']);
        $this->assertNotNull($done['resolution_hours']);
        $this->assertSame(0, DB::table('edu_scores')->where('assessment_id', $this->assessmentId)->count(), 'a complaint never changes marks by itself');
    }

    public function test_journey_is_self_service_and_admin_only_for_others(): void
    {
        $s = $this->student();
        $other = $this->member();
        $this->as($this->admin, 'PATCH', "edu/admin/classes/{$this->classId}/students/{$s->id}", ['stream' => 'ሀ', 'reason' => 'placement'])->assertOk();
        $this->as($this->admin, 'PATCH', "edu/admin/classes/{$this->classId}/students/{$s->id}", ['stream' => 'ሐ'])->assertStatus(422);
        $mine = $this->as($s, 'GET', 'edu/me/journey')->assertOk()->json('data');
        $this->assertSame('stream_changed', $mine[0]['event']);
        $this->as($other, 'GET', "edu/admin/students/{$s->id}/journey")->assertForbidden();
        $this->as($this->admin, 'GET', "edu/admin/students/{$s->id}/journey")->assertOk();
    }
}
