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
use Illuminate\\Support\\Facades\\DB;

try {
    // Find an admin user or super admin
    $user = DB::table('users')->where('role', 'admin')->orWhere('role', 'high_admin')->first();
    if (!$user) {
        $user = DB::table('users')->first();
    }
    echo "Testing with user: ID={$user->id}, role={$user->role}, name={$user->full_name}\\n";

    $roles = DB::table('role_user')
        ->join('roles', 'roles.id', '=', 'role_user.role_id')
        ->where('role_user.user_id', $user->id)
        ->pluck('roles.slug')
        ->all();
    echo "Assigned roles: " . implode(', ', $roles) . "\\n";

    // Build AuthContext
    $auth = App\\Mz\\Auth\\Tokens::signAccess($user);
    $authContext = App\\Mz\\Auth\\Tokens::verifyAccess($auth['token']);

    echo "Calling EduScores::forPeriod...\\n";
    $scores = EduScores::forPeriod($authContext);
    echo "EduScores::forPeriod SUCCESS! Count=" . count($scores) . "\\n";
    if (count($scores) > 0) {
        echo "Sample score: " . json_encode($scores[0]) . "\\n";
    }

    echo "Calling EduScores::activityReport...\\n";
    $activity = EduScores::activityReport($authContext);
    echo "EduScores::activityReport SUCCESS! Keys=" . implode(', ', array_keys($activity)) . "\\n";
    echo "Activity data: " . json_encode($activity) . "\\n";

} catch (Throwable $e) {
    echo "EXCEPTION: " . get_class($e) . ": " . $e->getMessage() . "\\n";
    echo "Trace:\\n" . $e->getTraceAsString() . "\\n";
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/test_scores_remote.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/test_scores_remote.php && rm -f /home/hersolot/app.hersolan.pro/test_scores_remote.php")
output = stdout.read().decode('utf-8', errors='replace')
print("REMOTE OUTPUT:\n" + output)
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print("REMOTE ERROR:\n" + err)
ssh.close()
