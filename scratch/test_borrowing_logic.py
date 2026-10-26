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

$user = App\Mz\Auth\AuthContext::load(1);
$actx = ["auth" => $user, "ip" => "127.0.0.1", "ua" => "test"];

// Test: Item 25 (User 1 currently has active borrowing for it)
try {
    App\Mz\Services\Library::request($actx, 25, ["quantity" => 1]);
    echo "ERROR: Should have thrown ALREADY_BORROWED!\n";
} catch (App\Mz\Support\ApiError $e) {
    echo "SUCCESS: Caught expected conflict: " . $e->getMessage() . "\n";
}

// Test: Check that books listing marks item 25 as issued / active loan
$books = App\Mz\Services\Library::books($user, ["domain" => "timhirt", "kind" => "physical"], ["limit" => 50, "offset" => 0]);
$item25 = collect($books["items"])->firstWhere("id", 25);
echo "ITEM 25 IN CATALOG:\n";
echo "  my_request: " . ($item25["my_request"] ?? "NULL") . "\n";
'"""

stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace'))
ssh.close()
