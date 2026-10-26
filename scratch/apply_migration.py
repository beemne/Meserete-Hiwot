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
sftp.put(
    'laravel/database/migrations/2026_10_28_000001_stage2_features.php',
    '/home/hersolot/app.hersolan.pro/database/migrations/2026_10_28_000001_stage2_features.php'
)
sftp.close()

cmd = 'cd /home/hersolot/app.hersolan.pro && php artisan migrate --force && php artisan migrate:status'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('MIGRATE OUTPUT:\n', stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print('ERR:\n', err)

ssh.close()
