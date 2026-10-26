import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

commands = [
    ("Migrate Status", "php /home/hersolot/app.hersolan.pro/artisan migrate:status"),
    ("Check edu_course_outcomes columns", "php /home/hersolot/app.hersolan.pro/artisan tinker --execute=\"echo json_encode(Schema::getColumnListing('edu_course_outcomes'));\""),
    ("Check edu_lesson_progress columns", "php /home/hersolot/app.hersolan.pro/artisan tinker --execute=\"echo json_encode(Schema::getColumnListing('edu_lesson_progress'));\""),
    ("Check app_releases or releases tables", "php /home/hersolot/app.hersolan.pro/artisan tinker --execute=\"echo json_encode(DB::select('SHOW TABLES LIKE \\\"%release%\\\"'));\""),
]

for title, cmd in commands:
    print(f"=== {title} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    print(stdout.read().decode('utf-8', errors='replace'))
    err = stderr.read().decode('utf-8', errors='replace')
    if err:
        print("ERR:", err)

ssh.close()
