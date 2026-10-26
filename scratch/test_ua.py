import urllib.request
import urllib.error

url = 'https://app.hersolan.pro/api/v1/edu/me/dashboard'

tests = [
    ("MezmurZelideta UA", {
        'Accept': 'application/json',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; Mobile) MezmurZelideta/1.5.3'
    }),
    ("Standard Dart/Flutter", {
        'Accept': 'application/json',
        'User-Agent': 'Dart/3.4 (dart:io)'
    }),
    ("Standard Android Dalvik", {
        'Accept': 'application/json',
        'User-Agent': 'Dalvik/2.1.0 (Linux; U; Android 14; SM-A546E Build/UP1A.231005.007)'
    }),
    ("Full Chrome Mobile", {
        'Accept': 'application/json, text/plain, */*',
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14; SM-A546E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.6613.127 Mobile Safari/537.36',
        'Accept-Language': 'en-US,en;q=0.9',
    }),
    ("Plain cPanel App UA", {
        'Accept': 'application/json',
        'User-Agent': 'MezmurZelideta/1.5.3 (Android 14; SM-A546E)'
    }),
]

for name, headers in tests:
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req) as r:
            body = r.read().decode('utf-8', errors='replace')
            print(f"[{name}] HTTP {r.status} (len={len(body)}) => {body[:100]}")
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', errors='replace')
        print(f"[{name}] HTTPError {e.code} (len={len(body)}) => {body[:150]}")
    except Exception as e:
        print(f"[{name}] Exception => {e}")
