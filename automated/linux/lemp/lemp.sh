#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
TEST_LIST="test-nginx-server mysql-show-databases test-phpinfo
           php-connect-db php-create-db php-create-table php-add-record
           php-select-record php-delete-record"

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

dist_name
# Install and configure LEMP.
# systemctl available on Debian 8, CentOS 7 and newer releases.
# shellcheck disable=SC2154
case "${dist}" in
    debian)
        # Stop apache server in case it is installed and running.
        systemctl stop apache2 > /dev/null 2>&1 || true

        install_deps "nginx mysql-server php5-mysql php5-fpm curl"

        systemctl restart nginx
        systemctl restart mysql

        # Configure PHP.
        cp /etc/php5/fpm/php.ini /etc/php5/fpm/php.ini.bak
        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
        systemctl restart php5-fpm

        # Configure NGINX for PHP.
        mv -f /etc/nginx/sites-available/default /etc/nginx/sites-available/default.bak
        cp ./debian-nginx.conf /etc/nginx/sites-available/default
        systemctl restart nginx
        ;;
    centos)
        # x86_64 nginx package can be installed from epel repo. However, epel
        # project doesn't support ARM arch yet. RPB repo should provide nginx.
        [ "$(uname -m)" = "x86_64" ] && install_deps "epel-release"
        pkgs="nginx mariadb-server mariadb php php-mysql php-fpm curl"
        install_deps "${pkgs}"

        # Stop apache server in case it is installed and running.
        systemctl stop httpd.service > /dev/null 2>&1 || true

        systemctl restart nginx
        systemctl restart mariadb

        # Configure PHP.
        cp /etc/php.ini /etc/php.ini.bak
        sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php.ini
        sed -i "s/listen.allowed_clients = 127.0.0.1/listen = \/run\/php-fpm\/php-fpm.sock/" /etc/php-fpm.d/www.conf
        sed -i "s/;listen.owner = nobody/listen.owner = nginx/" /etc/php-fpm.d/www.conf
        sed -i "s/;listen.group = nobody/listen.group = nginx/" /etc/php-fpm.d/www.conf
        sed -i "s/user = apache/user = nginx/" /etc/php-fpm.d/www.conf
        sed -i "s/group = apache/group = nginx/" /etc/php-fpm.d/www.conf
        # This creates the needed php-fpm.sock file
        systemctl restart php-fpm
        chmod 666 /run/php-fpm/php-fpm.sock
        chown nginx:nginx /run/php-fpm/php-fpm.sock
        systemctl restart php-fpm

        # Configure NGINX for PHP.
        cp ./centos-nginx.conf /etc/nginx/default.d/default.conf
        systemctl restart nginx
        ;;
    *)
        info_msg "Supported distributions: Debian, CentOS"
        error_msg "Unsupported distribution: ${dist}"
        ;;
esac

# Copy pre-defined html/php files to root directory.
mv -f /usr/share/nginx/html /usr/share/nginx/html.bak
mkdir -p /usr/share/nginx/html
cp ./html/* /usr/share/nginx/html/

# Test Nginx.
skip_list="$(echo "${TEST_LIST}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/index.html" "http://localhost/index.html"
test_command="grep 'Test Page for the Nginx HTTP Server' ${OUTPUT}/index.html"
run_test_case "${test_command}" "test-nginx-server" "${skip_list}"

# Test MySQL.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
mysqladmin -u root password lxmptest > /dev/null 2>&1 || true
test_command="mysql --user='root' --password='lxmptest' -e 'show databases'"
run_test_case "${test_command}" "mysql-show-databases" "${skip_list}"

# Test PHP.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/phpinfo.html" "http://localhost/info.php"
test_command="grep 'PHP Version' ${OUTPUT}/phpinfo.html"
run_test_case "${test_command}" "test-phpinfo" "${skip_list}"

# PHP Connect to MySQL.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/connect-db" "http://localhost/connect-db.php"
test_command="grep 'Connected successfully' ${OUTPUT}/connect-db"
run_test_case "${test_command}" "php-connect-db" "${skip_list}"

# PHP Create a MySQL Database.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/create-db" "http://localhost/create-db.php"
test_command="grep 'Database created successfully' ${OUTPUT}/create-db"
run_test_case "${test_command}" "php-create-db" "${skip_list}"

# PHP Create MySQL table.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/create-table" "http://localhost/create-table.php"
test_command="grep 'Table MyGuests created successfully' ${OUTPUT}/create-table"
run_test_case "${test_command}" "php-create-table" "${skip_list}"

# PHP add record to MySQL table.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/add-record" "http://localhost/add-record.php"
test_command="grep 'New record created successfully' ${OUTPUT}/add-record"
run_test_case "${test_command}" "php-create-recoard" "${skip_list}"

# PHP select record from MySQL table.
skip_list="$(echo "${skip_list}" | awk '{ for (i=2; i<=NF; i++) print $i}')"
curl -o "${OUTPUT}/select-record" "http://localhost/select-record.php"
test_command="grep 'id: 1 - Name: John Doe' ${OUTPUT}/select-record"
run_test_case "${test_command}" "php-select-record" "${skip_list}"

# PHP delete record from MySQL table.
curl -o "${OUTPUT}/delete-record" "http://localhost/delete-record.php"
test_command="grep 'Record deleted successfully' ${OUTPUT}/delete-record"
run_test_case "${test_command}" "php-delete-record"

# Cleanup.
# Delete myDB for the next run.
mysql --user='root' --password='lxmptest' -e 'DROP DATABASE myDB'

# Restore from backups.
rm -rf /usr/share/nginx/html
mv /usr/share/nginx/html.bak /usr/share/nginx/html
# shellcheck disable=SC2154
case "${dist}" in
    debian)
        mv -f /etc/php5/fpm/php.ini.bak /etc/php5/fpm/php.ini
        mv -f /etc/nginx/sites-available/default.bak /etc/nginx/sites-available/default
        ;;
    centos)
        mv -f /etc/php.ini.bak /etc/php.ini
        rm -f /etc/nginx/default.d/default.conf
        ;;
esac
