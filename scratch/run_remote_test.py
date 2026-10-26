import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

sftp = ssh.open_sftp()
sftp.put('laravel/app/Mz/Services/EduScores.php', '/home/hersolot/app.hersolan.pro/app/Mz/Services/EduScores.php')
sftp.put('laravel/app/Mz/Services/EduLearning.php', '/home/hersolot/app.hersolan.pro/app/Mz/Services/EduLearning.php')

php_script = '''<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

$u = DB::table('users')->where('status', 'active')->first(['id', 'phone', 'full_name', 'role_id', 'member_type']);
$auth = \\App\\Mz\\Auth\\AuthContext::load($u->id);
$calc = \\App\\Mz\\Services\\ContributionReceipts::calculateExpected($u->id, '2019-02', 3);
$studentScores = \\App\\Mz\\Services\\EduScores::forStudent($auth, $u->id);
$adminReceipts = \\App\\Mz\\Services\\ContributionReceipts::adminList([], ['page' => 1, 'limit' => 5]);
$searchRes = \\App\\Mz\\Services\\EduLearning::search($auth, 'ሃይማኖት');

echo json_encode([
    'user' => [
        'id' => $u->id,
        'name' => $u->full_name,
        'role_id' => $u->role_id,
        'member_type' => $u->member_type,
    ],
    'contribution_calc' => [
        'months' => $calc['months'],
        'expected_amount' => $calc['expected_amount'],
        'currency' => $calc['currency'],
    ],
    'student_scores' => [
        'student_id' => $studentScores['student']['id'] ?? null,
        'student_name' => $studentScores['student']['name'] ?? null,
        'outcomes_count' => count($studentScores['outcomes'] ?? []),
        'quizzes_count' => count($studentScores['quizzes'] ?? []),
    ],
    'search' => [
        'subjects' => count($searchRes['subjects'] ?? []),
        'courses' => count($searchRes['courses'] ?? []),
        'lessons' => count($searchRes['lessons'] ?? []),
    ],
    'receipts_queue' => [
        'total' => $adminReceipts['meta']['total'] ?? 0,
    ],
]);
'''

with sftp.file('/home/hersolot/app.hersolan.pro/test_live_runner.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('php /home/hersolot/app.hersolan.pro/test_live_runner.php && rm -f /home/hersolot/app.hersolan.pro/test_live_runner.php')
out = stdout.read().decode('utf-8', errors='replace')
print("LIVE RUNNER OUTPUT:\n", out)
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print("ERR:\n", err)

ssh.close()
