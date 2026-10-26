import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

php_code = """<?php
require "vendor/autoload.php";
$app = require_once "bootstrap/app.php";
$app->make("Illuminate\\Contracts\\Console\\Kernel")->bootstrap();

try {
    $auth = App\\Mz\\Auth\\AuthContext::load(1);
    $dashboard = App\\Mz\\Services\\EduDashboard::forUser($auth);
    echo "DASHBOARD SUCCESS! Keys: " . implode(', ', array_keys($dashboard)) . "\\n";
    echo "Subjects count: " . count($dashboard['subjects']) . "\\n";
    foreach ($dashboard['subjects'] as $s) {
        echo " - [{$s['sort_order']}] {$s['name']} (ID: {$s['id']})\\n";
    }
} catch (Throwable $e) {
    echo "DASHBOARD ERROR: " . $e->getMessage() . "\\n" . $e->getTraceAsString() . "\\n";
}
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print('STDERR:', err)

ssh.close()
