import paramiko
import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

php_code = """<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$app->make('Illuminate\\Contracts\\Console\\Kernel')->bootstrap();

$catCols = DB::select('SHOW COLUMNS FROM edu_categories');
echo "EDU_CATEGORIES COLUMNS:\\n" . json_encode($catCols, JSON_PRETTY_PRINT) . "\\n";

$subCols = DB::select('SHOW COLUMNS FROM edu_subjects');
echo "EDU_SUBJECTS COLUMNS:\\n" . json_encode($subCols, JSON_PRETTY_PRINT) . "\\n";
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
print(out)
ssh.close()
