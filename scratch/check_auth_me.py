import urllib.request
import json
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
req = urllib.request.Request("https://app.hersolan.pro/api/v1/auth/me", headers={
    "Authorization": f"Bearer {token}",
    "Accept": "application/json"
})
with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
    data = json.loads(resp.read().decode('utf-8'))
    print("GET /api/v1/auth/me:")
    u = data.get('data', {})
    print(f"  id: {u.get('id')}")
    print(f"  full_name: {u.get('full_name')}")
    print(f"  account_type: {u.get('account_type')}")
    print(f"  role: {u.get('role')}")
    print(f"  roles: {u.get('roles')}")
    print(f"  module_access: {u.get('module_access')}")
    print(f"  permissions ({len(u.get('permissions', []))}): {u.get('permissions', [])[:10]}...")
