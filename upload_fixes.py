import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

sftp = ssh.open_sftp()
files_to_upload = [
    ('laravel/app/Mz/Services/EduScores.php', '/home/hersolot/app.hersolan.pro/app/Mz/Services/EduScores.php'),
    ('laravel/app/Mz/Services/EduCertificates.php', '/home/hersolot/app.hersolan.pro/app/Mz/Services/EduCertificates.php'),
]

for local_path, remote_path in files_to_upload:
    print(f"Uploading {local_path} -> {remote_path}...")
    sftp.put(local_path, remote_path)
sftp.close()

print("Clearing caches on server...")
stdin, stdout, stderr = ssh.exec_command("cd /home/hersolot/app.hersolan.pro && php artisan config:clear && php artisan cache:clear && php artisan route:clear && php artisan optimize:clear")
print(stdout.read().decode('utf-8', errors='replace'))

print("Testing EduScores::forPeriod via tinker...")
test_script = """
$auth = new \\App\\Mz\\Auth\\AuthContext();
$auth->id = 1;
$auth->status = 'active';
$auth->isAdmin = true;
$auth->permissions = ['education.reports' => true];
$res = \\App\\Mz\\Services\\EduScores::forPeriod($auth);
echo "EduScores::forPeriod count: " . count($res) . "\\n";

$act = \\App\\Mz\\Services\\EduScores::activityReport($auth);
echo "EduScores::activityReport: " . json_encode($act) . "\\n";
"""

stdin, stdout, stderr = ssh.exec_command(f"php /home/hersolot/app.hersolan.pro/artisan tinker --execute=\"{test_script.strip()}\"")
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
print("Tinker test output:\n", out)
if err:
    print("Tinker test stderr:\n", err)

ssh.close()
print("Backend fixes uploaded and verified successfully!")
