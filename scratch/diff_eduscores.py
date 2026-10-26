import paramiko
import sys
import difflib

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

sftp = ssh.open_sftp()

for fname in ['routes/api/edu_learning.php', 'app/Mz/Services/EduScores.php', 'app/Mz/Auth/AuthContext.php']:
    remote_path = f"/home/hersolot/app.hersolan.pro/{fname}"
    local_path = f"laravel/{fname}"
    with sftp.open(remote_path, 'r') as rf:
        remote_lines = rf.readlines()
    with open(local_path, 'r', encoding='utf-8', errors='replace') as lf:
        local_lines = lf.readlines()
    
    diff = list(difflib.unified_diff(remote_lines, local_lines, fromfile=f"remote:{fname}", tofile=f"local:{fname}", n=3))
    print(f"=== DIFF FOR {fname} ({len(diff)} lines) ===")
    print("".join(diff[:60]))
    if len(diff) > 60:
        print(f"... and {len(diff)-60} more lines")

sftp.close()
ssh.close()
