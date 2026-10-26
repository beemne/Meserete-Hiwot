import paramiko
import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')


ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')
cmd = r"""cd /home/hersolot/app.hersolan.pro && php -r '
require "vendor/autoload.php";
$app = require_once "bootstrap/app.php";
$app->make("Illuminate\Contracts\Console\Kernel")->bootstrap();
$auth = App\Mz\Auth\AuthContext::load(1);
$res = App\Mz\Services\Diagnostics::listReports($auth, [], ["page"=>1, "per_page"=>5]);
echo json_encode($res, JSON_PRETTY_PRINT);
'"""
stdin, stdout, stderr = ssh.exec_command(cmd)
print("STDOUT:", stdout.read().decode())
print("STDERR:", stderr.read().decode())
ssh.close()
