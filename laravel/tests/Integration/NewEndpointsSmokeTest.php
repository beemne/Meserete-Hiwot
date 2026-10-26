<?php

namespace Tests\Integration;

use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Every list / read endpoint added for the master prompt answers without a server error. */
class NewEndpointsSmokeTest extends IntegrationTestCase
{
    public function test_education_read_endpoints_and_complaint_attachments(): void
    {
        $admin = $this->member(['education.manage']);
        $teacher = $this->member();
        $student = $this->member();
        $class = (int) $this->as($admin, 'POST', 'edu/admin/classes', ['name' => 'IT Smoke', 'streams' => ['A', 'B']])->json('data.id');
        $course = (int) $this->as($admin, 'POST', "edu/admin/classes/$class/courses", ['name' => 'Smoke subject', 'teacher_user_id' => $teacher->id])->json('data.id');
        DB::table('edu_enrollments')->insert(['class_id' => $class, 'user_id' => $student->id, 'program' => 'regular', 'status' => 'active']);
        $assessment = (int) $this->as($teacher, 'POST', "edu/courses/$course/assessments", ['title' => 'Quiz', 'max_score' => 10])->json('data.id');
        $this->as($teacher, 'PUT', "edu/assessments/$assessment/scores", ['scores' => [['user_id' => $student->id, 'score' => 7]]])->assertOk();
        $this->as($teacher, 'POST', "edu/assessments/$assessment/submit")->assertOk();

        // queues and histories
        foreach (['submitted', 'approved', 'rejected', 'published', 'draft'] as $s) $this->as($admin, 'GET', "edu/admin/marks?status=$s")->assertOk();
        $this->assertSame($assessment, $this->as($admin, 'GET', 'edu/admin/marks')->json('data.0.id'));
        $this->as($admin, 'POST', "edu/admin/assessments/$assessment/review", ['decision' => 'approve'])->assertOk();
        $this->as($admin, 'POST', "edu/admin/assessments/$assessment/publish")->assertOk()->assertJsonPath('data.published', 1);
        $this->assertNotEmpty($this->as($admin, 'GET', "edu/admin/assessments/$assessment/history")->assertOk()->json('data'));
        $this->as($admin, 'GET', "edu/admin/assessments/$assessment/history?user_id={$student->id}")->assertOk();
        $this->as($teacher, 'GET', 'edu/teaching')->assertOk();
        $this->as($admin, 'GET', "edu/admin/courses/$course/teachers")->assertOk();

        // requests
        $this->as($student, 'POST', 'edu/me/requests', ['type' => 'stream_change', 'class_id' => $class, 'requested_value' => 'B', 'reason' => 'closer friends'])->assertCreated();
        $mine = $this->as($student, 'GET', 'edu/me/requests')->assertOk()->json('data');
        $this->assertCount(1, $mine);
        foreach (['pending', 'implemented', 'approved', 'rejected', 'cancelled'] as $s) $this->as($admin, 'GET', "edu/admin/requests?status=$s")->assertOk();
        $this->as($admin, 'GET', 'edu/admin/requests?q=' . rawurlencode('IT Member'))->assertOk();
        $this->as($student, 'DELETE', "edu/me/requests/{$mine[0]['id']}")->assertOk()->assertJsonPath('data.status', 'cancelled');

        // complaint with an attachment (multipart), downloaded by the student and the reviewer only
        $pdf = UploadedFile::fake()->createWithContent('evidence.pdf', "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");
        $token = \App\Mz\Auth\Tokens::signAccess($student, 'app', $student->device_id)['token'];
        $res = $this->call('POST', '/api/v1/edu/me/complaints', ['category' => 'marks', 'course_id' => (string) $course, 'subject' => 'Quiz mark', 'description' => 'Question two was marked wrongly.'],
            [], ['file' => $pdf], ['HTTP_AUTHORIZATION' => "Bearer $token", 'HTTP_ACCEPT' => 'application/json', 'CONTENT_TYPE' => 'multipart/form-data']);
        $res->assertCreated();
        $cid = (int) $res->json('data.id');
        $this->assertTrue($res->json('data.has_attachment'));
        $this->as($student, 'GET', 'edu/me/complaints')->assertOk()->assertJsonPath('data.0.id', $cid);
        $this->as($student, 'GET', "edu/complaints/$cid/attachment")->assertOk();
        $this->as($admin, 'GET', "edu/complaints/$cid/attachment")->assertOk();
        $this->as($this->member(), 'GET', "edu/complaints/$cid/attachment")->assertNotFound();
        foreach (['submitted', 'under_review', 'awaiting_information', 'resolved', 'rejected', 'escalated'] as $s) $this->as($admin, 'GET', "edu/admin/complaints?status=$s")->assertOk();
        $this->as($admin, 'GET', 'edu/admin/complaints?category=marks&q=Quiz')->assertOk();
        $this->as($admin, 'GET', "edu/admin/complaints/$cid")->assertOk();
        $this->as($admin, 'POST', "edu/admin/complaints/$cid/actions", ['assigned_to' => $admin->id])->assertOk()->assertJsonPath('data.assigned_to.id', $admin->id);
        DB::table('edu_complaints')->where('id', $cid)->value('attachment_path') && \App\Mz\Services\Storage::remove(DB::table('edu_complaints')->where('id', $cid)->value('attachment_path'));

        $this->as($student, 'GET', 'edu/me/journey')->assertOk();
        $this->as($admin, 'GET', "edu/admin/students/{$student->id}/journey")->assertOk();
        $this->as($student, 'GET', "edu/classes/$class/my-results")->assertOk();
    }
}
