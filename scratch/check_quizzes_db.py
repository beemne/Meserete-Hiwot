import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = 'mysql -u hersolot_yoni -pKAS@wifi1 hersolot_appdb -e "SELECT id, title, course_id, lesson_id, assessment_id, status FROM edu_quizzes ORDER BY id DESC LIMIT 10;"'
stdin, stdout, stderr = ssh.exec_command(cmd)
print('QUIZZES:\n', stdout.read().decode('utf-8'))
err = stderr.read().decode('utf-8')
if err:
    print('ERR:\n', err)

cmd_cols = 'mysql -u hersolot_yoni -pKAS@wifi1 hersolot_appdb -e "DESCRIBE edu_quizzes;"'
stdin, stdout, stderr = ssh.exec_command(cmd_cols)
print('COLUMNS:\n', stdout.read().decode('utf-8'))

ssh.close()
