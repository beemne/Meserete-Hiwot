import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'php /home/hersolot/app.hersolan.pro/artisan tinker --execute="echo DB::select(\'SELECT VERSION() as v\')[0]->v;"'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('DB VERSION:', stdout.read().decode('utf-8'))
ssh.close()
