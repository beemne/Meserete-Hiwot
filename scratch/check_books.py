import paramiko
import sys
import json

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

cmd = r"""cd /home/hersolot/app.hersolan.pro && php -r '
require "vendor/autoload.php";
$app = require_once "bootstrap/app.php";
$app->make("Illuminate\Contracts\Console\Kernel")->bootstrap();

$digital = Illuminate\Support\Facades\DB::table("items")->where("kind", "digital")->select("id", "name", "code", "kind", "status", "file_path", "file_size", "domain")->get();
echo "DIGITAL ITEMS:\n" . json_encode($digital, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

$item25 = Illuminate\Support\Facades\DB::table("items")->where("id", 25)->first();
echo "ITEM 25:\n" . json_encode($item25, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
'"""

stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace'))
ssh.close()
