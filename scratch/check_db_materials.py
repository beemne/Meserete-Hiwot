import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php_script = """<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();

use Illuminate\\Support\\Facades\\DB;
use App\\Mz\\Services\\EduLearning;
use App\\Mz\\Auth\\AuthContext;

$mats = DB::table('edu_lesson_materials')->get();
echo "Total materials in DB: " . count($mats) . "\\n";
foreach ($mats as $m) {
    echo json_encode($m) . "\\n";
    if ($m->kind === 'file') {
        $abs = App\\Mz\\Services\\Storage::privatePath($m->path);
        echo "  File path: " . $m->path . " -> Exists? " . (file_exists($abs) ? "YES (" . filesize($abs) . " bytes)" : "NO: $abs") . "\\n";
        try {
            $auth = AuthContext::load(1);
            $res = EduLearning::materialFile($auth, $m->id);
            echo "  materialFile result: " . json_encode($res) . "\\n";
        } catch (Throwable $e) {
            echo "  materialFile EXCEPTION: " . $e->getMessage() . "\\n";
        }
    }
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/check_materials.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/check_materials.php && rm -f /home/hersolot/app.hersolan.pro/check_materials.php")
print(stdout.read().decode('utf-8', errors='replace'))
ssh.close()
