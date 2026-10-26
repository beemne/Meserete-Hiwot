import paramiko
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

echo "LESSONS COLS:\n" . json_encode(Illuminate\Support\Facades\Schema::getColumnListing("edu_lessons"), JSON_PRETTY_PRINT) . "\n";
echo "COURSES COLS:\n" . json_encode(Illuminate\Support\Facades\Schema::getColumnListing("edu_courses"), JSON_PRETTY_PRINT) . "\n";
echo "MATERIALS COLS:\n" . json_encode(Illuminate\Support\Facades\Schema::getColumnListing("edu_lesson_materials"), JSON_PRETTY_PRINT) . "\n";
'"""

stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace'))
ssh.close()
