import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

sftp = ssh.open_sftp()
sftp.put(
    'laravel/app/Mz/Services/Payments.php',
    '/home/hersolot/app.hersolan.pro/app/Mz/Services/Payments.php'
)
sftp.close()

cmd = 'cd /home/hersolot/app.hersolan.pro && php artisan config:clear && php artisan cache:clear'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('CACHE CLEAR OUTPUT:\n', stdout.read().decode('utf-8'))

ssh.close()
print('Payments.php updated on server.')
