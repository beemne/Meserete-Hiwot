import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'find /usr/local/cpanel -name "*imunify*" 2>/dev/null'
stdin, stdout, stderr = ssh.exec_command(cmd)
print("CPANEL IMUNIFY FILES:")
print(stdout.read().decode())

ssh.close()
