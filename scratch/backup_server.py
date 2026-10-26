import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

backup_dir = '/home/hersolot/backups/release_candidate_backup'

commands = [
    ("Create backup directory", f"mkdir -p {backup_dir}"),
    ("Dump database", f"mysqldump -u hersolot_yoni -pKAS@wifi1 hersolot_appdb > {backup_dir}/hersolot_appdb_backup.sql"),
    ("Verify database dump", f"ls -lh {backup_dir}/hersolot_appdb_backup.sql && head -n 5 {backup_dir}/hersolot_appdb_backup.sql"),
    ("Backup current app files", f"tar --exclude='vendor' --exclude='node_modules' --exclude='storage/framework/cache/*' -czf {backup_dir}/app_files_backup.tar.gz -C /home/hersolot app.hersolan.pro"),
    ("Verify app files backup", f"ls -lh {backup_dir}/app_files_backup.tar.gz"),
]

for title, cmd in commands:
    print(f"=== {title} ===")
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    if out:
        print(out.strip())
    if err:
        print("ERR:", err.strip())

ssh.close()
print("Backup completed successfully.")
