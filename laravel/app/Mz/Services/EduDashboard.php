<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use Illuminate\Support\Facades\DB;

/**
 * The ትምህርት home in one request: the blocks of every responsibility the member really has
 * (student, teacher, attendance taker, registrar, content editor, education administrator), each
 * computed from the records — no sample or invented numbers. A block the member has no part in is
 * null / empty, so the app shows a helpful empty state instead.
 */
final class EduDashboard
{
    public static function forUser(AuthContext $auth): array
    {
        $overview = Edu::overview($auth);
        $courseIds = Edu::myCourseIds($auth->id);
        $teachingIds = Edu::myTeachingCourseIds($auth->id);
        $isAdmin = $auth->can('education.manage');

        return [
            'featured' => EduLearning::featured($auth),
            'categories' => EduLearning::categories($auth),
            'continue' => EduLearning::continueLearning($auth),
            'classes' => $overview['classes'],
            'next_sessions' => $overview['next_sessions'],
            'open_registration' => $overview['open_registration'],
            'student' => $courseIds || $overview['classes'] ? self::student($auth, $overview['classes'], $courseIds) : null,
            'teaching' => $teachingIds ? self::teaching($overview['teaching'], $teachingIds) : null,
            'attendance_classes' => $overview['attendance_classes'],
            'admin' => $isAdmin ? self::admin() : null,
            'roles' => [
                'student' => (bool) $courseIds,
                'teacher' => (bool) $teachingIds,
                'attendance_taker' => (bool) $overview['attendance_classes'],
                'registrar' => $auth->can('education.register') || $isAdmin,
                'content_editor' => EduLearning::isEditor($auth),
                'admin' => $isAdmin,
                'author' => EduLearning::isEditor($auth) || (bool) EduLearning::teachingSubjectIds($auth->id),
            ],
        ];
    }

    private static function student(AuthContext $auth, array $classes, array $courseIds): array
    {
        $now = Dates::sql(Dates::now());
        // Assignments of the subjects taken: not yet submitted, newest deadline first (overdue kept a week).
        $weekAgo = Dates::sql(Dates::of($now)->modify('-7 days'));
        $assignments = $courseIds ? DB::table('edu_assignments as a')->join('edu_courses as co', 'co.id', '=', 'a.course_id')
            ->whereIn('a.course_id', $courseIds)
            ->where(fn ($w) => $w->whereNull('a.due_at')->orWhere('a.due_at', '>=', $weekAgo))
            ->select('a.id', 'a.title', 'a.due_at', 'a.course_id', 'a.is_group', 'co.name as course_name', 'co.class_id')
            ->orderByRaw('a.due_at IS NULL')->orderBy('a.due_at')->limit(40)->get() : collect();
        $groups = DB::table('edu_group_members as gm')->join('edu_groups as g', 'g.id', '=', 'gm.group_id')->where('gm.user_id', $auth->id)->pluck('g.id', 'g.course_id')->all();
        $due = [];
        foreach ($assignments as $a) {
            $g = $groups[$a->course_id] ?? null;
            $sub = DB::table('edu_submissions')->where('assignment_id', $a->id)
                ->where(fn ($w) => $a->is_group && $g ? $w->where('group_id', $g)->orWhere('user_id', $auth->id) : $w->where('user_id', $auth->id))->first(['id', 'graded_at']);
            if ($sub) continue;
            $due[] = ['id' => (int) $a->id, 'title' => $a->title, 'due_at' => $a->due_at, 'course_id' => (int) $a->course_id, 'course_name' => $a->course_name, 'class_id' => (int) $a->class_id,
                'overdue' => $a->due_at !== null && Dates::sql($a->due_at) < $now];
            if (count($due) >= 10) break;
        }
        $quizzes = array_values(array_filter(EduQuizzes::mine($auth), fn ($q) => $q['availability'] !== 'closed' && ($q['attempts_left'] > 0 || $q['in_progress_attempt_id'])));
        $attendance = [];
        foreach ($classes as $c) {
            if (! empty($c['added_subjects_only'])) continue;
            $s = Edu::attendanceSummary((int) $c['id'], $auth->id);
            $attendance[] = ['class_id' => (int) $c['id'], 'class_name' => $c['name'], 'rate' => $s['rate'], 'total' => $s['total'], 'present' => $s['present'], 'late' => $s['late'], 'absent' => $s['absent'], 'excused' => $s['excused']];
        }
        // Only published marks — never drafts or marks under review.
        $results = DB::table('edu_scores as s')->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')->join('edu_courses as co', 'co.id', '=', 'a.course_id')
            ->where(['s.user_id' => $auth->id, 's.status' => 'published'])->whereNotNull('s.score')
            ->orderByDesc('s.published_at')->limit(5)
            ->get(['a.id as assessment_id', 'a.title', 'a.max_score', 's.score', 's.published_at', 'co.id as course_id', 'co.name as course_name', 'co.class_id'])
            ->map(fn ($r) => ['assessment_id' => (int) $r->assessment_id, 'title' => $r->title, 'score' => Num::n($r->score), 'max_score' => Num::n($r->max_score),
                'course_id' => (int) $r->course_id, 'course_name' => $r->course_name, 'class_id' => (int) $r->class_id, 'published_at' => $r->published_at])->all();
        // Academic period (F1)
        $primaryClassId = ! empty($classes) ? (int) $classes[0]['id'] : null;
        $classRow = $primaryClassId ? DB::table('edu_classes')->where('id', $primaryClassId)->first() : null;
        $yearRow = $classRow && $classRow->academic_year_id ? DB::table('edu_academic_years')->where('id', $classRow->academic_year_id)->first() : DB::table('edu_academic_years')->where('is_current', 1)->first();
        $termRow = $classRow && $classRow->term_id ? DB::table('edu_terms')->where('id', $classRow->term_id)->first() : null;
        $levelRow = $classRow && $classRow->level_id ? DB::table('edu_levels')->where('id', $classRow->level_id)->first() : null;
        $academicPeriod = $yearRow ? [
            'year_id' => (int) $yearRow->id,
            'year_name' => $yearRow->name,
            'eth_year' => (int) $yearRow->eth_year,
            'is_current' => (bool) $yearRow->is_current,
            'term_id' => $termRow ? (int) $termRow->id : null,
            'term_name' => $termRow ? $termRow->name : null,
            'level_id' => $levelRow ? (int) $levelRow->id : null,
            'level_name' => $levelRow ? $levelRow->name : null,
        ] : null;

        // Outcomes (F10), retakes (F11), certificates (F13)
        $outcomes = EduOutcomes::forStudent($auth);
        $retakes = EduRetakes::list($auth, ['user_id' => $auth->id]);
        $certificates = EduCertificates::myCertificates($auth->id);

        return [
            'academic_period' => $academicPeriod,
            'assignments_due' => $due,
            'quizzes' => array_slice($quizzes, 0, 10),
            'attendance' => $attendance,
            'results' => $results,
            'outcomes' => $outcomes,
            'retakes' => $retakes,
            'certificates' => $certificates,
            'subject_count' => count($courseIds),
        ];
    }

