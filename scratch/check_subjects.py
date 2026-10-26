import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'php /home/hersolot/app.hersolan.pro/artisan tinker --execute="echo json_encode(Schema::getColumnListing(\'edu_subjects\'));"'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('COLUMNS:', stdout.read().decode('utf-8'))
ssh.close()
