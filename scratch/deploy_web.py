import os
import sys
import time
import paramiko

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = r'v:89]yYLi:7t7O0E)0*'
TARGET_SUBDOMAIN = 'app'
REMOTE_PUBLIC = f'/home/{SSH_USER}/{TARGET_SUBDOMAIN}.{SERVER_HOST}/public'
LOCAL_WEB = os.path.abspath('mobile/mobile/build/web')

if not os.path.isdir(LOCAL_WEB):
    print(f'Error: {LOCAL_WEB} does not exist.')
    sys.exit(1)

print(f'Connecting to {SERVER_HOST}...')
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS, timeout=30)
sftp = ssh.open_sftp()
print('Connected!')

def sftp_makedirs(sftp, remote_dir):
    dirs = []
    p = remote_dir
    while p not in ('/', ''):
        dirs.append(p)
        p = os.path.dirname(p)
    dirs.reverse()
    for d in dirs:
        try:
            sftp.stat(d)
        except IOError:
            try:
                sftp.mkdir(d)
            except Exception:
                pass

uploaded_count = 0
uploaded_bytes = 0
start_time = time.time()

# Walk local_web and upload files
for root, dirs, files in os.walk(LOCAL_WEB):
    rel_dir = os.path.relpath(root, LOCAL_WEB)
    remote_dir = REMOTE_PUBLIC if rel_dir == '.' else f"{REMOTE_PUBLIC}/{rel_dir.replace(os.sep, '/')}"
    
    if rel_dir != '.':
        sftp_makedirs(sftp, remote_dir)
        
    for file in files:
        if file.startswith('.last_build_id'):
            continue
        local_file = os.path.join(root, file)
        remote_file = f"{remote_dir}/{file}"
        
        file_size = os.path.getsize(local_file)
        # Check if remote file exists and has same size & mtime
        need_upload = True
        try:
            attr = sftp.stat(remote_file)
            if attr.st_size == file_size:
                # If size matches, check if it's not a frequently changing file
                if file not in ['main.dart.js', 'flutter_bootstrap.js', 'flutter_service_worker.js', 'version.json', 'index.html']:
                    need_upload = False
        except IOError:
            need_upload = True
            
        if need_upload:
            print(f'Uploading {rel_dir}/{file} ({file_size:,} bytes)...')
            sftp.put(local_file, remote_file)
            uploaded_count += 1
            uploaded_bytes += file_size

sftp.close()
ssh.close()
elapsed = time.time() - start_time
print(f'Web deployment complete! Uploaded {uploaded_count} files ({uploaded_bytes:,} bytes) in {elapsed:.1f}s.')
