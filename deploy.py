import os
import shutil
import zipfile
import paramiko
import sys
import hashlib

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
if hasattr(sys.stderr, 'reconfigure'):
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')

SERVER_HOST = 'hersolan.pro'
SSH_PORT = 22
SSH_USER = 'hersolot'
SSH_PASS = 'v:89]yYLi:7t7O0E)0*'
TARGET_SUBDOMAIN = 'app'
TARGET_DIR = f'/home/{SSH_USER}/{TARGET_SUBDOMAIN}.{SERVER_HOST}'
DB_NAME = f'{SSH_USER}_appdb'
DB_USER = 'hersolot_yoni'
DB_PASS = 'KAS@wifi1'

def package_project(zip_filename='project.zip'):
    print(f'Packaging project into {zip_filename}...')
    if os.path.exists(zip_filename):
        os.remove(zip_filename)
        
    with zipfile.ZipFile(zip_filename, 'w', zipfile.ZIP_DEFLATED) as z:
        # 1. Add laravel files (excluding vendor and storage/logs/framework caches)
        for root, dirs, files in os.walk('laravel'):
            # Ignore vendor, .git, tests, storage, .phpunit.cache
            if 'vendor' in root.split(os.sep) or '.git' in root.split(os.sep) or 'storage' in root.split(os.sep):
                continue
            for f in files:
                # Local .env files are never shipped: the server keeps its own .env (written below).
                # Shipping laravel/.env replaced it for a few seconds per deploy (DB user root → errors).
                if f.endswith('.log') or f == '.phpunit.result.cache' or f.startswith('.env'):
                    continue
                file_path = os.path.join(root, f)
                rel_path = os.path.relpath(file_path, 'laravel')
                z.write(file_path, rel_path)
                
        # 2. Add flutter web build to public/
        web_dir = 'mobile/mobile/build/web'
        if os.path.exists(web_dir):
            print('Adding Flutter web build into public/...')
            for root, dirs, files in os.walk(web_dir):
                for f in files:
                    file_path = os.path.join(root, f)
                    rel_path = os.path.relpath(file_path, web_dir)
                    target_zip_path = os.path.join('public', rel_path).replace('\\', '/')
                    z.write(file_path, target_zip_path)
                    
        # 3. Add root .htaccess to forward requests to public/
        root_htaccess = '''<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_URI} !^/public/
    RewriteRule ^(.*)$ public/$1 [L,QSA]
</IfModule>

<Files .env>
    Order allow,deny
    Deny from all
</Files>
'''
        z.writestr('.htaccess', root_htaccess)
        
        # 4. Add root index.php as fallback
        root_index = '''<?php
// Forward to public/index.php
require __DIR__ . '/public/index.php';
'''
        z.writestr('index.php', root_index)

    print(f'Project packaged successfully ({os.path.getsize(zip_filename)} bytes).')

