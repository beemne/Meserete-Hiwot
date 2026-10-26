import json
import urllib.request
import ssl
import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ctx = ssl.create_default_context()

print("=" * 70)
print("PRODUCTION VERIFICATION REPORT: Sinksar Widget Release")
print("=" * 70)

# 1. Verify /health
try:
    req = urllib.request.Request("https://app.hersolan.pro/health", headers={"User-Agent": "ReleaseVerifier/1.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        body = resp.read().decode('utf-8')
        print(f"[PASS] /health returned HTTP {resp.status}: {body.strip()}")
except Exception as e:
    print(f"[FAIL] /health error: {e}")

# 2. Verify APK download
try:
    req = urllib.request.Request("https://app.hersolan.pro/app-release.apk", headers={"User-Agent": "ReleaseVerifier/1.0"}, method="HEAD")
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        ct = resp.headers.get("Content-Type")
        cl = resp.headers.get("Content-Length")
        print(f"[PASS] /app-release.apk returned HTTP {resp.status}, Content-Type: {ct}, Size: {int(cl):,} bytes")
except Exception as e:
    print(f"[FAIL] /app-release.apk error: {e}")

# 3. Verify /api/v1/sinksar/today
try:
    req = urllib.request.Request("https://app.hersolan.pro/api/v1/sinksar/today", headers={"User-Agent": "ReleaseVerifier/1.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print(f"[PASS] /api/v1/sinksar/today returned HTTP {resp.status}")
        payload = data.get('data', data)
        eth_date = payload.get('ethiopian_date') or payload.get('date_ethiopian')
        ann_feasts = payload.get('annual_feasts') or payload.get('feasts') or []
        mth_feasts = payload.get('monthly_feasts') or []
        print(f"       Ethiopian Date: {eth_date}")
        print(f"       Annual Feasts: {ann_feasts[:3] if isinstance(ann_feasts, list) else ann_feasts}")
        print(f"       Monthly Feasts: {mth_feasts[:3] if isinstance(mth_feasts, list) else mth_feasts}")
except Exception as e:
    print(f"[FAIL] /api/v1/sinksar/today error: {e}")

# 4. Verify /api/v1/sinksar/2019-02-15
try:
    req = urllib.request.Request("https://app.hersolan.pro/api/v1/sinksar/2019-02-15", headers={"User-Agent": "ReleaseVerifier/1.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        print(f"[PASS] /api/v1/sinksar/2019-02-15 returned HTTP {resp.status}")
        payload = data.get('data', data)
        print(f"       Feasts: {payload.get('feasts', [])[:2]}")
except Exception as e:
    print(f"[FAIL] /api/v1/sinksar/2019-02-15 error: {e}")

# 5. Check remote Laravel logs
try:
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')
    stdin, stdout, stderr = ssh.exec_command("tail -n 20 /home/hersolot/app.hersolan.pro/storage/logs/laravel.log")
    logs = stdout.read().decode('utf-8', errors='replace').strip()
    if logs:
        print("[INFO] Last 20 lines of remote laravel.log:")
        for line in logs.splitlines()[-5:]:
            print(f"       {line}")
    else:
        print("[PASS] remote laravel.log is clean.")
    ssh.close()
except Exception as e:
    print(f"[WARN] SSH log check error: {e}")

print("=" * 70)
