import urllib.request
import ssl
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

import paramiko
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

ctx = ssl.create_default_context()

try:
    url = "https://app.hersolan.pro/api/v1/edu/materials/3/file"
    print(f"Downloading: {url}")
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bearer {token}",
    })
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        content = resp.read()
        print(f"HTTP {resp.status}, Content-Type: {resp.headers.get('Content-Type')}, Length: {len(content)} bytes")
        print(f"Content-Disposition: {resp.headers.get('Content-Disposition')}")
except Exception as e:
    print(f"Download exception: {e}")
