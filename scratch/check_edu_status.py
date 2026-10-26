import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_script = """
echo "=== SETTINGS modules.policy ===\\n";
$m = \\DB::table('settings')->where('key', 'modules.policy')->first();
echo json_encode($m) . "\\n";

echo "=== ALL SETTINGS KEYS ===\\n";
echo json_encode(\\DB::table('settings')->pluck('key')) . "\\n";

echo "=== USERS (sample) ===\\n";
$users = \\DB::table('users')->where('first_name', 'like', '%ዮናስ%')->orWhere('id', '<', 5)->get(['id', 'first_name', 'phone', 'member_group', 'role', 'status']);
echo json_encode($users, JSON_UNESCAPED_UNICODE) . "\\n";

echo "=== RECENT LOGS ===\\n";
"""

cmd = f"cd /home/hersolot/app.hersolan.pro && php artisan tinker --execute=\"{php_script}\""
stdin, stdout, stderr = ssh.exec_command(cmd)
print("STDOUT:")
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:")
print(stderr.read().decode('utf-8', errors='replace'))

# Also check last 40 lines of laravel.log
stdin, stdout, stderr = ssh.exec_command("tail -n 40 /home/hersolot/app.hersolan.pro/storage/logs/laravel.log")
print("RECENT LARAVEL LOG:")
print(stdout.read().decode('utf-8', errors='replace'))

ssh.close()
