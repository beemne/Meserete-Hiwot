import paramiko
import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

php_code = """<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$app->make('Illuminate\\Contracts\\Console\\Kernel')->bootstrap();

echo "=== CATEGORIES ===\\n";
$cats = DB::table('edu_categories')->get();
foreach ($cats as $c) {
    echo "ID: {$c->id} | Name: {$c->name} | Order: {$c->sort_order} | Status: {$c->status}\\n";
}

echo "\\n=== SUBJECTS ===\\n";
$subs = DB::table('edu_subjects')->get();
foreach ($subs as $s) {
    echo "ID: {$s->id} | CatID: {$s->category_id} | Name: {$s->name} | Code: {$s->code} | Status: {$s->status}\\n";
}

echo "\\n=== LESSONS ===\\n";
$lessons = DB::table('edu_lessons')->get();
foreach ($lessons as $l) {
    echo "ID: {$l->id} | SubID: {$l->subject_id} | UnitID: {$l->unit_id} | Title: {$l->title} | Status: {$l->status}\\n";
}

echo "\\n=== COURSES ===\\n";
$courses = DB::table('edu_courses')->get();
foreach ($courses as $co) {
    echo "ID: {$co->id} | SubID: {$co->subject_id} | ClassID: {$co->class_id} | Name: {$co->name} | Status: {$co->status}\\n";
}
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
print(out)
ssh.close()
