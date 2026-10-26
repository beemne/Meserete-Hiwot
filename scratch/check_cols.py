import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd1 = "php /home/hersolot/app.hersolan.pro/artisan tinker --execute=\"echo json_encode(Schema::getColumnListing('notifications'));\""
stdin, stdout, stderr = ssh.exec_command(cmd1)
print("notifications columns:", stdout.read().decode('utf-8', errors='replace'))

ssh.close()
