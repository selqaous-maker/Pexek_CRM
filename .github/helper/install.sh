#!/bin/bash

set -e

cd ~ || ex

sudo apt update
sudo apt remove mysql-server mysql-client
sudo apt install libcups2-dev redis-server mariadb-client libmariadb-dev

# Frappe (and erpnext) branch to test against; set by CI matrix, defaults to develop.
FRAPPE_BRANCH="${FRAPPE_BRANCH:-develop}"

pip install frappe-bench
git clone "https://github.com/frappe/frappe" --branch "${FRAPPE_BRANCH}" --depth 1
bench init --skip-assets --frappe-path ~/frappe --python "$(which python)" frappe-bench

mkdir ~/frappe-bench/sites/test_site

CI_DB_PASSWORD="${CI_DB_PASSWORD:-$(openssl rand -hex 16)}"
CI_ROOT_PASSWORD="${CI_ROOT_PASSWORD:-$(openssl rand -hex 16)}"
CI_ADMIN_PASSWORD="${CI_ADMIN_PASSWORD:-$(openssl rand -hex 16)}"
sed -e "s/__CI_DB_PASSWORD__/${CI_DB_PASSWORD}/g" \
    -e "s/__CI_MAIL_PASSWORD__/${CI_ADMIN_PASSWORD}/g" \
    -e "s/__CI_ADMIN_PASSWORD__/${CI_ADMIN_PASSWORD}/g" \
    -e "s/__CI_ROOT_PASSWORD__/${CI_ROOT_PASSWORD}/g" \
    -e "s/__CI_ROOT_LOGIN__/ci_root/g" \
    "${GITHUB_WORKSPACE}/.github/helper/site_config.json" > ~/frappe-bench/sites/test_site/site_config.json

mariadb --host 127.0.0.1 --port 3306 -u root -p"${CI_ROOT_PASSWORD}" -e "SET GLOBAL character_set_server = 'utf8mb4'"
mariadb --host 127.0.0.1 --port 3306 -u root -p"${CI_ROOT_PASSWORD}" -e "SET GLOBAL collation_server = 'utf8mb4_unicode_ci'"

mariadb --host 127.0.0.1 --port 3306 -u root -p"${CI_ROOT_PASSWORD}" -e "CREATE USER 'test_frappe'@'localhost' IDENTIFIED BY '${CI_DB_PASSWORD}'"
mariadb --host 127.0.0.1 --port 3306 -u root -p"${CI_ROOT_PASSWORD}" -e "CREATE DATABASE test_frappe"
mariadb --host 127.0.0.1 --port 3306 -u root -p"${CI_ROOT_PASSWORD}" -e "GRANT ALL PRIVILEGES ON \`test_frappe\`.* TO 'test_frappe'@'localhost'"

mariadb --host 127.0.0.1 --port 3306 -u root -p"${CI_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES"

install_whktml() {
    wget -O /tmp/wkhtmltox.tar.xz https://github.com/frappe/wkhtmltopdf/raw/master/wkhtmltox-0.12.3_linux-generic-amd64.tar.xz
    tar -xf /tmp/wkhtmltox.tar.xz -C /tmp
    sudo mv /tmp/wkhtmltox/bin/wkhtmltopdf /usr/local/bin/wkhtmltopdf
    sudo chmod o+x /usr/local/bin/wkhtmltopdf
}
install_whktml &

cd ~/frappe-bench || exit

sed -i 's/watch:/# watch:/g' Procfile
sed -i 's/schedule:/# schedule:/g' Procfile
sed -i 's/socketio:/# socketio:/g' Procfile
sed -i 's/redis_socketio:/# redis_socketio:/g' Procfile

bench get-app crm "${GITHUB_WORKSPACE}"

# Only pull erpnext when the integration is under test, to keep other runs fast.
if [ "${INSTALL_ERPNEXT}" = "true" ]; then
    bench get-app erpnext --branch "${FRAPPE_BRANCH}"
fi

bench setup requirements --dev

bench start &>> ~/frappe-bench/bench_start.log &
CI=Yes bench build --app frappe &
bench --site test_site reinstall --yes

if [ "${INSTALL_ERPNEXT}" = "true" ]; then
    bench --verbose --site test_site install-app erpnext crm
else
    bench --verbose --site test_site install-app crm
fi
