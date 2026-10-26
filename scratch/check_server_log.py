import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'tail -n 100 /home/hersolot/app.hersolan.pro/storage/logs/laravel.log'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('LARAVEL LOG:\n', stdout.read().decode('utf-8'))

ssh.close()
