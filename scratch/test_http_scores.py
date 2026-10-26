import urllib.request
import json
import ssl
import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_script = """<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

use Illuminate\\Support\\Facades\\DB;
use App\\Mz\\Auth\\Tokens;

$user = DB::table('users')->where('id', 1)->first();
$tokenData = Tokens::signAccess($user);
echo "TOKEN:" . $tokenData['token'] . "\\n";
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/get_token1.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/get_token1.php && rm -f /home/hersolot/app.hersolan.pro/get_token1.php")
token_out = stdout.read().decode('utf-8', errors='replace')
ssh.close()

token = None
for line in token_out.splitlines():
    if line.startswith("TOKEN:"):
        token = line.replace("TOKEN:", "").strip()

print(f"Obtained token: {token[:25]}...")

ctx = ssl.create_default_context()

def test_endpoint(url):
    print(f"\n--- GET {url} ---")
    try:
        req = urllib.request.Request(url, headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/json"
        })
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            body = resp.read().decode('utf-8')
            print(f"Status: {resp.status}")
            data = json.loads(body)
            print("Response structure:")
            print(f"Top-level keys: {list(data.keys())}")
            if "data" in data:
                if isinstance(data["data"], dict):
                    print(f"data keys: {list(data['data'].keys())}")
                    for k, v in data["data"].items():
                        if isinstance(v, list):
                            print(f"  {k} (list of {len(v)} items)")
                        else:
                            print(f"  {k} ({type(v).__name__})")
                elif isinstance(data["data"], list):
                    print(f"data is list of {len(data['data'])} items")
            return data
    except urllib.error.HTTPError as e:
        print(f"HTTPError: {e.code} {e.reason}")
        print(e.read().decode('utf-8', errors='replace'))
    except Exception as e:
        print(f"Exception: {e}")

test_endpoint("https://app.hersolan.pro/api/v1/edu/admin/scores")
test_endpoint("https://app.hersolan.pro/api/v1/edu/admin/activity")
