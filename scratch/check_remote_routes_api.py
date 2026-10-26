import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

stdin, stdout, stderr = ssh.exec_command("ls -la /home/hersolot/app.hersolan.pro/routes/api/")
print("REMOTE routes/api/ files:")
print(stdout.read().decode('utf-8', errors='replace'))

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/artisan route:list | grep -E 'edu/me/scores|students.*scores'")
print("REMOTE routes matching scores:")
print(stdout.read().decode('utf-8', errors='replace'))

ssh.close()
