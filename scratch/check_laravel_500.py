import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

stdin, stdout, stderr = ssh.exec_command('grep -n "500" /home/hersolot/app.hersolan.pro/storage/logs/laravel.log | tail -n 30')
print("=== GREP 500 IN LARAVEL.LOG ===")
print(stdout.read().decode('utf-8', errors='replace'))

stdin, stdout, stderr = ssh.exec_command('tail -n 100 /home/hersolot/app.hersolan.pro/storage/logs/laravel.log')
print("=== TAIL 100 OF LARAVEL.LOG ===")
print(stdout.read().decode('utf-8', errors='replace'))

ssh.close()
