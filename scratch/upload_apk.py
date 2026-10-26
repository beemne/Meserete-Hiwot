import os
import time
import sys
import paramiko

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = r'v:89]yYLi:7t7O0E)0*'
TARGET_SUBDOMAIN = 'app'
PUBLIC_DIR = f'/home/{SSH_USER}/{TARGET_SUBDOMAIN}.{SERVER_HOST}/public'

apk_source = os.path.abspath('mobile/mobile/build/app/outputs/flutter-apk/app-release.apk')
if not os.path.exists(apk_source):
    print(f'Error: {apk_source} not found.')
    sys.exit(1)

apk_size = os.path.getsize(apk_source)
print(f'Source APK: {apk_source} ({apk_size:,} bytes)')

max_retries = 3
ssh = None
for attempt in range(1, max_retries + 1):
    try:
        print(f'Connecting to {SERVER_HOST}:{SSH_PORT} (Attempt {attempt}/{max_retries})...')
        ssh = paramiko.SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS, timeout=30)
        print('Connected successfully!')
        break
    except Exception as e:
        print(f'Connection failed: {e}')
        if attempt < max_retries:
            time.sleep(3)
        else:
            sys.exit(1)

sftp = ssh.open_sftp()
temp_target = f'{PUBLIC_DIR}/app-release.apk.tmp'
final_target = f'{PUBLIC_DIR}/app-release.apk'

print(f'Uploading to {temp_target} with pipelined SFTP...')
start_time = time.time()
transferred = 0
last_pct = 0

chunk_size = 512 * 1024  # 512 KB

with open(apk_source, 'rb') as f_local:
    with sftp.open(temp_target, 'wb') as f_remote:
        f_remote.set_pipelined(True)
        while True:
            chunk = f_local.read(chunk_size)
            if not chunk:
                break
            f_remote.write(chunk)
            transferred += len(chunk)
            pct = int((transferred / apk_size) * 100)
            if pct >= last_pct + 10 or pct == 100:
                elapsed = time.time() - start_time
                speed = (transferred / (1024 * 1024)) / elapsed if elapsed > 0 else 0
                print(f'  Progress: {pct}% ({transferred:,} / {apk_size:,} bytes) - {speed:.2f} MB/s')
                last_pct = pct

# Atomically replace target file
try:
    sftp.remove(final_target)
except Exception:
    pass
sftp.rename(temp_target, final_target)

sftp.close()
ssh.close()
total_time = time.time() - start_time
print(f'APK upload completed successfully in {total_time:.1f}s!')