def deploy():
    package_project('project.zip')
    
    print(f'Connecting to {SERVER_HOST} via SSH...')
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(SERVER_HOST, port=SSH_PORT, username=SSH_USER, password=SSH_PASS, timeout=60, banner_timeout=60, auth_timeout=60)
    
    # Ensure vendor dependencies exist without duplicating
    print('Checking vendor dependencies on server...')
    ssh.exec_command(f'rm -rf {TARGET_DIR}/vendor/vendor')
    stdin, stdout, stderr = ssh.exec_command(f'[ -d {TARGET_DIR}/vendor ] || cp -a /home/{SSH_USER}/mhs.{SERVER_HOST}/vendor {TARGET_DIR}/vendor')
    stdout.channel.recv_exit_status()
    
    # Upload project.zip via SFTP
    print(f'Uploading project.zip ({os.path.getsize("project.zip"):,} bytes) to {TARGET_DIR}/...')
    sftp = ssh.open_sftp()
    last_pct = [0]
    def zip_progress(transferred, total):
        pct = int((transferred / total) * 100)
        if pct >= last_pct[0] + 10 or pct == 100:
            print(f'  project.zip upload progress: {pct}% ({transferred:,} / {total:,} bytes)')
            last_pct[0] = pct
    sftp.put('project.zip', f'{TARGET_DIR}/project.zip', callback=zip_progress)
    sftp.close()
    
    # Extract project.zip remotely
    print('Extracting project.zip on server...')
    stdin, stdout, stderr = ssh.exec_command(f'cd {TARGET_DIR} && unzip -o project.zip && rm -f project.zip')
    out = stdout.read().decode('utf-8', errors='replace')
    err = stderr.read().decode('utf-8', errors='replace')
    print('Extract done.')
    if err:
        print('Extract stderr:', err[:300])
        
    # Write production .env remotely
    print('Setting up production .env...')
    prod_env = f'''APP_NAME="Meserete Hiwot"
APP_ENV=production
APP_KEY=base64:Q+LSM0tVbukjw3CZwCaCkog87gYztiJXaNUJ0pyL3FY=
DATA_ENCRYPTION=true
DATA_ENCRYPTION_KEY=
DATA_ENCRYPTION_OLD_KEYS=
APP_DEBUG=false
APP_URL=https://app.{SERVER_HOST}
PUBLIC_BASE_URL=https://app.{SERVER_HOST}

APP_LOCALE=en
APP_FALLBACK_LOCALE=en
APP_FAKER_LOCALE=en_US

APP_MAINTENANCE_DRIVER=file

PHP_CLI_SERVER_WORKERS=4
BCRYPT_ROUNDS=12

LOG_CHANNEL=stack
LOG_STACK=single
LOG_DEPRECATIONS_CHANNEL=null
LOG_LEVEL=error

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE={DB_NAME}
DB_USERNAME={DB_USER}
DB_PASSWORD={DB_PASS}

SESSION_DRIVER=file
SESSION_LIFETIME=120
SESSION_ENCRYPT=false
SESSION_PATH=/
SESSION_DOMAIN=null

BROADCAST_CONNECTION=log
FILESYSTEM_DISK=local
QUEUE_CONNECTION=sync
CACHE_STORE=file

MEMCACHED_HOST=127.0.0.1
REDIS_CLIENT=phpredis
REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_SCHEME=null
MAIL_HOST=127.0.0.1
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_FROM_ADDRESS="hello@example.com"
MAIL_FROM_NAME="Meserete Hiwot"

# --- Timezone & CORS ---
APP_TIMEZONE=Africa/Addis_Ababa
CORS_ORIGINS=http://localhost:8000,http://localhost:3000,http://localhost:4000,http://localhost:5000,https://app.{SERVER_HOST},http://app.{SERVER_HOST},https://mhs.{SERVER_HOST},https://mh.{SERVER_HOST},https://api.mh.{SERVER_HOST}
TRUST_PROXY=0

# --- JWT ---
JWT_SECRET=397a90ddf325b2b05d7e9f5a9cd67d38f927b987678f404ca6a9972b13388878bdf974a1db286b460587777e93e2103a
JWT_REFRESH_SECRET=97e6a7501e963f6d5b156528617d848dd4d65d3a7fda15a77ef157bfb1d70bf77eea9516157b3b3aceab8c8f5c576b0a
JWT_ACCESS_TTL=15m
JWT_REFRESH_TTL_DAYS=0
JWT_ISSUER=mezmur-zelideta-api
JWT_AUDIENCE=mezmur-zelideta-app

# --- Internal System Authority ---
SYSTEM_ENCRYPTION_KEY=b4128795c5282aba17e6369fb8add84c4fd9a52161296e5d6c3dc530b39f9a48
SYSTEM_ACCESS_TTL=10m
SYSTEM_REFRESH_TTL_HOURS=0
SYSTEM_ALLOWED_IPS=

# --- Firebase Cloud Messaging (server credentials; backend only) ---
FIREBASE_PROJECT_ID=mezmur-zelideta
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@mezmur-zelideta.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\\nMIIEvAIBADANBgkqhkiG9w0BAQEFAASCBKYwggSiAgEAAoIBAQCuvQvFpSLmahOS\\nQOuCFjc9usYTYmWIs9ZjNSJ15GULhRnTVmrxGZ938Ojn7FdiNrNot49NbH0XP59O\\n5fvKEqLzgAOTwoSox5c4Dbbom2gZyaia+5V7ijQLkNQQaC5YVQt0No74Lbavv3M/\\nOtxt8WkDeOx5FZtrHMe06y8LgP/XhRDM7lf47Bvpa0JNImAIEFjevPJkjM381Yz3\\n9eWSQicRi2aoEDxm246sUdT5HwBZi3pHSqvZxipQz/gK54heH+xJlROYiPiYXJwO\\nPtJ+t3tRaa3ASnSznd9Ls4zF4/oyBhzNnW4kfkZjs8XwYU/1McED3vluFdekX2NE\\nMAwJ1z6HAgMBAAECggEAIs/d5wfhvpbWhFYztSx43+70ZEs/oC734LbmwSb57IQd\\nY4m9b4Aj0ZDozb+7nwD32D5tqcaZ20ZdFipicd0poqpXzBm+NSPiYBP3YzsGz9Bp\\nq0rA+qZLfRxi60veI9H5oLL348CzuyrAqpGu9aZZPgxazDq+RmYq8UPDkR6nmceA\\nCg0nKZbcW362WJPePAVeUts5BO1urec7MYoidBUq2FiyWVyRdAniy1j5+cZmO+0P\\nQayImlZCa7ya3PG0RT+FhwX0AdMRQbLu36U8qrHi33WF8dgHjBd4Hz4pXPWACsL2\\nz+MHZtPXpur8f2Isfy508G/pkpLV23Zw2dXD6kM3TQKBgQDXgNaSFQfBafNAlU4H\\nxgPqs7tzViuJizrPNfym8ssV6yAazJE6XAq5QwN4WqULWCnamfDTdbFvJG+Ayz10\\nuWdLbbaEFaAwKPj/JGsGOd3wQ4dP9OO3VpFC48nu1cMb810HIJ02uBZylxstbDM5\\nLhzMYhFbkgFReSJuXm+r/8BP4wKBgQDPkyUrlmJ8qoZLKRrxm3Ry8p1slVYl5i4g\\nOB6YpQV3BLk4ixRKStOF6OnefdK/Yif8MEqOXe1TXRmVj287TLqI3mOnJu5UhcbV\\nTUW4BCKyJ2Agzy0bVoALJIHzwYFiUCFaZsz/QwKdrbPP46nIXKfM8IdQsj2NpKYx\\nCWyeWacQDQKBgF/fbZYnzP97B0EgK0rCCVQNCcPR/iR+0HcG6ZPMSBVEOVAy2hlA\\ngXTSH2UXzn0xh8081yr8HSf46bI+uOSI5y9ja+NvS4ihccTwiryGWfpd0ID9zaDu\\n3kkH1fpvFxIEPsrA87A4TaRFHU4j6NXzcdRrfJVkazm3zl2TndLDQOdJAoGAAjHn\\nIbfcYL8Y3nCX1Vg0egawvXYyzAHMGREe2bRdA24sWzm1RDfYVsEov+6KrPVnwNXt\\n4+WAXfJNE/TJU1IzYsEfQqQ5vvEPMjA3/YMlrsaV0KMAMhrPDc8cBKzWJmj8gU02\\n+7gErhApJ5ibsf+w0oz0kVjhJ79G9pvH50DBcH0CgYBMWM1zcQ6HElzoNzxjvK2D\\nyygt1u3lOuknWFhPBTP/s3lcbvMJ6OdeNpcNUvMjFOZHv130lnVQh3APdy6TFoIo\\nV+mk+3wNY5d6BGNaeVc/uvQq+Ww7t2AIStj/uFH6ZBiQuq17DlMCZdUlAoYJy5Cx\\nEwSkWWQ9RgdJFmgimgt9Ew==\\n-----END PRIVATE KEY-----\\n"
'''
    sftp = ssh.open_sftp()
    with sftp.file(f'{TARGET_DIR}/.env', 'w') as f:
        f.write(prod_env)
    sftp.close()
    
    # Fix directory permissions & storage symlink
    print('Ensuring directory permissions and storage symlink...')
    ssh.exec_command(f'mkdir -p {TARGET_DIR}/storage/framework/views {TARGET_DIR}/storage/framework/cache {TARGET_DIR}/storage/framework/sessions {TARGET_DIR}/storage/logs {TARGET_DIR}/bootstrap/cache {TARGET_DIR}/storage/mz/public')
    ssh.exec_command(f'chmod -R 775 {TARGET_DIR}/storage {TARGET_DIR}/bootstrap/cache')
    ssh.exec_command(f'chmod -R 777 {TARGET_DIR}/storage/mz/public')
    ssh.exec_command(f'[ -L {TARGET_DIR}/public/files ] || ln -s ../storage/mz/public {TARGET_DIR}/public/files')
    
    # Upload APK if exists and register release in database
    apk_path = 'mobile/mobile/build/app/outputs/flutter-apk/app-release.apk'
    if os.path.exists(apk_path):
        apk_size = os.path.getsize(apk_path)
        print(f'Uploading {apk_path} ({apk_size:,} bytes) to public/app-release.apk...')
        
        # Calculate SHA256
        sha256_hash = hashlib.sha256()
        with open(apk_path, 'rb') as f:
            for byte_block in iter(lambda: f.read(65536), b""):
                sha256_hash.update(byte_block)
        apk_sha256 = sha256_hash.hexdigest()
        
        sftp = ssh.open_sftp()
        last_pct = [0]
        def progress_callback(transferred, total):
            pct = int((transferred / total) * 100)
            if pct >= last_pct[0] + 10 or pct == 100:
                print(f'  APK upload progress: {pct}% ({transferred:,} / {total:,} bytes)')
                last_pct[0] = pct
        sftp.put(apk_path, f'{TARGET_DIR}/public/app-release.apk', callback=progress_callback)
        sftp.chmod(f'{TARGET_DIR}/public/app-release.apk', 0o644)
        
        # Also copy to private/releases for download system
        print('Ensuring private releases directory exists...')
        ssh.exec_command(f'mkdir -p {TARGET_DIR}/storage/mz/private/releases')
        remote_release_path = 'private/releases/release-1.5.3-27.apk'
        print(f'Uploading to {TARGET_DIR}/storage/mz/{remote_release_path}...')
        sftp.put(apk_path, f'{TARGET_DIR}/storage/mz/{remote_release_path}')
        sftp.chmod(f'{TARGET_DIR}/storage/mz/{remote_release_path}', 0o644)
        sftp.close()
        print('APK upload complete.')

        # Register in app_releases table
        print('Registering release 1.5.3+27 in app_releases database table...')
        notes = "Quiz attempt limits enforcement, direct course materials without lessons, canonical grade access separation, Google Classroom assignments & teacher announcements."
        sql = (
            f"INSERT INTO app_releases (platform, version_name, version_code, file_path, file_size, sha256, release_notes, min_supported_code, is_mandatory, is_published, download_count, created_at) "
            f"VALUES ('android', '1.5.3', 27, '{remote_release_path}', {apk_size}, '{apk_sha256}', '{notes}', 26, 0, 1, 0, NOW()) "
            f"ON DUPLICATE KEY UPDATE version_name='1.5.3', file_path='{remote_release_path}', file_size={apk_size}, sha256='{apk_sha256}', release_notes='{notes}', min_supported_code=26, is_mandatory=0, is_published=1;"
        )
        cmd = f"mysql -u {DB_USER} -p'{DB_PASS}' {DB_NAME} -e \"{sql}\""
        stdin, stdout, stderr = ssh.exec_command(cmd)
        stdout.read()
        err = stderr.read().decode('utf-8', errors='replace')
        if err and 'Deprecated program name' not in err:
            print('Release DB registration warning/error:', err)
        else:
            print('Release 1.5.3+26 registered successfully in database.')
    
    # Run migrations and seeders
    print('Running migrations, cache clears and GuidanceSeeder on server...')
    artisan_cmd = (
        f'cd {TARGET_DIR} && '
        'php artisan config:clear && '
        'php artisan cache:clear && '
        'php artisan route:clear && '
        'php artisan view:clear && '
        'php artisan optimize:clear && '
        'php artisan migrate --force && '
        'php artisan db:seed --class=GuidanceSeeder --force'
    )
    stdin, stdout, stderr = ssh.exec_command(artisan_cmd)
    print('Artisan output:\n', stdout.read().decode('utf-8', errors='replace'))
    err = stderr.read().decode('utf-8', errors='replace')
    if err:
        print('Artisan stderr:\n', err)
        
    # Test HTTP endpoints
    print('Testing HTTP responses...')
    stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/health')
    print('CURL /health:\n', stdout.read().decode('utf-8', errors='replace'))
    
    stdin, stdout, stderr = ssh.exec_command(f'curl -sI -k https://app.{SERVER_HOST}/')
    print('CURL / (root):\n', stdout.read().decode('utf-8', errors='replace'))

    stdin, stdout, stderr = ssh.exec_command(f'curl -s -k https://app.{SERVER_HOST}/api/v1/app/version?version_code=26')
    print('CURL /api/v1/app/version:\n', stdout.read().decode('utf-8', errors='replace'))
    
    ssh.close()
    print('Deployment completed successfully!')

if __name__ == '__main__':
    deploy()
