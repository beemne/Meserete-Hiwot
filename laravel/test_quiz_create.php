<?php

require __DIR__ . '/vendor/autoload.php';
$app = require_once __DIR__ . '/bootstrap/app.php';
$kernel = $app->make(Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

use App\Mz\Auth\AuthContext;
use App\Mz\Services\EduQuizzes;
use App\Mz\Services\EduLearning;
use Illuminate\Support\Facades\DB;

echo "DB connection: " . DB::connection()->getName() . PHP_EOL;
echo "DB database: " . DB::connection()->getDatabaseName() . PHP_EOL;
try {
    $subjects = DB::table('edu_subjects')->select('id', 'name')->limit(5)->get();
    echo "Subjects: " . $subjects->toJson() . PHP_EOL;
    $admins = DB::table('users')->where('role', 'admin')->orWhere('is_admin', 1)->select('id', 'name', 'phone')->limit(5)->get();
    echo "Admins: " . $admins->toJson() . PHP_EOL;
} catch (\Throwable $e) {
    echo "DB Error: " . $e->getMessage() . PHP_EOL;
}
