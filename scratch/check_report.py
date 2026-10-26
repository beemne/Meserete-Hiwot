import paramiko
import json
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

$rep = Illuminate\\Support\\Facades\\DB::table("diagnostic_reports")
    ->where("report_id", "REP-20261026-A1112")
    ->orWhere("report_id", "like", "%A1112%")
    ->first();

if (!$rep) {
    echo "NOT FOUND DIRECTLY. LATEST 5 REPORTS:\\n";
    $recent = Illuminate\\Support\\Facades\\DB::table("diagnostic_reports")->orderByDesc("id")->limit(5)->get();
    echo json_encode($recent, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";
} else {
    echo "FOUND REPORT:\\n";
    echo json_encode($rep, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";
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
