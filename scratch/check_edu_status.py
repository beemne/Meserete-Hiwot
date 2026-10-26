import time
import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password=r'v:89]yYLi:7t7O0E)0*', timeout=20)

php_code = """<?php
require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make('Illuminate\\Contracts\\Http\\Kernel');

// Authenticate as User 1
$user = App\\Models\\User::first();
if ($user) {
    auth()->login($user);
    echo "Authenticated as: " . $user->name . " (" . $user->phone . ")\\n\\n";
}

// 1. Categories
$req1 = Illuminate\\Http\\Request::create('/api/v1/edu/categories', 'GET');
$res1 = $kernel->handle($req1);
echo "=== CATEGORIES (Status: " . $res1->getStatusCode() . ") ===\\n";
$data1 = json_decode($res1->getContent(), true);
$cats = $data1['data'] ?? [];
echo "Count: " . count($cats) . "\\n";
foreach ($cats as $c) {
    echo "  [ID " . $c['id'] . "] (Order " . $c['display_order'] . ") " . $c['name'] . " (icon: " . ($c['icon'] ?? '') . ")\\n";
}

// 2. Category 1 Subjects
$req2 = Illuminate\\Http\\Request::create('/api/v1/edu/categories/1/subjects', 'GET');
$res2 = $kernel->handle($req2);
echo "\\n=== CATEGORY 1 (ትምህርተ ሃይማኖት) GRADES/SUBJECTS (Status: " . $res2->getStatusCode() . ") ===\\n";
$data2 = json_decode($res2->getContent(), true);
$subs = $data2['data'] ?? [];
echo "Count: " . count($subs) . "\\n";
foreach ($subs as $s) {
    echo "  [Subject " . $s['id'] . "] " . $s['name'] . " (" . $s['code'] . ", order: " . $s['sort_order'] . ")\\n";
}
"""

sftp = ssh.open_sftp()
with sftp.open('/home/hersolot/app.hersolan.pro/test_edu.php', 'w') as f:
    f.write(php_code)
sftp.close()

stdin, stdout, stderr = ssh.exec_command('cd /home/hersolot/app.hersolan.pro && php test_edu.php 2>&1')
out = stdout.read().decode('utf-8', errors='replace')
err = stderr.read().decode('utf-8', errors='replace')
if err:
    print('STDERR:', err)
print(out)
ssh.close()
