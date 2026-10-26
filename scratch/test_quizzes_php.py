import paramiko
import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_test = '''<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

use App\\Mz\\Auth\\AuthContext;
use App\\Mz\\Services\\EduQuizzes;
use Illuminate\\Support\\Facades\\DB;

$auth = AuthContext::load(1);
$results = [];

foreach ([16, 6, 4] as $qid) {
    $res = ['quiz_id' => $qid];
    
    // 1. teacherQuiz (called by quiz-edit)
    try {
        $tq = EduQuizzes::teacherQuiz($auth, $qid);
        $res['teacher_quiz'] = ['ok' => true, 'questions_count' => count($tq['questions'] ?? [])];
    } catch (\\Throwable $e) {
        $res['teacher_quiz'] = ['ok' => false, 'error' => $e->getMessage()];
    }

    // 2. quizDetail (called by quiz preview)
    try {
        $qd = EduQuizzes::quizDetail($auth, $qid);
        $res['quiz_detail'] = ['ok' => true, 'can_edit' => $qd['can_edit'] ?? false];
    } catch (\\Throwable $e) {
        $res['quiz_detail'] = ['ok' => false, 'error' => $e->getMessage()];
    }

    // 3. results (called by quiz results)
    try {
        $qr = EduQuizzes::results($auth, $qid);
        $res['results'] = ['ok' => true, 'students_count' => count($qr['students'] ?? [])];
    } catch (\\Throwable $e) {
        $res['results'] = ['ok' => false, 'error' => $e->getMessage()];
    }

    $results[$qid] = $res;
}

echo json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
'''

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/test_quizzes.php', 'w') as f:
    f.write(php_test)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('cd /home/hersolot/app.hersolan.pro && php test_quizzes.php && rm -f test_quizzes.php')
out = stdout.read().decode('utf-8')
err = stderr.read().decode('utf-8')
print("OUTPUT:\n", out)
if err:
    print("STDERR:\n", err)

ssh.close()
