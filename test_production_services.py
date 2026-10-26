import paramiko
import sys
import json

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = 'v:89]yYLi:7t7O0E)0*'
TARGET_DIR = f'/home/{SSH_USER}/app.{SERVER_HOST}'

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS)

tests = [
    (
        "Library::books excludes general property items",
        """
        $auth = \\App\\Mz\\Auth\\AuthContext::load(1);
        $page = \\App\\Mz\\Support\\Page::params(['page' => 1, 'limit' => 20]);
        $books = \\App\\Mz\\Services\\Library::books($auth, [], $page);
        $items = $books['items'] ?? [];
        echo json_encode(['book_count' => count($items), 'total' => $books['meta']['total']]);
        """
    ),
    (
        "Borrowing digital book throws DIGITAL_NOT_BORROWABLE",
        """
        $auth = \\App\\Mz\\Auth\\AuthContext::load(1);
        $actx = ['auth' => $auth];
        $testId = DB::table('items')->insertGetId([
            'name' => 'የሙከራ ዲጂታል መጽሐፍ',
            'kind' => 'digital',
            'category' => 'books',
            'domain' => 'timhirt',
            'quantity' => 1,
            'available_quantity' => 1,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now()
        ]);
        try {
            \\App\\Mz\\Services\\Borrowings::create($actx, [
                'user_id' => 1,
                'item_id' => $testId,
                'quantity' => 1,
                'days' => 7
            ]);
            DB::table('items')->where('id', $testId)->delete();
            echo json_encode(['result' => 'borrowed_unexpectedly']);
        } catch (\\App\\Mz\\Support\\ApiError $err) {
            DB::table('items')->where('id', $testId)->delete();
            echo json_encode(['result' => 'guard_verified', 'code' => $err->errorCode, 'message' => $err->getMessage()]);
        } catch (\\Throwable $e) {
            DB::table('items')->where('id', $testId)->delete();
            echo json_encode(['result' => 'exception', 'msg' => $e->getMessage()]);
        }
        """
    ),
    (
        "EduQuizzes attempt limit enforcement & grading feedback persistence",
        """
        try {
            $auth = \\App\\Mz\\Auth\\AuthContext::load(1);
            $actx = ['auth' => $auth];
            $quizId = DB::table('edu_quizzes')->insertGetId([
                'title' => 'የሙከራ ፈተና - Production Verify',
                'status' => 'published',
                'max_attempts' => 1,
                'scoring' => 'best',
                'shuffle' => 0,
                'review_policy' => 'after_submit',
                'created_at' => now(),
                'updated_at' => now()
            ]);
            $qId = DB::table('edu_quiz_questions')->insertGetId([
                'quiz_id' => $quizId,
                'type' => 'short_text',
                'prompt' => 'የሙከራ ጥያቄ',
                'points' => 10.0
            ]);

            $att1 = \\App\\Mz\\Services\\EduQuizzes::start($auth, $quizId);
            \\App\\Mz\\Services\\EduQuizzes::submit($auth, $att1['id'], [
                ['question_id' => $qId, 'response' => 'መልስ']
            ]);

            \\App\\Mz\\Services\\EduQuizzes::gradeAnswer($actx, $att1['id'], $qId, 9.5, 'እጅግ በጣም ጥሩ!');

            $ans = DB::table('edu_quiz_answers')->where(['attempt_id' => $att1['id'], 'question_id' => $qId])->first();
            $persisted = [
                'points_awarded' => (float) $ans->points_awarded,
                'feedback' => $ans->feedback,
                'has_graded_at' => !is_null($ans->graded_at),
                'graded_by' => (int) $ans->graded_by
            ];

            $attempt2Blocked = false;
            try {
                \\App\\Mz\\Services\\EduQuizzes::start($auth, $quizId);
            } catch (\\App\\Mz\\Support\\ApiError $e) {
                $attempt2Blocked = ($e->errorCode === 'NO_ATTEMPTS_LEFT');
            }

            DB::table('edu_quiz_answers')->where('attempt_id', $att1['id'])->delete();
            DB::table('edu_quiz_attempts')->where('id', $att1['id'])->delete();
            DB::table('edu_quiz_questions')->where('quiz_id', $quizId)->delete();
            DB::table('edu_quizzes')->where('id', $quizId)->delete();

            echo json_encode([
                'persisted' => $persisted,
                'attempt2_blocked' => $attempt2Blocked
            ]);
        } catch (\\Throwable $e) {
            echo json_encode(['err' => $e->getMessage(), 'line' => $e->getLine()]);
        }
        """
    )
]

print("=== Running Refined Library & Borrowing Tests on Production ===")
for name, php_code in tests:
    clean_code = " ".join(php_code.strip().split())
    escaped_code = clean_code.replace('\\', '\\\\').replace('$', '\\$').replace('"', '\\"')
    cmd = f'php {TARGET_DIR}/artisan tinker --execute="{escaped_code}"'
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    err = stderr.read().decode('utf-8', errors='replace').strip()
    print(f"\n[{name}]")
    print("OUTPUT:", out)
    if err:
        print("STDERR:", err)

ssh.close()
print("\n=== Verification Completed ===")
