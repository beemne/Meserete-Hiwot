import urllib.request
import json
import ssl
import sys
import paramiko

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')
sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/get_token1.php', 'w') as f:
    f.write("""<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$k = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$k->bootstrap();
$u = Illuminate\\Support\\Facades\\DB::table('users')->where('id', 1)->first();
echo 'TOKEN:' . App\\Mz\\Auth\\Tokens::signAccess($u)['token'] . "\\n";
""")
sftp.close()
stdin, stdout, stderr = ssh.exec_command('php /home/hersolot/app.hersolan.pro/get_token1.php && rm -f /home/hersolot/app.hersolan.pro/get_token1.php')
out_text = stdout.read().decode('utf-8', errors='replace')
token = None
for l in out_text.splitlines():
    if l.startswith('TOKEN:'):
        token = l.replace('TOKEN:', '').strip()
ssh.close()

if not token:
    print("Could not obtain token. Output was:\n", out_text)
    sys.exit(1)

print(f"Obtained token: {token[:25]}...")

ctx = ssl.create_default_context()
endpoints = [
    ('/api/v1/edu/categories?all=true', 'GET'),
    ('/api/v1/edu/subjects?all=true', 'GET'),
    ('/api/v1/edu/subjects/1/quizzes', 'GET'),
    ('/api/v1/edu/admin/classes', 'GET'),
    ('/api/v1/edu/admin/academic-years', 'GET'),
    ('/api/v1/edu/admin/levels', 'GET'),
    ('/api/v1/edu/admin/marks', 'GET'),
    ('/api/v1/edu/admin/requests', 'GET'),
    ('/api/v1/edu/admin/complaints', 'GET'),
    ('/api/v1/edu/admin/scores', 'GET'),
    ('/api/v1/edu/admin/activity', 'GET'),
    ('/api/v1/edu/me/scores', 'GET'),
    ('/api/v1/edu/students/1/scores', 'GET'),
    ('/api/v1/library/books?domain=timhirt', 'GET'),
    ('/api/v1/library/circulation/copies', 'GET'),
    ('/api/v1/library/circulation/loans', 'GET'),
    ('/api/v1/library/requests', 'GET'),
    ('/api/v1/reminders', 'GET'),
    ('/api/v1/auth/me', 'GET'),
]

print(f"\nTesting {len(endpoints)} endpoints with User 1 token...")
results = []
for ep, method in endpoints:
    url = f"https://app.hersolan.pro{ep}"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}', 'Accept': 'application/json'}, method=method)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print(f"[{resp.status} OK] {ep}")
            results.append((ep, resp.status, "OK", None))
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        try:
            err_json = json.loads(body)
            code = err_json.get('code', '')
            msg = err_json.get('message', '')
            print(f"[{e.code} FAIL] {ep} -> {code}: {msg}")
            results.append((ep, e.code, code, msg))
        except Exception:
            print(f"[{e.code} FAIL] {ep} -> {body[:100]}")
            results.append((ep, e.code, "RAW_ERROR", body[:100]))
    except Exception as e:
        print(f"[ERROR] {ep} -> {e}")
        results.append((ep, 0, "EXCEPTION", str(e)))

print("\nSummary:")
for ep, status, code, msg in results:
    print(f"{status:3d} | {ep:40s} | {code} {msg or ''}")
