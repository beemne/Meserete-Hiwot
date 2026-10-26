import json
import paramiko
import requests

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = 'v:89]yYLi:7t7O0E)0*'
TARGET_DIR = f'/home/{SSH_USER}/app.{SERVER_HOST}'

print("=== 1. Connecting to Production Server via SSH ===")
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS)

def run_artisan(expr):
    cmd = f'php {TARGET_DIR}/artisan tinker --execute="{expr}"'
    stdin, stdout, stderr = ssh.exec_command(cmd)
    out = stdout.read().decode('utf-8', errors='replace').strip()
    return out

# Check migrate status
print("\n=== 2. Checking Migration Status on Production ===")
stdin, stdout, stderr = ssh.exec_command(f'php {TARGET_DIR}/artisan migrate:status')
status_out = stdout.read().decode('utf-8', errors='replace').strip()
print(status_out[-500:])

# Check schema on MariaDB
print("\n=== 3. Checking Database Schema on Production ===")
mag_cols = run_artisan("echo json_encode(Schema::getColumnListing('edu_magazines'));")
print("edu_magazines columns:", mag_cols)

quiz_cols = run_artisan("echo json_encode(Schema::getColumnListing('edu_quizzes'));")
print("edu_quizzes has magazine_id:", 'magazine_id' in quiz_cols)

items_cols = run_artisan("echo json_encode(Schema::getColumnListing('items'));")
print("items has magazine_id & course_id:", 'magazine_id' in items_cols and 'course_id' in items_cols)

ans_cols = run_artisan("echo json_encode(Schema::getColumnListing('edu_quiz_answers'));")
print("edu_quiz_answers has feedback & graded_at:", 'feedback' in ans_cols and 'graded_at' in ans_cols)

# Check existing data counts
print("\n=== 4. Checking Existing Data Preservation ===")
data_counts = run_artisan(
    "echo json_encode(["
    "'users' => DB::table('users')->count(),"
    "'items' => DB::table('items')->count(),"
    "'library_copies' => Schema::hasTable('library_copies') ? DB::table('library_copies')->count() : 0,"
    "'library_loans' => Schema::hasTable('library_loans') ? DB::table('library_loans')->count() : 0,"
    "'edu_quizzes' => DB::table('edu_quizzes')->count(),"
    "'edu_quiz_attempts' => DB::table('edu_quiz_attempts')->count(),"
    "'edu_quiz_answers' => DB::table('edu_quiz_answers')->count()"
    "]);"
)
print("Production Data Counts (Preserved):", data_counts)

# Test HTTP endpoints
print("\n=== 5. Testing Production Public HTTP Endpoints ===")
base_url = "https://app.hersolan.pro"

# Health
r = requests.get(f"{base_url}/health", verify=False, timeout=10)
print(f"GET /health: {r.status_code} -> {r.text[:100]}")

# Magazines (anonymous / public or token)
r = requests.get(f"{base_url}/edu/magazines", verify=False, timeout=10)
print(f"GET /edu/magazines: {r.status_code} -> {r.text[:150]}")

r = requests.get(f"{base_url}/edu/magazines/latest", verify=False, timeout=10)
print(f"GET /edu/magazines/latest: {r.status_code} -> {r.text[:150]}")

# APK Release Download
r = requests.head(f"{base_url}/app-release.apk", verify=False, timeout=10)
print(f"HEAD /app-release.apk: {r.status_code}, Length: {r.headers.get('content-length')}, Accept-Ranges: {r.headers.get('accept-ranges')}")

# Web app entry point
r = requests.get(f"{base_url}/version.json", verify=False, timeout=10)
print(f"GET /version.json: {r.status_code} -> {r.text.strip()}")

ssh.close()
print("\n=== Verification Finished ===")
