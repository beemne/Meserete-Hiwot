import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'grep -rn "contribution_receipts" /home/hersolot/app.hersolan.pro/app /home/hersolot/app.hersolan.pro/routes'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('GREP APP/ROUTES:', stdout.read().decode('utf-8'))
err = stderr.read().decode('utf-8')
if err:
    print('ERR:', err)

ssh.close()
