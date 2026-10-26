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

Illuminate\\Support\\Facades\\DB::table("diagnostic_reports")
    ->where("report_id", "REP-20261026-A1112")
    ->update([
        "status" => "resolved",
        "status_note" => "Fixed missing default argument in EduLearning::subjects() called by EduDashboard::forUser(). Verified live on server.",
        "resolved_at" => now(),
        "updated_at" => now(),
    ]);

$updated = Illuminate\\Support\\Facades\\DB::table("diagnostic_reports")
    ->where("report_id", "REP-20261026-A1112")
    ->first();

echo "REPORT STATUS UPDATED:\\n" . json_encode($updated, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
