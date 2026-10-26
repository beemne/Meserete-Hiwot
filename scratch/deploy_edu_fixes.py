import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')
sftp = ssh.open_sftp()

files_to_deploy = [
    ('laravel/routes/api/edu_learning.php', '/home/hersolot/app.hersolan.pro/routes/api/edu_learning.php'),
    ('laravel/app/Mz/Services/EduScores.php', '/home/hersolot/app.hersolan.pro/app/Mz/Services/EduScores.php'),
    ('laravel/app/Mz/Services/Users.php', '/home/hersolot/app.hersolan.pro/app/Mz/Services/Users.php'),
]

for local_path, remote_path in files_to_deploy:
    bak_path = f"{remote_path}.bak_edu_fix"
    try:
        sftp.stat(bak_path)
        print(f"Backup {bak_path} already exists, skipping backup.")
    except FileNotFoundError:
        print(f"Creating backup: {remote_path} -> {bak_path}")
        stdin, stdout, stderr = ssh.exec_command(f"cp {remote_path} {bak_path}")
        stdout.read()
    
    print(f"Uploading {local_path} -> {remote_path}...")
    sftp.put(local_path, remote_path)

sftp.close()

print("Clearing Laravel caches on hersolan.pro...")
cmd = "cd /home/hersolot/app.hersolan.pro && php artisan config:clear && php artisan cache:clear && php artisan route:clear && php artisan optimize:clear"
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print("Stderr:", err)

ssh.close()
print("Deployment completed successfully!")
