import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

commands = [
    'curl -sI -H "Host: app.hersolan.pro" http://127.0.0.1/api/v1/auth/me',
    'curl -sI -H "Host: app.hersolan.pro" https://127.0.0.1/api/v1/auth/me -k',
]

for cmd in commands:
    print("=== COMMAND:", cmd)
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print(stdout.read().decode('utf-8', errors='replace'))

ssh.close()
