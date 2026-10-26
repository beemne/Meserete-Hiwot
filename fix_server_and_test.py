import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

# 1. Update APP_KEY in /home/hersolot/app.hersolan.pro/.env
print("Updating APP_KEY in app.hersolan.pro/.env...")
cmd_update_key = "sed -i 's|APP_KEY=base64:z8B6Cybu5XqYTYb8OeFAqL3partPoHqpPxxa2F8nqoI=|APP_KEY=base64:Q+LSM0tVbukjw3CZwCaCkog87gYztiJXaNUJ0pyL3FY=|' /home/hersolot/app.hersolan.pro/.env"
ssh.exec_command(cmd_update_key)

# 2. Upload updated Seal.php to server
print("Uploading updated Seal.php...")
sftp = ssh.open_sftp()
sftp.put(
    'laravel/app/Mz/Crypto/Seal.php',
    '/home/hersolot/app.hersolan.pro/app/Mz/Crypto/Seal.php'
)
sftp.close()

# 3. Clear cache remotely
print("Clearing cache on server...")
stdin, stdout, stderr = ssh.exec_command("cd /home/hersolot/app.hersolan.pro && php artisan config:clear && php artisan cache:clear")
print(stdout.read().decode('utf-8', errors='replace'))

# 4. Test notifications query via php artisan tinker or curl
print("Testing notifications query via artisan tinker...")
test_script = "echo 'echo json_encode(\\App\\Models\\Notification::take(3)->get()->toArray());' | php /home/hersolot/app.hersolan.pro/artisan tinker"
stdin, stdout, stderr = ssh.exec_command(test_script)
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print("Tinker output:")
print(out)
if err:
    print("Tinker stderr:", err)

# 5. Check laravel.log tail
print("Recent laravel log entries:")
stdin, stdout, stderr = ssh.exec_command("tail -n 20 /home/hersolot/app.hersolan.pro/storage/logs/laravel.log")
print(stdout.read().decode('utf-8', errors='replace'))

ssh.close()
print("Done server test.")
