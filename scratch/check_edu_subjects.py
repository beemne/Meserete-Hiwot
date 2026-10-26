import paramiko
import json
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')
cmd = r"""cd /home/hersolot/app.hersolan.pro && php -r '
require "vendor/autoload.php";
$app = require_once "bootstrap/app.php";
$app->make("Illuminate\Contracts\Console\Kernel")->bootstrap();

$subjects = Illuminate\Support\Facades\DB::table("edu_subjects")->get();
echo "SUBJECTS:\n" . json_encode($subjects, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

$classes = Illuminate\Support\Facades\DB::table("edu_classes")->get();
echo "CLASSES:\n" . json_encode($classes, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

$courses = Illuminate\Support\Facades\DB::table("edu_courses")->get();
echo "COURSES:\n" . json_encode($courses, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

$tables = Illuminate\Support\Facades\DB::select("SHOW TABLES");
echo "TABLES:\n" . json_encode($tables, JSON_PRETTY_PRINT) . "\n";
'"""
stdin, stdout, stderr = ssh.exec_command(cmd)
print("STDOUT:", stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace'))
ssh.close()
