import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'php /home/hersolot/app.hersolan.pro/artisan tinker --execute="echo json_encode(DB::table(\'contribution_receipts\')->get());"'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('ROWS:', stdout.read().decode('utf-8'))
err = stderr.read().decode('utf-8')
if err:
    print('ERR:', err)

ssh.close()
