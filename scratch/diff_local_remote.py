import paramiko
import os
import hashlib
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

sftp = ssh.open_sftp()

dirs_to_check = [
    ('laravel/routes/api', '/home/hersolot/app.hersolan.pro/routes/api'),
    ('laravel/app/Mz/Services', '/home/hersolot/app.hersolan.pro/app/Mz/Services'),
    ('laravel/app/Mz/Auth', '/home/hersolot/app.hersolan.pro/app/Mz/Auth'),
]

diffs = []

for local_dir, remote_dir in dirs_to_check:
    for f in os.listdir(local_dir):
        if not f.endswith('.php'):
            continue
        local_path = os.path.join(local_dir, f)
        remote_path = f"{remote_dir}/{f}"
        local_size = os.path.getsize(local_path)
        try:
            remote_attr = sftp.stat(remote_path)
            remote_size = remote_attr.st_size
            if local_size != remote_size:
                diffs.append((f, local_path, remote_path, local_size, remote_size))
        except FileNotFoundError:
            diffs.append((f, local_path, remote_path, local_size, "MISSING_ON_REMOTE"))

print(f"Total diffs found: {len(diffs)}")
for f, lp, rp, ls, rs in diffs:
    print(f"File {f}: local_size={ls}, remote_size={rs}")

sftp.close()
ssh.close()
