#!/usr/bin/env bash

set -euo pipefail

CRM_SITE_NAME="${CRM_SITE_NAME:-crm.localhost}"
: "${DB_ROOT_PASSWORD:?DB_ROOT_PASSWORD must be set}"
: "${ADMIN_PASSWORD:?ADMIN_PASSWORD must be set}"

if [ -d "/home/frappe/frappe-bench/apps/frappe" ]; then
    echo "Bench already exists, skipping init"
    cd frappe-bench
    exec bench start
else
    echo "Creating new bench..."
fi

bench init --skip-redis-config-generation frappe-bench --version version-16

cd frappe-bench

# Use containers instead of localhost
bench set-mariadb-host mariadb
bench set-redis-cache-host redis://redis:6379
bench set-redis-queue-host redis://redis:6379
bench set-redis-socketio-host redis://redis:6379

# Remove redis, watch from Procfile
sed -i '/redis/d' ./Procfile
sed -i '/watch/d' ./Procfile

bench get-app /workspace/crm

bench new-site "$CRM_SITE_NAME" \
    --force \
    --mariadb-root-password "$DB_ROOT_PASSWORD" \
    --admin-password "$ADMIN_PASSWORD" \
    --no-mariadb-socket

bench --site "$CRM_SITE_NAME" install-app crm
bench --site "$CRM_SITE_NAME" set-config developer_mode 1
bench --site "$CRM_SITE_NAME" set-config mute_emails 1
bench --site "$CRM_SITE_NAME" set-config server_script_enabled 1
bench --site "$CRM_SITE_NAME" clear-cache
bench use "$CRM_SITE_NAME"

exec bench start
