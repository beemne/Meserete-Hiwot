<?php

namespace Tests\Integration;

use Illuminate\Support\Facades\DB;

/** Every way a teacher is assigned in the app, checked from the teacher's side. */
class TeacherAssignmentTest extends IntegrationTestCase
{
    private object $admin;
    private int $classId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = $this->member(['education.manage']);
        $this->classId = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Teach'])->assertCreated()->json('data.id');
    }

    /** What the teacher sees: the subject on the ትምህርት home, and the subject itself opens. */
    private function assertTeaches(object $t, int $courseId, bool $yes = true): void
    {
        $teaching = array_column($this->as($t, 'GET', 'edu/overview')->assertOk()->json('data.teaching'), 'id');
        $yes ? $this->assertContains($courseId, $teaching) : $this->assertNotContains($courseId, $teaching);
        $this->as($t, 'GET', "edu/courses/$courseId")->assertStatus($yes ? 200 : 403);
        $this->as($t, 'GET', "edu/courses/$courseId/assessments")->assertStatus($yes ? 200 : 403);
    }

    public function test_teacher_chosen_when_creating_the_subject(): void
    {
        $t = $this->member();
        $c = $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'A', 'teacher_user_id' => $t->id])->assertCreated();
        $this->assertSame($t->id, $c->json('data.teacher.id'));
        $this->assertTeaches($t, (int) $c->json('data.id'));
    }

    public function test_teacher_changed_in_the_subject_form(): void
    {
        $t1 = $this->member();
        $t2 = $this->member();
        $id = (int) $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'B', 'teacher_user_id' => $t1->id])->json('data.id');
        $this->as($this->admin, 'PATCH', "edu/admin/courses/$id", ['name' => 'B', 'teacher_user_id' => $t2->id, 'progress' => 0])->assertOk()->assertJsonPath('data.teacher.id', $t2->id);
        $this->assertTeaches($t2, $id);
        $this->assertTeaches($t1, $id, false);
        // the form saved again with the same teacher changes nothing
        $this->as($this->admin, 'PATCH', "edu/admin/courses/$id", ['name' => 'B2', 'teacher_user_id' => $t2->id, 'progress' => 10])->assertOk();
        $this->assertTeaches($t2, $id);
        // and clearing the teacher
        $this->as($this->admin, 'PATCH', "edu/admin/courses/$id", ['teacher_user_id' => null])->assertOk()->assertJsonPath('data.teacher', null);
        $this->assertTeaches($t2, $id, false);
    }

    public function test_teacher_added_later_through_the_teachers_sheet(): void
    {
        $id = (int) $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'C'])->json('data.id');
        $t = $this->member();
        $this->as($this->admin, 'POST', "edu/admin/courses/$id/teachers", ['user_id' => $t->id])->assertCreated();
        $this->assertTeaches($t, $id);
        $this->assertSame($t->id, $this->as($this->admin, 'GET', "edu/classes/{$this->classId}")->json('data.courses.0.teacher.id'), 'shown as the subject teacher');
    }

    public function test_a_suspended_teacher_chosen_again_in_the_form_is_reactivated(): void
    {
        $t = $this->member();
        $id = (int) $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'D', 'teacher_user_id' => $t->id])->json('data.id');
        $row = DB::table('edu_course_teachers')->where(['course_id' => $id, 'user_id' => $t->id])->value('id');
        $this->as($this->admin, 'PATCH', "edu/admin/course-teachers/$row", ['status' => 'suspended'])->assertOk();
        $this->assertTeaches($t, $id, false);
        $this->as($this->admin, 'PATCH', "edu/admin/courses/$id", ['teacher_user_id' => $t->id])->assertOk()->assertJsonPath('data.teacher.id', $t->id);
        $this->assertTeaches($t, $id);
    }

    public function test_a_removed_teacher_can_be_assigned_again(): void
    {
        $t = $this->member();
        $id = (int) $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'E', 'teacher_user_id' => $t->id])->json('data.id');
        $row = DB::table('edu_course_teachers')->where(['course_id' => $id, 'user_id' => $t->id])->value('id');
        $this->as($this->admin, 'PATCH', "edu/admin/course-teachers/$row", ['status' => 'removed'])->assertOk();
        $this->assertTeaches($t, $id, false);
        $this->as($this->admin, 'POST', "edu/admin/courses/$id/teachers", ['user_id' => $t->id])->assertCreated();
        $this->assertTeaches($t, $id);
    }

    public function test_an_admin_account_or_a_student_can_be_a_teacher(): void
    {
        $adminTeacher = $this->member([], ['account_type' => 'admin', 'role_id' => DB::table('roles')->where('slug', 'moderator')->value('id')]);
        $student = $this->member();
        DB::table('edu_enrollments')->insert(['class_id' => $this->classId, 'user_id' => $student->id, 'program' => 'regular', 'status' => 'active']);
        $other = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Other'])->json('data.id');
        foreach ([$adminTeacher, $student] as $t) {
            $id = (int) $this->as($this->admin, 'POST', "edu/admin/classes/$other/courses", ['name' => 'F' . $t->id, 'teacher_user_id' => $t->id])->assertCreated()->json('data.id');
            $this->assertTeaches($t, $id);
        }
    }
}
