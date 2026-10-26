import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

stdin, stdout, stderr = ssh.exec_command("head -n 40 /home/hersolot/app.hersolan.pro/routes/api/edu_learning.php")
print("REMOTE edu_learning.php head:")
print(stdout.read().decode('utf-8', errors='replace'))

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/artisan route:list --path=edu")
print("REMOTE artisan route:list --path=edu:")
print(stdout.read().decode('utf-8', errors='replace'))

ssh.close()
