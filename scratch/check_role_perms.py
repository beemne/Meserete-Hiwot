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

use Illuminate\\Support\\Facades\\DB;
use App\\Mz\\Auth\\AuthContext;

$rp = DB::table('role_permissions as rp')
    ->join('roles as r', 'r.id', '=', 'rp.role_id')
    ->select('r.id', 'r.slug', 'r.name', 'rp.permission')
    ->get()
    ->groupBy('slug');

foreach ($rp as $slug => $perms) {
    echo "Role: $slug (total " . count($perms) . " perms):\\n";
    $pList = $perms->pluck('permission')->all();
    echo "  " . implode(', ', array_slice($pList, 0, 15)) . (count($pList) > 15 ? "..." : "") . "\\n";
}

echo "\\n--- Testing AuthContext for all admin users ---\\n";
$users = DB::table('users')->whereNotNull('role_id')->get();
foreach ($users as $u) {
    $ctx = AuthContext::load($u->id);
    if ($ctx) {
        echo "User {$u->id} ({$u->full_name}): role={$ctx->role['slug']}, isSuperAdmin=" . ($ctx->isSuperAdmin() ? 'YES' : 'NO') . ", can(education.reports)=" . ($ctx->can('education.reports') ? 'YES' : 'NO') . ", can(education.manage)=" . ($ctx->can('education.manage') ? 'YES' : 'NO') . "\\n";
    }
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/check_role_perms.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/check_role_perms.php && rm -f /home/hersolot/app.hersolan.pro/check_role_perms.php")
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
