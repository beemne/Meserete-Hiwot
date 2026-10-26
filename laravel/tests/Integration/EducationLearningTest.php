<?php

namespace Tests\Integration;

use App\Mz\Auth\Tokens;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;

/**
 * The ትምህርት learning platform: module switch on the server, records protected from deletion,
 * the catalog (categories → subjects → lessons → materials), who may read and write, progress /
 * continue learning, quizzes (eligibility, attempts, time, hidden answers) and how quiz scores reach
 * the official marks only through the existing review and publication.
 */
class EducationLearningTest extends IntegrationTestCase
{
    private object $admin;
    private object $editor;
    private object $teacher;
    private object $student;
    private int $classId;
    private int $courseId;
    private int $subjectId;
    private int $categoryId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->admin = $this->member(['education.manage']);
        $this->editor = $this->member(['education.content']);
        $this->teacher = $this->member();
        $this->classId = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Learn Class'])->assertCreated()->json('data.id');
        $this->courseId = (int) $this->as($this->admin, 'POST', "edu/admin/classes/{$this->classId}/courses", ['name' => 'የቤተ ክርስቲያን ታሪክ'])->assertCreated()->json('data.id');
        $this->as($this->admin, 'POST', "edu/admin/courses/{$this->courseId}/teachers", ['user_id' => $this->teacher->id])->assertCreated();
        $this->categoryId = (int) DB::table('edu_categories')->where('name_en', 'Church History')->value('id');
        $this->subjectId = (int) $this->as($this->editor, 'POST', 'edu/content/subjects', ['category_id' => $this->categoryId, 'name' => 'IT Church History', 'status' => 'published'])->assertCreated()->json('data.id');
        $this->as($this->admin, 'PATCH', "edu/admin/courses/{$this->courseId}", ['subject_id' => $this->subjectId])->assertOk()->assertJsonPath('data.subject_id', $this->subjectId);
        $this->student = $this->member();
        DB::table('edu_enrollments')->insert(['class_id' => $this->classId, 'user_id' => $this->student->id, 'program' => 'regular', 'status' => 'active']);
    }

    private function upload(object $user, string $uri, UploadedFile $file, array $fields = []): TestResponse
    {
        $token = Tokens::signAccess($user, 'app', $user->device_id)['token'];
        return $this->withHeaders(['Authorization' => "Bearer $token", 'Accept' => 'application/json'])->post('/api/v1/' . $uri, $fields + ['file' => $file]);
    }

    private function lesson(array $attrs = []): int
    {
        return (int) $this->as($this->editor, 'POST', "edu/subjects/{$this->subjectId}/lessons", $attrs + ['title' => 'Lesson ' . uniqid(), 'body' => "# Title\n\nText", 'status' => 'published'])->assertCreated()->json('data.id');
    }

    // ---------------------------------------------------------------- module switch, deletion

    public function test_the_education_switch_is_enforced_by_the_server(): void
    {
        DB::table('settings')->updateOrInsert(['key' => 'modules.policy'], ['value' => json_encode(['mezmur_enabled' => true, 'education_enabled' => true, 'user_overrides' => [(string) $this->student->id => ['education_enabled' => false]]])]);
        $this->as($this->student, 'GET', 'edu/overview')->assertForbidden()->assertJsonPath('code', 'MODULE_DISABLED');
        $this->as($this->student, 'GET', 'edu/me/dashboard')->assertForbidden();
        $this->as($this->student, 'GET', 'edu/me/requests')->assertForbidden();
        $this->as($this->student, 'GET', 'library/books?domain=timhirt')->assertForbidden();
        $this->as($this->student, 'GET', 'library/books?domain=mezmur')->assertOk();
        // The module's own administrators keep their tools.
        DB::table('settings')->updateOrInsert(['key' => 'modules.policy'], ['value' => json_encode(['mezmur_enabled' => true, 'education_enabled' => false])]);
        $this->as($this->admin, 'GET', 'edu/admin/classes')->assertOk();
        $this->as($this->teacher, 'GET', 'edu/overview')->assertForbidden();
    }

    public function test_classes_and_subjects_with_records_are_archived_not_deleted(): void
    {
        $this->as($this->admin, 'DELETE', "edu/admin/classes/{$this->classId}")->assertStatus(409)->assertJsonPath('code', 'HAS_RECORDS');
        $this->assertTrue(DB::table('edu_enrollments')->where(['class_id' => $this->classId, 'user_id' => $this->student->id])->exists(), 'enrollment kept');

        $a = (int) $this->as($this->teacher, 'POST', "edu/courses/{$this->courseId}/assessments", ['title' => 'Exam', 'max_score' => 10])->json('data.id');
        $this->as($this->teacher, 'PUT', "edu/assessments/$a/scores", ['scores' => [['user_id' => $this->student->id, 'score' => 7]]])->assertOk();
        $this->as($this->teacher, 'DELETE', "edu/assessments/$a")->assertStatus(409);
        $this->as($this->admin, 'DELETE', "edu/admin/courses/{$this->courseId}")->assertStatus(409);
        $this->assertSame('7.00', (string) DB::table('edu_scores')->where(['assessment_id' => $a, 'user_id' => $this->student->id])->value('score'));

        // Empty ones can still be deleted.
        $empty = (int) $this->as($this->admin, 'POST', 'edu/admin/classes', ['name' => 'IT Empty'])->json('data.id');
        $this->as($this->admin, 'DELETE', "edu/admin/classes/$empty")->assertOk();
    }

    // ---------------------------------------------------------------- catalog

    public function test_categories_are_managed_dynamically(): void
    {
        $names = collect($this->as($this->student, 'GET', 'edu/categories')->assertOk()->json('data'))->pluck('name_en')->all();
        foreach (['Holy Bible', 'Church History', 'Liturgy & Order', 'Hagiography'] as $n) $this->assertContains($n, $names);

        $this->as($this->student, 'POST', 'edu/content/categories', ['name' => 'X'])->assertForbidden();
        $id = (int) $this->as($this->editor, 'POST', 'edu/content/categories', ['name' => 'ልሳነ ግእዝ', 'name_en' => "Ge'ez"])->assertCreated()->json('data.id');
        $this->assertContains($id, collect($this->as($this->student, 'GET', 'edu/categories')->json('data'))->pluck('id')->all());

        $ids = collect($this->as($this->editor, 'GET', 'edu/categories?all=1')->json('data'))->pluck('id')->all();
        $reordered = array_merge([$id], array_values(array_diff($ids, [$id])));
        $this->as($this->editor, 'PUT', 'edu/content/categories/order', ['ids' => $reordered])->assertOk()->assertJsonPath('data.0.id', $id);

        $this->as($this->editor, 'PATCH', "edu/content/categories/$id", ['status' => 'archived'])->assertOk();
        $this->assertNotContains($id, collect($this->as($this->student, 'GET', 'edu/categories')->json('data'))->pluck('id')->all(), 'archived is hidden');
        $this->as($this->editor, 'DELETE', "edu/content/categories/{$this->categoryId}")->assertStatus(409); // has subjects
        $this->as($this->editor, 'DELETE', "edu/content/categories/$id")->assertOk();
    }

    public function test_lessons_are_for_the_subjects_students_and_counts_are_real(): void
    {
        $l1 = $this->lesson(['title' => 'L1']);
        $this->lesson(['title' => 'Draft', 'status' => 'draft']);
        $outsider = $this->member();

        $cat = collect($this->as($this->student, 'GET', 'edu/categories')->json('data'))->firstWhere('id', $this->categoryId);
        $this->assertSame(1, $cat['subject_count'] >= 1 ? 1 : 0);
        $subject = collect($this->as($outsider, 'GET', "edu/categories/{$this->categoryId}/subjects")->json('data'))->firstWhere('id', $this->subjectId);
        $this->assertSame(1, $subject['lesson_count'], 'drafts are not counted');
        $this->assertFalse($subject['can_open']);

        $detail = $this->as($outsider, 'GET', "edu/subjects/{$this->subjectId}")->assertOk()->json('data');
        $this->assertCount(1, $detail['lessons'], 'titles are visible, drafts are not');
        $this->as($outsider, 'GET', "edu/lessons/$l1")->assertForbidden();
        $this->as($this->student, 'GET', "edu/lessons/$l1")->assertOk()->assertJsonPath('data.teacher_notes', null);

        // "members" subjects are open to everyone with Education on.
        $this->as($this->editor, 'PATCH', "edu/content/subjects/{$this->subjectId}", ['visibility' => 'members'])->assertOk();
        $this->as($outsider, 'GET', "edu/lessons/$l1")->assertOk();
    }

    public function test_active_teachers_write_lessons_for_their_subject_only(): void
    {
        $id = (int) $this->as($this->teacher, 'POST', "edu/subjects/{$this->subjectId}/lessons", ['title' => 'By teacher', 'teacher_notes' => 'secret', 'status' => 'published'])->assertCreated()->json('data.id');
        $this->as($this->teacher, 'GET', "edu/lessons/$id")->assertJsonPath('data.teacher_notes', 'secret');
        $this->as($this->student, 'GET', "edu/lessons/$id")->assertJsonPath('data.teacher_notes', null);
        $this->as($this->student, 'POST', "edu/subjects/{$this->subjectId}/lessons", ['title' => 'Nope'])->assertForbidden();
        $this->as($this->teacher, 'POST', 'edu/content/subjects', ['name' => 'Nope'])->assertForbidden();
        $this->assertTrue(DB::table('notifications')->where(['user_id' => $this->student->id, 'entity_type' => 'edu_lesson', 'entity_id' => $id])->exists(), 'students are told');

        $assignment = DB::table('edu_course_teachers')->where(['course_id' => $this->courseId, 'user_id' => $this->teacher->id])->value('id');
        $this->as($this->admin, 'PATCH', "edu/admin/course-teachers/$assignment", ['status' => 'suspended'])->assertOk();
        $this->as($this->teacher, 'PATCH', "edu/lessons/$id", ['title' => 'Changed'])->assertForbidden();
    }

    public function test_progress_sequential_lessons_and_continue_learning(): void
    {
        $l1 = $this->lesson(['title' => 'One']);
        $l2 = $this->lesson(['title' => 'Two']);
        $this->assertNull($this->as($this->student, 'GET', 'edu/me/dashboard')->assertOk()->json('data.continue'), 'nothing invented');

        $this->as($this->editor, 'PATCH', "edu/content/subjects/{$this->subjectId}", ['sequential' => true])->assertOk();
        $this->as($this->student, 'GET', "edu/lessons/$l2")->assertStatus(409)->assertJsonPath('code', 'LESSON_LOCKED');
        $this->as($this->student, 'GET', "edu/lessons/$l1")->assertOk()->assertJsonPath('data.next_id', $l2);
        $this->assertSame($l1, $this->as($this->student, 'GET', 'edu/me/dashboard')->json('data.continue.lesson_id'));

        $this->as($this->student, 'POST', "edu/lessons/$l1/progress", ['action' => 'complete'])->assertOk()->assertJsonPath('data.subject_progress.percent', 50);
        $this->assertSame($l2, $this->as($this->student, 'GET', 'edu/me/dashboard')->json('data.continue.lesson_id'), 'next lesson after the completed one');
        $this->as($this->student, 'GET', "edu/lessons/$l2")->assertOk();
        $this->as($this->student, 'POST', "edu/lessons/$l2/progress", ['action' => 'bookmark'])->assertOk()->assertJsonPath('data.bookmarked', true);
        $this->assertSame($l2, $this->as($this->student, 'GET', 'edu/me/bookmarks')->json('data.0.lesson_id'));
    }

    public function test_materials_are_private_to_those_who_may_open_the_lesson(): void
    {
        $l = $this->lesson();
        $pdf = UploadedFile::fake()->createWithContent('notes.pdf', "%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF");
        $m = $this->upload($this->editor, "edu/lessons/$l/materials", $pdf, ['title' => 'Notes'])->assertCreated()->json('data');
        $this->assertNull($m['url']);
        $path = DB::table('edu_lesson_materials')->where('id', $m['id'])->value('path');
        $this->assertStringStartsWith('private/', $path);

        $this->as($this->student, 'GET', "edu/materials/{$m['id']}/file")->assertOk();
        $this->as($this->member(), 'GET', "edu/materials/{$m['id']}/file")->assertForbidden();

        $exe = UploadedFile::fake()->createWithContent('x.pdf', "MZ\x90\x00 not a pdf");
        $this->upload($this->editor, "edu/lessons/$l/materials", $exe)->assertStatus(400);

        $this->as($this->editor, 'POST', "edu/lessons/$l/links", ['kind' => 'video_link', 'title' => 'Video', 'url' => 'javascript:alert(1)'])->assertStatus(422);
        $this->as($this->editor, 'POST', "edu/lessons/$l/links", ['kind' => 'video_link', 'title' => 'Video', 'url' => 'https://youtu.be/abc'])->assertCreated();
        $this->assertCount(2, $this->as($this->student, 'GET', "edu/lessons/$l")->json('data.materials'));

        $this->as($this->editor, 'DELETE', "edu/materials/{$m['id']}")->assertOk();
        // Opened by a student → archived, not deleted.
        $this->as($this->editor, 'DELETE', "edu/lessons/$l")->assertStatus(409);
    }

    // ---------------------------------------------------------------- quizzes

    private function quiz(array $attrs = [], array $questions = []): int
    {
        $id = (int) $this->as($this->teacher, 'POST', "edu/courses/{$this->courseId}/quizzes", $attrs + ['title' => 'Weekly quiz', 'max_attempts' => 1, 'review_policy' => 'after_close'])->assertCreated()->json('data.id');
        $this->as($this->teacher, 'PUT', "edu/quizzes/$id/questions", ['questions' => $questions ?: [
            ['type' => 'single', 'prompt' => 'Where was the first council?', 'options' => ['Jerusalem', 'Antioch', 'Rome'], 'answer' => 'a', 'points' => 2],
            ['type' => 'true_false', 'prompt' => 'Nicaea was in 325', 'answer' => true],
            ['type' => 'multiple', 'prompt' => 'Apostles', 'options' => ['Peter', 'Paul', 'Arius'], 'answer' => ['a', 'b']],
        ]])->assertOk();
        $this->as($this->teacher, 'PATCH', "edu/quizzes/$id", ['status' => 'published'])->assertOk();
        return $id;
    }

    public function test_quiz_eligibility_attempts_and_hidden_answers(): void
    {
        $id = $this->quiz();
        $this->as($this->member(), 'POST', "edu/quizzes/$id/attempts")->assertForbidden();

        $a = $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->assertOk()->json('data');
        foreach ($a['questions'] as $q) $this->assertArrayNotHasKey('answer', $q, 'answers never sent before the review time');
        $this->assertSame($a['id'], $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->json('data.id'), 'the attempt in progress is resumed, not duplicated');

        $byPrompt = collect($a['questions'])->keyBy('type');
        $this->as($this->student, 'PUT', "edu/attempts/{$a['id']}/answers", ['answers' => [['question_id' => $byPrompt['single']['id'], 'response' => 'z']]])->assertStatus(422);
        $this->as($this->student, 'POST', "edu/attempts/{$a['id']}/check", ['question_id' => $byPrompt['single']['id'], 'response' => 'a'])->assertForbidden(); // not a practice quiz
        $done = $this->as($this->student, 'POST', "edu/attempts/{$a['id']}/submit", ['answers' => [
            ['question_id' => $byPrompt['single']['id'], 'response' => 'a'],
            ['question_id' => $byPrompt['true_false']['id'], 'response' => false],
            ['question_id' => $byPrompt['multiple']['id'], 'response' => ['b', 'a']],
        ]])->assertOk()->json('data');
        $this->assertEquals(3, $done['score'], '2 + 0 + 1');
        $this->assertFalse($done['answers_visible'], 'after_close: not yet');
        $this->as($this->student, 'POST', "edu/attempts/{$a['id']}/submit")->assertOk()->assertJsonPath('data.score', 3); // idempotent
        $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->assertStatus(409)->assertJsonPath('code', 'NO_ATTEMPTS_LEFT');
        $this->assertSame(1, DB::table('edu_quiz_attempts')->where(['quiz_id' => $id, 'user_id' => $this->student->id])->count());

        $this->as($this->teacher, 'PATCH', "edu/quizzes/$id", ['status' => 'closed'])->assertOk();
        $after = $this->as($this->student, 'GET', "edu/attempts/{$a['id']}")->json('data');
        $this->assertTrue($after['answers_visible']);
        $this->assertSame('a', collect($after['questions'])->firstWhere('type', 'single')['answer']);
        $this->as($this->teacher, 'PUT', "edu/quizzes/$id/questions", ['questions' => [['type' => 'true_false', 'prompt' => 'x', 'answer' => true]]])->assertStatus(409);
        $this->as($this->teacher, 'DELETE', "edu/quizzes/$id")->assertStatus(409);
    }

    public function test_quiz_time_and_deadline_are_enforced(): void
    {
        $id = $this->quiz(['time_limit_minutes' => 5, 'max_attempts' => 2]);
        $a = $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->json('data');
        $this->assertNotNull($a['expires_at']);
        DB::table('edu_quiz_attempts')->where('id', $a['id'])->update(['expires_at' => now('UTC')->subMinutes(2)->format('Y-m-d H:i:s')]);
        $q = $a['questions'][0];
        $this->as($this->student, 'PUT', "edu/attempts/{$a['id']}/answers", ['answers' => [['question_id' => $q['id'], 'response' => null]]])->assertStatus(409)->assertJsonPath('code', 'ATTEMPT_EXPIRED');
        $this->assertNotSame('in_progress', $this->as($this->student, 'GET', "edu/attempts/{$a['id']}")->json('data.status'), 'finished with what was saved');

        DB::table('edu_quizzes')->where('id', $id)->update(['closes_at' => now('UTC')->subMinute()->format('Y-m-d H:i:s')]);
        $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->assertStatus(409)->assertJsonPath('code', 'QUIZ_CLOSED');
        $upcoming = $this->quiz(['opens_at' => now('UTC')->addDay()->toIso8601String()]);
        $this->as($this->student, 'POST', "edu/quizzes/$upcoming/attempts")->assertStatus(409)->assertJsonPath('code', 'QUIZ_NOT_OPEN');
    }

    public function test_quiz_scores_become_official_only_through_review_and_publication(): void
    {
        $assessment = (int) $this->as($this->teacher, 'POST', "edu/courses/{$this->courseId}/assessments", ['title' => 'Quiz mark', 'max_score' => 20])->json('data.id');
        $id = $this->quiz(['assessment_id' => $assessment, 'review_policy' => 'after_submit'], [
            ['type' => 'single', 'prompt' => 'Q', 'options' => ['A', 'B'], 'answer' => 'a', 'points' => 1],
            ['type' => 'short_text', 'prompt' => 'Explain', 'points' => 1],
        ]);
        $a = $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->json('data');
        $qs = collect($a['questions'])->keyBy('type');
        $done = $this->as($this->student, 'POST', "edu/attempts/{$a['id']}/submit", ['answers' => [
            ['question_id' => $qs['single']['id'], 'response' => 'a'],
            ['question_id' => $qs['short_text']['id'], 'response' => 'Because…'],
        ]])->json('data');
        $this->assertNull($done['score'], 'a linked quiz shows no score before the mark is published');
        $this->assertTrue($done['score_hidden']);

        // Written answer waits for the teacher; transfer skips it until graded.
        $this->as($this->teacher, 'POST', "edu/quizzes/$id/transfer")->assertOk()->assertJsonPath('data.pending_grading', 1)->assertJsonPath('data.transferred', 0);
        $this->as($this->teacher, 'PUT', "edu/quiz-attempts/{$a['id']}/grade", ['question_id' => $qs['short_text']['id'], 'points' => 2])->assertStatus(422);
        $this->as($this->teacher, 'PUT', "edu/quiz-attempts/{$a['id']}/grade", ['question_id' => $qs['short_text']['id'], 'points' => 0.5])->assertOk();
        $this->as($this->teacher, 'POST', "edu/quizzes/$id/transfer")->assertOk()->assertJsonPath('data.transferred', 1);

        $mark = DB::table('edu_scores')->where(['assessment_id' => $assessment, 'user_id' => $this->student->id])->first();
        $this->assertSame('draft', $mark->status, 'enters the score sheet as a draft');
        $this->assertSame('15.00', (string) $mark->score, '1.5 / 2 scaled to 20');
        $this->assertTrue(DB::table('edu_score_history')->where(['assessment_id' => $assessment, 'user_id' => $this->student->id, 'action' => 'entered'])->exists());
        $results = $this->as($this->student, 'GET', "edu/classes/{$this->classId}/my-results")->json('data.courses.0.assessments');
        $this->assertNull(collect($results)->firstWhere('id', $assessment)['score'], 'not official yet');

        $this->as($this->teacher, 'POST', "edu/assessments/$assessment/submit")->assertOk();
        $this->as($this->admin, 'POST', "edu/admin/assessments/$assessment/review", ['decision' => 'approve', 'publish' => true])->assertOk();
        $this->assertEquals(1.5, collect($this->as($this->student, 'GET', 'edu/me/quizzes')->json('data'))->firstWhere('id', $id)['my_score']);
        $this->as($this->teacher, 'POST', "edu/quizzes/$id/transfer")->assertOk()->assertJsonPath('data.locked', 1); // published marks are never overwritten
    }

    public function test_practice_quiz_checks_one_answer_at_a_time(): void
    {
        $id = $this->quiz(['review_policy' => 'practice', 'max_attempts' => 3]);
        $a = $this->as($this->student, 'POST', "edu/quizzes/$id/attempts")->json('data');
        $single = collect($a['questions'])->firstWhere('type', 'single');
        $this->as($this->student, 'POST', "edu/attempts/{$a['id']}/check", ['question_id' => $single['id'], 'response' => 'b'])->assertOk()->assertJsonPath('data.correct', false)->assertJsonPath('data.answer', 'a');
    }

    // ---------------------------------------------------------------- dashboard

    public function test_dashboard_blocks_follow_real_responsibilities(): void
    {
        $outsider = $this->member();
        $d = $this->as($outsider, 'GET', 'edu/me/dashboard')->assertOk()->json('data');
        $this->assertNull($d['student']);
        $this->assertNull($d['teaching']);
        $this->assertNull($d['admin']);
        $this->assertGreaterThanOrEqual(4, count($d['categories']));

        $s = $this->as($this->student, 'GET', 'edu/me/dashboard')->json('data');
        $this->assertTrue($s['roles']['student']);
        $this->assertNotNull($s['student']);
        $this->assertNull($s['admin']);

        $t = $this->as($this->teacher, 'GET', 'edu/me/dashboard')->json('data');
        $this->assertTrue($t['roles']['teacher']);
        $this->assertTrue($t['roles']['author']);
        $this->assertNotNull($t['teaching']);

        $this->assertNotNull($this->as($this->admin, 'GET', 'edu/me/dashboard')->json('data.admin'));
        $this->as($this->student, 'GET', 'edu/me/progress')->assertOk();
        $this->as($this->student, 'GET', 'edu/search?q=Church')->assertOk()->assertJsonPath('data.subjects.0.id', $this->subjectId);
    }

    public function test_featured_banner_points_at_real_published_content(): void
    {
        $l = $this->lesson(['title' => 'Featured lesson']);
        $this->as($this->student, 'POST', 'edu/content/featured', ['target_type' => 'lesson', 'target_id' => $l])->assertForbidden();
        $this->as($this->editor, 'POST', 'edu/content/featured', ['target_type' => 'lesson', 'target_id' => 999999])->assertStatus(422);
        $this->as($this->editor, 'POST', 'edu/content/featured', ['target_type' => 'lesson', 'target_id' => $l, 'subtitle' => 'Start here'])->assertCreated();
        $f = collect($this->as($this->student, 'GET', 'edu/featured')->json('data'))->firstWhere('target_id', $l);
        $this->assertSame("/edu/learn/lesson/$l", $f['target']['route']);
        $this->assertSame('Featured lesson', $f['title']);

        $this->as($this->editor, 'PATCH', "edu/lessons/$l", ['status' => 'archived'])->assertOk();
        $this->assertNull(collect($this->as($this->student, 'GET', 'edu/featured')->json('data'))->firstWhere('target_id', $l), 'unpublished targets are not advertised');
    }
}
