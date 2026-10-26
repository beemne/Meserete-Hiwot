import paramiko
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')
cmd = "php /home/hersolot/app.hersolan.pro/artisan tinker --execute=\"echo json_encode(DB::table('users')->select('id', 'full_name', 'account_type', 'role_id')->get());\""
_, stdout, _ = ssh.exec_command(cmd)
print(stdout.read().decode())
ssh.close()
