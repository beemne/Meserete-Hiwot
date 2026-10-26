import paramiko
import sys
import os

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')
sftp = ssh.open_sftp()

remote_base = '/home/hersolot/app.hersolan.pro'
local_base = r'c:\Users\HP\Documents\MH-app-1.5.3\laravel'

files_to_sync = [
    'database/migrations/2026_10_26_100000_canonical_subjects_and_borrowing_constraints.php',
    'database/migrations/2026_10_26_120000_categories_and_grade_subjects.php',
    'app/Mz/Services/EduLearning.php',
    'app/Mz/Services/Library.php',
    'app/Mz/Services/Borrowings.php',
    'app/Mz/Services/LibraryCirculation.php',
    'routes/api/edu_learning.php',
    'routes/api/library.php',
    'app/Mz/Services/EduDashboard.php',
]

for rel in files_to_sync:
    local_p = os.path.join(local_base, rel.replace('/', os.sep))
    remote_p = f"{remote_base}/{rel}"
    print(f"Uploading {local_p} -> {remote_p}")
    sftp.put(local_p, remote_p)

sftp.close()

stdin, stdout, stderr = ssh.exec_command(f"cd {remote_base} && php artisan migrate --force")
print("MIGRATE STDOUT:\n", stdout.read().decode('utf-8', errors='replace'))
print("MIGRATE STDERR:\n", stderr.read().decode('utf-8', errors='replace'))

stdin, stdout, stderr = ssh.exec_command(f"""cd {remote_base} && php -r '
require "vendor/autoload.php";
$app = require_once "bootstrap/app.php";
$app->make("Illuminate\Contracts\Console\Kernel")->bootstrap();

$subjects = Illuminate\Support\Facades\DB::table("edu_subjects")->whereBetween("sort_order", [1, 7])->orderBy("sort_order")->get(["id", "name", "sort_order", "status"]);
echo "CANONICAL SUBJECTS IN DB:\n" . json_encode($subjects, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
'""")
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:\n", stderr.read().decode('utf-8', errors='replace'))

ssh.close()
