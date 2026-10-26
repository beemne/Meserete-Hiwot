#!/bin/bash
set -e

# 1. Load local environment variables
if [ -f .env ]; then
  source .env
elif [ -f .env-ssh ]; then
  source .env-ssh
fi

SERVER_HOST=${SERVER_HOST:-"hersolan.pro"}
SSH_PORT=${SSH_PORT:-22}
SSH_USER=${SSH_USER:-"hersolot"}
SSH_PASS=${SSH_PASS:-"v:89]yYLi:7t7O0E)0*"}
NEW_SUBDOMAIN=${NEW_SUBDOMAIN:-"app"}
NEW_DB_NAME=${NEW_DB_NAME:-"appdb"}
NEW_DB_USER=${NEW_DB_USER:-"hersolot_yoni"}
NEW_DB_PASS=${NEW_DB_PASS:-"KAS@wifi1"}

echo "1. Creating new database via cPanel UAPI..."
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p $SSH_PORT ${SSH_USER}@${SERVER_HOST} \
  "uapi Mysql create_database name=${SSH_USER}_${NEW_DB_NAME} && \
   uapi Mysql set_privileges_on_database user=${NEW_DB_USER} database=${SSH_USER}_${NEW_DB_NAME} privileges=ALL%20PRIVILEGES"

echo "2. Creating subdomain root directory..."
TARGET_DIR="/home/${SSH_USER}/${NEW_SUBDOMAIN}.${SERVER_HOST}"
sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -p $SSH_PORT ${SSH_USER}@${SERVER_HOST} \
  "uapi SubDomain addsubdomain domain=${NEW_SUBDOMAIN} rootdomain=${SERVER_HOST} dir=${TARGET_DIR}"

echo "3. Uploading project files..."
if [ -f "project.zip" ]; then
    scp -P $SSH_PORT project.zip ${SSH_USER}@${SERVER_HOST}:${TARGET_DIR}/
    sshpass -p "$SSH_PASS" ssh -p $SSH_PORT ${SSH_USER}@${SERVER_HOST} "cd ${TARGET_DIR} && unzip -o project.zip && rm project.zip"
else
    rsync -avz -e "ssh -p $SSH_PORT" ./dist/ ${SSH_USER}@${SERVER_HOST}:${TARGET_DIR}/
fi

echo "4. Importing database migration (if database.sql exists)..."
if [ -f "database.sql" ]; then
    scp -P $SSH_PORT database.sql ${SSH_USER}@${SERVER_HOST}:${TARGET_DIR}/
    sshpass -p "$SSH_PASS" ssh -p $SSH_PORT ${SSH_USER}@${SERVER_HOST} \
      "mysql -u ${NEW_DB_USER} -p'${NEW_DB_PASS}' ${SSH_USER}_${NEW_DB_NAME} < ${TARGET_DIR}/database.sql && rm ${TARGET_DIR}/database.sql"
fi

echo "Deployment finished successfully!"
