import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'mysql -u hersolot_yoni -pKAS@wifi1 hersolot_appdb -e "DESCRIBE diagnostic_reports; SELECT * FROM diagnostic_reports ORDER BY id DESC LIMIT 5;"'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('DIAGNOSTIC REPORTS:\n', stdout.read().decode('utf-8'))
err = stderr.read().decode('utf-8')
if err:
    print('ERR:\n', err)

ssh.close()
