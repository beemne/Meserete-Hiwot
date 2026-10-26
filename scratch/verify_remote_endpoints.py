import paramiko
import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_test = '''<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

use App\\Mz\\Auth\\AuthContext;
use App\\Mz\\Services\\EduScores;
use App\\Mz\\Services\\Diagnostics;
use App\\Mz\\Services\\Sinksar;
use Illuminate\\Support\\Facades\\DB;

// 1. Find Super Admin user (role slug high_admin or role_id 2)
$adminUser = DB::table('users as u')
    ->join('roles as r', 'r.id', '=', 'u.role_id')
    ->where('r.slug', 'high_admin')
    ->where('u.status', 'active')
    ->first(['u.id', 'u.full_name', 'r.slug as role_slug']);

if (!$adminUser) {
    $adminUser = DB::table('users')->where('status', 'active')->where('role_id', 2)->first(['id', 'full_name']);
}

$auth = AuthContext::load($adminUser->id);

// 2. Test EduScores::forPeriod (The fix for "Something went wrong")
$scoresError = null;
$scoresCount = 0;
try {
    $scores = EduScores::forPeriod($auth);
    $scoresCount = count($scores);
} catch (\\Throwable $e) {
    $scoresError = $e->getMessage();
}

// 3. Test Diagnostics report submission & dashboard retrieval
$diagError = null;
$diagSubmitId = null;
$diagListCount = 0;
try {
    $subRes = Diagnostics::submitReport(
        $auth,
        [
            'module' => 'education',
            'screen' => '/edu/admin/scores',
            'error_message' => 'Integration test verification report',
            'severity' => 'info',
            'diagnostic_data' => ['tester' => 'automated_integration_test']
        ]
    );
    $diagSubmitId = $subRes['id'] ?? null;

    $listRes = Diagnostics::listReports($auth, ['page' => 1, 'limit' => 5]);
    $diagListCount = $listRes['meta']['total'] ?? 0;
} catch (\\Throwable $e) {
    $diagError = $e->getMessage();
}

// 4. Test Sinksar daily data & upstream parsing
$sinksarError = null;
$sinksarData = null;
try {
    $day = Sinksar::getDay('2026-10-25');
    $sinksarData = [
        'ethiopian_date' => $day['ethiopian_date'] ?? null,
        'feasts_count' => count($day['feasts'] ?? []),
        'fasting' => $day['fasting'] ?? null,
        'has_readings' => !empty($day['readings']),
    ];
} catch (\\Throwable $e) {
    $sinksarError = $e->getMessage();
}

// 5. Test Sinksar test notification endpoint
$notifError = null;
$notifRes = null;
try {
    $notifRes = Sinksar::sendTestNotification($auth);
} catch (\\Throwable $e) {
    $notifError = $e->getMessage();
}

echo json_encode([
    'admin_user' => [
        'id' => $adminUser->id,
        'name' => $adminUser->full_name,
        'is_super_admin' => $auth->isSuperAdmin(),
    ],
    'scores_and_activity' => [
        'success' => $scoresError === null,
        'error' => $scoresError,
        'scores_returned' => $scoresCount,
    ],
    'diagnostics_pipeline' => [
        'success' => $diagError === null,
        'submitted_id' => $diagSubmitId,
        'total_reports' => $diagListCount,
        'error' => $diagError,
    ],
    'sinksar' => [
        'success' => $sinksarError === null,
        'data' => $sinksarData,
        'error' => $sinksarError,
    ],
    'test_notification' => [
        'success' => $notifError === null,
        'result' => $notifRes,
        'error' => $notifError,
    ],
], JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
''';

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/verify_test.php', 'w') as f:
    f.write(php_test)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('php /home/hersolot/app.hersolan.pro/verify_test.php && rm -f /home/hersolot/app.hersolan.pro/verify_test.php')
out = stdout.read().decode('utf-8', errors='replace')
print("REMOTE INTEGRATION RESULTS:\n", out)
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print("REMOTE STDERR:\n", err)

ssh.close()