    private static function teaching(array $courses, array $teachingIds): array
    {
        $ungraded = DB::table('edu_submissions as s')->join('edu_assignments as a', 'a.id', '=', 's.assignment_id')->whereIn('a.course_id', $teachingIds)->whereNull('s.graded_at')->count();
        $rejected = DB::table('edu_scores as s')->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')->whereIn('a.course_id', $teachingIds)->where('s.status', 'rejected')->count();
        $drafts = DB::table('edu_scores as s')->join('edu_assessments as a', 'a.id', '=', 's.assessment_id')->whereIn('a.course_id', $teachingIds)->where('s.status', 'draft')->whereNotNull('s.score')->count();
        $quizGrading = DB::table('edu_quiz_attempts as qa')->join('edu_quizzes as q', 'q.id', '=', 'qa.quiz_id')->whereIn('q.course_id', $teachingIds)->where('qa.needs_grading', 1)->count();
        return [
            'courses' => $courses,
            'submissions_to_grade' => $ungraded,
            'marks_rejected' => $rejected,
            'marks_draft' => $drafts,
            'quiz_answers_to_grade' => $quizGrading,
        ];
    }

    private static function admin(): array
    {
        return [
            'marks_submitted' => DB::table('edu_scores')->where('status', 'submitted')->distinct()->count('assessment_id'),
            'marks_approved_unpublished' => DB::table('edu_scores')->where('status', 'approved')->distinct()->count('assessment_id'),
            'requests_pending' => DB::table('edu_requests')->where('status', 'pending')->count(),
            'complaints_open' => DB::table('edu_complaints')->whereIn('status', ['submitted', 'under_review', 'awaiting_information', 'escalated'])->count(),
            'classes_active' => DB::table('edu_classes')->where('status', 'active')->count(),
            'subjects_unlinked' => DB::table('edu_courses as co')->join('edu_classes as c', 'c.id', '=', 'co.class_id')->where('c.status', 'active')->whereNull('co.subject_id')->count(),
        ];
    }

    /** Progress page: per class attendance + published results, lesson completion per subject, journey count. */
    public static function progress(AuthContext $auth): array
    {
        $overview = Edu::overview($auth);
        $classes = [];
        foreach ($overview['classes'] as $c) {
            $r = Edu::myResults($auth, (int) $c['id']);
            $classes[] = ['class' => $c, 'attendance' => $r['attendance'], 'courses' => $r['courses']];
        }
        $subjects = array_values(array_filter(EduLearning::subjects($auth, null), fn ($s) => $s['my_progress']['completed'] > 0 || $s['enrolled']));
        return [
            'classes' => $classes,
            'subjects' => array_map(fn ($s) => ['id' => $s['id'], 'name' => $s['name'], 'name_en' => $s['name_en'], 'progress' => $s['my_progress'], 'enrolled' => $s['enrolled']], $subjects),
            'quizzes' => array_values(array_filter(EduQuizzes::mine($auth), fn ($q) => $q['attempts_used'] > 0)),
            'bookmarks' => EduLearning::bookmarks($auth),
        ];
    }
}
