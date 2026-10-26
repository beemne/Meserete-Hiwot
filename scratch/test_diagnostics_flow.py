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

print("1. Submitting test diagnostic report...")
report_payload = {
    "module": "education",
    "screen": "EduScoresScreen",
    "operation": "load_scores",
    "category": "api_error",
    "severity": "high",
    "message": "Controlled test error: verified report submission",
    "stack_trace": "#0 EduScoresScreen.initState()\\n#1 Flutter framework test",
    "endpoint": "/api/v1/edu/admin/scores",
    "http_status": 500,
    "app_version": "1.5.3+25",
    "platform": "android"
}

req = urllib.request.Request(
    "https://app.hersolan.pro/api/v1/diagnostics/reports",
    data=json.dumps(report_payload).encode('utf-8'),
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }
)

with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
    res = json.loads(resp.read().decode('utf-8'))
    print(f"Submission status: {resp.status}, response: {res}")
    rep_id = res.get('data', {}).get('report_id')

print("\n2. Fetching reports from /api/v1/admin/diagnostics...")
req2 = urllib.request.Request(
    "https://app.hersolan.pro/api/v1/admin/diagnostics",
    headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    }
)

with urllib.request.urlopen(req2, context=ctx, timeout=10) as resp:
    res2 = json.loads(resp.read().decode('utf-8'))
    print(f"Admin diagnostics status: {resp.status}")
    reports = res2.get('data', {}).get('items', [])
    print(f"Total reports found: {len(reports)}")
    for r in reports[:3]:
        print(f"  Report {r.get('report_id')}: [{r.get('module')}] {r.get('message')[:50]} (status: {r.get('status')})")
