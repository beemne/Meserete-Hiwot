import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

stdin, stdout, stderr = ssh.exec_command('grep -C 5 -i "quizzes" /home/hersolot/app.hersolan.pro/storage/logs/laravel.log | tail -n 80')
print("=== QUIZZES IN LOG ===")
out1 = stdout.read().decode('utf-8', errors='replace')
with open('scratch/server_quiz_log.txt', 'w', encoding='utf-8') as f:
    f.write(out1)
print(out1.encode('ascii', 'backslashreplace').decode('ascii')[:3000])

stdin, stdout, stderr = ssh.exec_command('tail -n 100 /home/hersolot/app.hersolan.pro/storage/logs/laravel.log')
out2 = stdout.read().decode('utf-8', errors='replace')
with open('scratch/server_tail_log.txt', 'w', encoding='utf-8') as f:
    f.write(out2)
print("=== LAST LINES ===")
print(out2.encode('ascii', 'backslashreplace').decode('ascii')[-2000:])

ssh.close()
