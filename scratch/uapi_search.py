import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'uapi --help | grep -iE "secur|firewall|imun|shield|bot|protect|white|block"'
stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode())
ssh.close()
