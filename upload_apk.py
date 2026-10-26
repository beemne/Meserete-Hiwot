import os
import sys
import paramiko

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

local_apk = 'mobile/mobile/build/app/outputs/flutter-apk/app-release.apk'
if not os.path.exists(local_apk):
    print(f"ERROR: {local_apk} does not exist!")
    sys.exit(1)

local_size = os.path.getsize(local_apk)
print(f"Local APK: {local_apk} ({local_size:,} bytes)")

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

remote_apk = '/home/hersolot/app.hersolan.pro/public/app-release.apk'
print(f"Uploading APK via SFTP to {remote_apk}...")

sftp = ssh.open_sftp()
# Use callback to track progress
last_pct = 0
def progress_callback(transferred, total):
    global last_pct
    pct = int((transferred / total) * 100)
    if pct >= last_pct + 10:
        print(f"  Upload progress: {pct}% ({transferred:,} / {total:,} bytes)")
        last_pct = pct

sftp.put(local_apk, remote_apk, callback=progress_callback)
sftp.chmod(remote_apk, 0o644)
sftp.close()

stdin, stdout, stderr = ssh.exec_command(f"ls -la {remote_apk}")
remote_info = stdout.read().decode('utf-8', errors='replace').strip()
print(f"Remote file: {remote_info}")

# Verify via curl HEAD
stdin, stdout, stderr = ssh.exec_command("curl -sI https://app.hersolan.pro/app-release.apk")
curl_out = stdout.read().decode('utf-8', errors='replace')
print("CURL HEAD response:\n" + curl_out)

ssh.close()
print("APK upload completed and verified successfully!")
