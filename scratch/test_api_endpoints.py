import paramiko
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

cmd = r"""cd /home/hersolot/app.hersolan.pro && php -r '
require "vendor/autoload.php";
$app = require_once "bootstrap/app.php";
$app->make("Illuminate\Contracts\Console\Kernel")->bootstrap();

$user = App\Mz\Auth\AuthContext::load(1);

$subjects = App\Mz\Services\EduLearning::subjects($user, null);
echo "SUBJECTS LIST COUNT: " . count($subjects) . "\n";
echo "SUBJECTS NAMES: " . implode(", ", array_column($subjects, "name")) . "\n";

$grades = App\Mz\Services\EduLearning::subjectGrades($user, 1);
echo "GRADES FOR SUBJECT 1:\n" . json_encode($grades, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

$contentG6 = App\Mz\Services\EduLearning::subjectGradeContent($user, 1, 6);
echo "CONTENT FOR SUBJECT 1, GRADE 6:\n" . json_encode($contentG6, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";

$contentG1 = App\Mz\Services\EduLearning::subjectGradeContent($user, 1, 1);
echo "CONTENT FOR SUBJECT 1, GRADE 1 (EMPTY):\n" . json_encode($contentG1, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE) . "\n";
'"""

stdin, stdout, stderr = ssh.exec_command(cmd)
print(stdout.read().decode('utf-8', errors='replace'))
print("STDERR:", stderr.read().decode('utf-8', errors='replace'))
ssh.close()
