import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_code = """<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

$user = Illuminate\\Support\\Facades\\DB::table('users')->where('status', 'active')->first();
$tokenData = App\\Mz\\Auth\\Tokens::signAccess($user);
echo "TOKEN:" . $tokenData['token'] . "\\n";
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/get_token_tmp.php', 'w') as f:
    f.write(php_code)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('php /home/hersolot/app.hersolan.pro/get_token_tmp.php && rm -f /home/hersolot/app.hersolan.pro/get_token_tmp.php')
token_out = stdout.read().decode('utf-8', errors='replace')

token = None
for line in token_out.splitlines():
    if line.startswith("TOKEN:"):
        token = line.replace("TOKEN:", "").strip()

if token:
    print(f"Generated test token: {token[:20]}...")
    endpoints = [
        "/health",
        "/api/v1/auth/me",
        "/api/v1/me/payments",
        "/api/v1/me/payments/receipts",
        "/api/v1/payments/receipts",
        "/api/v1/payments/policy",
        "/api/v1/payments/rates",
        "/api/v1/edu/me/scores",
        "/api/v1/edu/me/dashboard",
        "/api/v1/edu/me/progress",
        "/api/v1/edu/search?q=test",
        "/api/v1/edu/magazines",
        "/api/v1/edu/magazines/latest",
        "/api/v1/edu/subjects",
        "/api/v1/edu/categories",
        "/api/v1/edu/featured",
        "/api/v1/library/books",
        "/api/v1/programs",
        "/api/v1/audit-logs",
    ]
    for ep in endpoints:
        cmd = f'curl -s -w "\\nSTATUS:%{{http_code}}" -H "Authorization: Bearer {token}" -H "User-Agent: Mozilla/5.0 (Linux; Android 14; Mobile) MezmurZelideta/1.5.3" https://app.hersolan.pro{ep}'
        stdin, stdout, stderr = ssh.exec_command(cmd)
        raw = stdout.read().decode('utf-8', errors='replace').strip()
        parts = raw.rsplit("STATUS:", 1)
        body = parts[0].strip() if len(parts) > 1 else ""
        code = parts[1].strip() if len(parts) > 1 else raw
        print(f"GET {ep} -> HTTP {code} | {body[:100]}")
else:
    print("Could not generate token. Output:", token_out)

ssh.close()
