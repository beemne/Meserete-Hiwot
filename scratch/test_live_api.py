import paramiko
import sys
import json

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

cmd = '''php /home/hersolot/app.hersolan.pro/artisan tinker --execute="
    $u = DB::table('users')->where('status', 'active')->first(['id', 'phone', 'full_name', 'role_id', 'member_type']);
    echo json_encode([
        'user' => $u,
        'roles' => DB::table('roles')->get(['id', 'key', 'name']),
        'calc' => \\App\\Mz\\Services\\ContributionReceipts::calculateExpected($u->id, '2019-02', 3),
        'scores' => \\App\\Mz\\Services\\EduScores::myScores($u->id),
    ]);
"'''

stdin, stdout, stderr = ssh.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
print("TINKER OUTPUT:\n", out)
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print("ERR:\n", err)

ssh.close()
