import os
import zipfile
import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = 'v:89]yYLi:7t7O0E)0*'
TARGET_SUBDOMAIN = 'app'
TARGET_DIR = f'/home/{SSH_USER}/{TARGET_SUBDOMAIN}.{SERVER_HOST}'
PUBLIC_DIR = f'{TARGET_DIR}/public'

web_source = 'mobile/mobile/build/web'
zip_filename = 'web_update.zip'

print(f'Packaging {web_source} into {zip_filename}...')
if os.path.exists(zip_filename):
    os.remove(zip_filename)

with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(web_source):
        for f in files:
            file_path = os.path.join(root, f)
            rel_path = os.path.relpath(file_path, web_source).replace('\\', '/')
            z.write(file_path, rel_path)

zip_size = os.path.getsize(zip_filename)
print(f'Packed web update successfully: {zip_size:,} bytes.')

print(f'Connecting to {SERVER_HOST} via SSH...')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS)

print(f'Uploading {zip_filename} to {PUBLIC_DIR}...')
sftp = ssh.open_sftp()
last_pct = [0]
def progress_callback(transferred, total):
    pct = int((transferred / total) * 100)
    if pct >= last_pct[0] + 20 or pct == 100:
        print(f'  Upload progress: {pct}% ({transferred:,} / {total:,} bytes)')
        last_pct[0] = pct

sftp.put(zip_filename, f'{PUBLIC_DIR}/{zip_filename}', callback=progress_callback)
sftp.close()

print('Extracting web update into public directory...')
stdin, stdout, stderr = ssh.exec_command(f'cd {PUBLIC_DIR} && unzip -o {zip_filename} && rm -f {zip_filename}')
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print('Extract stderr:', err[:300])

print('Clearing Laravel application caches...')
stdin, stdout, stderr = ssh.exec_command(f'cd {TARGET_DIR} && php artisan config:clear && php artisan cache:clear')
print(stdout.read().decode('utf-8', errors='replace'))

print('Verifying updated files in public directory...')
stdin, stdout, stderr = ssh.exec_command(f'ls -la {PUBLIC_DIR}/main.dart.js {PUBLIC_DIR}/index.html {PUBLIC_DIR}/version.json')
print(stdout.read().decode('utf-8', errors='replace'))

print('Testing HTTP responses...')
stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/')
print('CURL / (root):\n', stdout.read().decode('utf-8', errors='replace'))

stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/main.dart.js')
print('CURL /main.dart.js:\n', stdout.read().decode('utf-8', errors='replace'))

ssh.close()
if os.path.exists(zip_filename):
    os.remove(zip_filename)

print('Web app update completed successfully!')
