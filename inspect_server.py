import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

for f in ['/home/hersolot/mhs.hersolan.pro/.env', '/home/hersolot/app.hersolan.pro/.env']:
    print(f"=== {f} ===")
    stdin, stdout, stderr = ssh.exec_command(f'cat {f}')
    content = stdout.read().decode('utf-8', errors='replace')
    for line in content.splitlines():
        if any(k in line for k in ['APP_KEY', 'DATA_ENCRYPTION', 'KEY']):
            print(line)

ssh.close()
