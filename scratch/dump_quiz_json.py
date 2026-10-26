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

$auth = AuthContext::load(1);

$tq = EduQuizzes::teacherQuiz($auth, 16);
$qd = EduQuizzes::quizDetail($auth, 16);
$qr = EduQuizzes::results($auth, 16);

echo "=== TEACHER_QUIZ (quiz-edit) ===\\n";
echo json_encode($tq, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";

echo "=== QUIZ_DETAIL (quiz preview) ===\\n";
echo json_encode($qd, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";

echo "=== QUIZ_RESULTS (quiz-results) ===\\n";
echo json_encode($qr, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";
'''

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/dump_quiz.php', 'w') as f:
    f.write(php_test)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('cd /home/hersolot/app.hersolan.pro && php dump_quiz.php && rm -f dump_quiz.php')
out = stdout.read().decode('utf-8')
print(out)
ssh.close()
