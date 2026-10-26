<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Mz\Services\Settings;
use App\Mz\Http\ModuleGate;
use App\Mz\Auth\AuthContext;
use Illuminate\Support\Facades\DB;

$users = DB::table('users')->where('full_name', 'like', '%ዮናስ%')->get();
foreach ($users as $user) {
    echo "=== USER {$user->id} ({$user->full_name}) ===\n";
    echo "Phone: {$user->phone}, Status: {$user->status}, MemberGroup: {$user->member_group}, AccountType: {$user->account_type}, RoleId: {$user->role_id}\n";
    
    $auth = AuthContext::load($user->id);
    if (! $auth) {
        echo "Could not load AuthContext!\n";
        continue;
    }
    echo "AuthContext isSystem: " . ($auth->isSystem ? 'yes' : 'no') . ", isAdmin: " . ($auth->isAdmin ? 'yes' : 'no') . ", Role: " . json_encode($auth->role) . "\n";
    echo "Permissions count: " . count($auth->permissions) . "\n";
    echo "Sample permissions: " . implode(', ', array_slice(array_keys($auth->permissions), 0, 10)) . "\n";
    
    $allowed = ModuleGate::allows($auth, 'education');
    echo "ModuleGate::allows('education'): " . ($allowed ? 'YES' : 'NO') . "\n";

    try {
        $dash = \App\Mz\Services\EduDashboard::forUser($auth);
        echo "Dashboard OK! Keys: " . implode(', ', array_keys($dash)) . "\n";
        echo "Continue: " . json_encode($dash['continue']) . "\n";
        echo "Stats: " . json_encode($dash['stats']) . "\n";
    } catch (\Throwable $e) {
        echo "Dashboard EXCEPTION: " . $e->getMessage() . " (" . get_class($e) . ")\n";
        echo $e->getTraceAsString() . "\n";
    }
}
