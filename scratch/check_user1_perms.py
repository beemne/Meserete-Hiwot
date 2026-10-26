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
use Illuminate\\Support\\Facades\\DB;

$ctx = AuthContext::load(1);
echo "User 1 AuthContext:\\n";
echo "  name: " . ($ctx ? $ctx->name : 'null') . "\\n";
echo "  isAdmin: " . ($ctx ? ($ctx->isAdmin ? 'true' : 'false') : 'null') . "\\n";
echo "  level: " . ($ctx ? $ctx->level : 'null') . "\\n";
echo "  role: " . json_encode($ctx ? $ctx->role : null) . "\\n";
echo "  isSuperAdmin(): " . ($ctx ? ($ctx->isSuperAdmin() ? 'TRUE' : 'FALSE') : 'null') . "\\n";
echo "  permissions count: " . ($ctx ? count($ctx->permissions) : 0) . "\\n";
echo "  permissions: " . json_encode($ctx ? array_keys($ctx->permissions) : []) . "\\n";
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/test_user1.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/test_user1.php && rm -f /home/hersolot/app.hersolan.pro/test_user1.php")
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
