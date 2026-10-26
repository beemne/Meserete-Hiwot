import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'cd /home/hersolot/app.hersolan.pro && php artisan migrate:status'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('MIGRATION STATUS:\n', stdout.read().decode('utf-8', errors='replace'))
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print('ERR:\n', err)

ssh.close()
