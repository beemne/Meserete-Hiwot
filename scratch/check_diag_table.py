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
use Illuminate\\Support\\Facades\\Schema;

if (Schema::hasTable('diagnostic_reports')) {
    echo "TABLE diagnostic_reports EXISTS! Columns:\\n";
    $cols = DB::select("SHOW COLUMNS FROM diagnostic_reports");
    foreach ($cols as $c) {
        echo "  " . $c->Field . " (" . $c->Type . ")\\n";
    }
    $cnt = DB::table('diagnostic_reports')->count();
    echo "Total reports in DB: $cnt\\n";
} else {
    echo "TABLE diagnostic_reports DOES NOT EXIST!\\n";
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/check_diag_table.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/check_diag_table.php && rm -f /home/hersolot/app.hersolan.pro/check_diag_table.php")
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
