import paramiko

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password='v:89]yYLi:7t7O0E)0*')

php = """<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\\Contracts\\Console\\Kernel::class);
$kernel->bootstrap();
use App\\Mz\\Auth\\AuthContext;
use App\\Mz\\Services\\EduLearning;
$auth = AuthContext::load(1);
try {
    $s = EduLearning::subjectDetail($auth, 1);
    echo "SUBJECT 1 OK: " . ($s['title'] ?? 'no title') . "\\n";
} catch (\\Throwable $e) {
    echo "SUBJECT ERR: " . $e->getMessage() . "\\n";
}
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/test_ep.php', 'w') as f:
    f.write(php)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('cd /home/hersolot/app.hersolan.pro && php test_ep.php && rm -f test_ep.php')
print(stdout.read().decode('utf-8', errors='replace'))
print(stderr.read().decode('utf-8', errors='replace'))
ssh.close()
