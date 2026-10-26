import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_script = """<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

use App\\Mz\\Auth\\AuthContext;
use App\\Mz\\Services\\EduScores;

try {
    $authContext = AuthContext::load(1);
    echo "AuthContext loaded for user 1 (high_admin):\\n";
    echo "  isSuperAdmin: " . ($authContext->isSuperAdmin() ? 'YES' : 'NO') . "\\n";

    echo "\\nExecuting EduScores::forPeriod...\\n";
    $scores = EduScores::forPeriod($authContext);
    echo "EduScores::forPeriod SUCCESS! Count=" . count($scores) . "\\n";
    if (count($scores) > 0) {
        echo "Sample score item: " . json_encode($scores[0]) . "\\n";
    }

    echo "\\nExecuting EduScores::activityReport...\\n";
    $activity = EduScores::activityReport($authContext);
    echo "EduScores::activityReport SUCCESS! Metrics count=" . count($activity) . "\\n";
    if (count($activity) > 0) {
        echo "Sample activity item: " . json_encode($activity[0]) . "\\n";
    }

} catch (Throwable $e) {
    echo "EXCEPTION: " . get_class($e) . ": " . $e->getMessage() . "\\n";
    echo "File: " . $e->getFile() . ":" . $e->getLine() . "\\n";
    echo "Trace:\\n" . $e->getTraceAsString() . "\\n";
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/test_scores_remote3.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/test_scores_remote3.php && rm -f /home/hersolot/app.hersolan.pro/test_scores_remote3.php")
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
