import paramiko
import sys

sys.stdout.reconfigure(encoding='utf-8')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

sftp = ssh.open_sftp()
sftp.put('scratch/check_diag.php', '/home/hersolot/app.hersolan.pro/check_diag.php')
sftp.close()

stdin, stdout, stderr = ssh.exec_command('php /home/hersolot/app.hersolan.pro/check_diag.php && rm /home/hersolot/app.hersolan.pro/check_diag.php')
print("OUTPUT:")
print(stdout.read().decode('utf-8', errors='replace'))
print("ERRORS:")
print(stderr.read().decode('utf-8', errors='replace'))

ssh.close()
