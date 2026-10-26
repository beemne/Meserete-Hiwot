import paramiko
import sys
import json

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
use Illuminate\\Support\\Facades\\Schema;

$tables = DB::select("SHOW TABLES LIKE 'edu_%'");
$tableNames = array_map(function($t) { return array_values((array)$t)[0]; }, $tables);

$libTables = DB::select("SHOW TABLES LIKE 'lib%'");
$libTableNames = array_map(function($t) { return array_values((array)$t)[0]; }, $libTables);

$allTables = array_merge($tableNames, $libTableNames);

$res = [];
foreach ($allTables as $t) {
    $cols = DB::select("SHOW COLUMNS FROM `$t`");
    $res[$t] = array_map(function($c) { return $c->Field . ' (' . $c->Type . ')'; }, $cols);
}

echo "JSON_START\\n" . json_encode($res, JSON_PRETTY_PRINT) . "\\nJSON_END\\n";
"""

sftp = ssh.open_sftp()
with sftp.file('/home/hersolot/app.hersolan.pro/inspect_edu_db.php', 'w') as f:
    f.write(php_script)
sftp.close()

stdin, stdout, stderr = ssh.exec_command("php /home/hersolot/app.hersolan.pro/inspect_edu_db.php && rm -f /home/hersolot/app.hersolan.pro/inspect_edu_db.php")
output = stdout.read().decode('utf-8', errors='replace')
ssh.close()

if "JSON_START" in output:
    json_str = output.split("JSON_START")[1].split("JSON_END")[0].strip()
    data = json.loads(json_str)
    with open("scratch/edu_db_schema.json", "w", encoding="utf-8") as out_f:
        json.dump(data, out_f, indent=2)
    print(f"Successfully retrieved schema for {len(data)} tables. Saved to scratch/edu_db_schema.json")
    for t, cols in data.items():
        print(f"Table {t} ({len(cols)} columns):")
        print("  " + ", ".join(cols[:8]) + ("..." if len(cols) > 8 else ""))
else:
    print("Failed to get JSON. Output:")
    print(output)
    print("Stderr:")
    print(stderr.read().decode('utf-8', errors='replace'))
