import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'grep " 404 " /home/hersolot/logs/*app.hersolan.pro* 2>/dev/null | tail -n 20'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('ACCESS LOG 404s:\n', stdout.read().decode('utf-8'))

cmd2 = 'grep -i "404" /home/hersolot/app.hersolan.pro/public/error_log 2>/dev/null | tail -n 20'
stdin, stdout, stderr = ssh.exec_command(cmd2)
print('PUBLIC ERROR LOG:\n', stdout.read().decode('utf-8'))

ssh.close()
