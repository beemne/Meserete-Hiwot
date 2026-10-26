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

$cols = DB::select("SHOW COLUMNS FROM users");
foreach ($cols as $c) {
    echo $c->Field . " (" . $c->Type . ")\\n";
}

$roles = DB::select("SELECT * FROM roles");
echo "\\nROLES:\\n";
foreach ($roles as $r) {
    echo json_encode($r) . "\\n";
}

$adminUsers = DB::select("
    SELECT u.id, u.full_name, u.email, r.name as role_name, r.slug as role_slug 
    FROM users u 
    JOIN role_user ru ON ru.user_id = u.id 
    JOIN roles r ON r.id = ru.role_id 
    WHERE r.slug LIKE '%admin%' OR r.slug = 'high_admin'
    LIMIT 10
");
echo "\\nADMIN USERS IN ROLE_USER:\\n";
foreach ($adminUsers as $u) {
    echo json_encode($u) . "\\n";
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/check_users_schema.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/check_users_schema.php && rm -f /home/hersolot/app.hersolan.pro/check_users_schema.php")
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
