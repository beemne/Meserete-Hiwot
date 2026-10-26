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

$courses = Illuminate\\Support\\Facades\\DB::table("edu_courses")->get();
echo "COURSES:\\n" . json_encode($courses, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";

$units = Illuminate\\Support\\Facades\\DB::table("edu_units")->get();
echo "UNITS:\\n" . json_encode($units, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";

$quizzes = Illuminate\\Support\\Facades\\DB::table("edu_quizzes")->get();
echo "QUIZZES:\\n" . json_encode($quizzes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\\n";
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
