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

echo "COURSES:\\n" . json_encode(Illuminate\\Support\\Facades\\DB::table('edu_courses')->get(), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) . "\\n";
echo "UNITS:\\n" . json_encode(Illuminate\\Support\\Facades\\DB::table('edu_units')->get(), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) . "\\n";
echo "LESSONS:\\n" . json_encode(Illuminate\\Support\\Facades\\DB::table('edu_lessons')->get(), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) . "\\n";
echo "MATERIALS:\\n" . json_encode(Illuminate\\Support\\Facades\\DB::table('edu_lesson_materials')->get(), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) . "\\n";
echo "QUIZZES:\\n" . json_encode(Illuminate\\Support\\Facades\\DB::table('edu_quizzes')->get(), JSON_PRETTY_PRINT|JSON_UNESCAPED_UNICODE) . "\\n";
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
print(out)
ssh.close()
