import json
import urllib.request
import ssl
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ctx = ssl.create_default_context()

print("=" * 70)
print("PRODUCTION VERIFICATION REPORT: Categories, Grades & Release Deployment")
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
        print(f"[PASS] /app-release.apk returned HTTP {resp.status}, Size: {int(cl):,} bytes")
except Exception as e:
    print(f"[FAIL] /app-release.apk error: {e}")

# 3. Verify Web Version
try:
    req = urllib.request.Request("https://app.hersolan.pro/version.json", headers={"User-Agent": "ReleaseVerifier/1.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        v = json.loads(resp.read().decode('utf-8'))
        print(f"[PASS] /version.json returned HTTP {resp.status}: app_name={v.get('app_name')}, version={v.get('version')}, build_number={v.get('build_number')}")
except Exception as e:
    print(f"[FAIL] /version.json error: {e}")

# 4. Verify Web index.html
try:
    req = urllib.request.Request("https://app.hersolan.pro/", headers={"User-Agent": "ReleaseVerifier/1.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        html = resp.read().decode('utf-8')
        has_bootstrap = "flutter_bootstrap.js" in html
        print(f"[PASS] Web root returned HTTP {resp.status}, flutter_bootstrap.js referenced: {has_bootstrap}")
except Exception as e:
    print(f"[FAIL] Web root error: {e}")

# 5. Verify /api/v1/education/home categories & grade subjects
try:
    req = urllib.request.Request("https://app.hersolan.pro/api/v1/education/home", headers={"User-Agent": "ReleaseVerifier/1.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        data = json.loads(resp.read().decode('utf-8'))
        cats = data.get('data', {}).get('categories', [])
        print(f"[PASS] /api/v1/education/home returned {len(cats)} categories:")
        for c in sorted(cats, key=lambda x: x.get('display_order', 0)):
            cid = c.get('id')
            cname = c.get('name')
            order = c.get('display_order')
            subs = c.get('subjects', [])
            grades = [s.get('name') for s in subs]
            print(f"       ({order}) [ID: {cid}] {cname} -> {len(subs)} grades ({grades[:3]}...{grades[-1:] if grades else ''})")
except Exception as e:
    print(f"[FAIL] /api/v1/education/home error: {e}")

print("=" * 70)
