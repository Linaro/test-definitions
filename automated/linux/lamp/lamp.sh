#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Install lamp and use systemctl for service management. Tested on Ubuntu 16.04,
# Debian 8, CentOS 7 and Fedora 24. systemctl should available on newer releases
# as well.
if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    warn_msg "LAMP package installation skipped"
else
    # Stop nginx server in case it is installed and running.
    systemctl stop nginx > /dev/null 2>&1 || true

    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        # Tested on Debian 9 and Ubuntu 17.10.
        pkgs="apache2 apache2-utils libapache2-mod-php mariadb-server php php-mysql"
        install_deps "curl ${pkgs}"
        systemctl restart apache2
        systemctl restart mysql
        ;;
      centos|fedora)
        # Tested on CentOS 7.
        pkgs="httpd mariadb-server mariadb php php-mysql"
        install_deps "curl ${pkgs}"
        systemctl start httpd.service
        systemctl start mariadb
        ;;
      *)
        error_msg "Unsupported distribution!"
    esac
fi

cp ./html/* /var/www/html/

# Test Apache.
curl -o "${OUTPUT}/index.html" "http://localhost/index.html"
grep "Test Page for the Apache HTTP Server" "${OUTPUT}/index.html"
check_return "apache2-test-page"

# Setup MySQL authentication.
mysqladmin -u root password lxmptest  > /dev/null 2>&1 || true
mysql --user='root' --password='lxmptest' -e 'DROP USER admin@localhost' || true
mysql --user='root' --password='lxmptest' -e "CREATE USER admin@localhost IDENTIFIED BY 'password'"
mysql --user='root' --password='lxmptest' -e "GRANT ALL ON *.* TO admin@localhost WITH GRANT OPTION"

# Test MySQL.
mysql --user="admin" --password="password" -e "show databases"
check_return "mysql-show-databases"

# Test PHP.
curl -o "${OUTPUT}/phpinfo.html" "http://localhost/info.php"
grep "PHP Version" "${OUTPUT}/phpinfo.html"
check_return "phpinfo"

# PHP Connect to MySQL.
curl -o "${OUTPUT}/connect-db" "http://localhost/connect-db.php"
grep "Connected successfully" "${OUTPUT}/connect-db"
exit_on_fail "php-connect-db"

# PHP Create a MySQL Database.
curl -o "${OUTPUT}/create-db" "http://localhost/create-db.php"
grep "Database created successfully" "${OUTPUT}/create-db"
check_return "php-create-db"

# PHP Create MySQL table.
curl -o "${OUTPUT}/create-table" "http://localhost/create-table.php"
grep "Table MyGuests created successfully" "${OUTPUT}/create-table"
check_return "php-create-table"

# PHP add record to MySQL table.
curl -o "${OUTPUT}/add-record" "http://localhost/add-record.php"
grep "New record created successfully" "${OUTPUT}/add-record"
check_return "php-add-record"

# PHP select record from MySQL table.
curl -o "${OUTPUT}/select-record" "http://localhost/select-record.php"
grep "id: 1 - Name: John Doe" "${OUTPUT}/select-record"
check_return "php-select-record"

# PHP delete record from MySQL table.
curl -o "${OUTPUT}/delete-record" "http://localhost/delete-record.php"
grep "Record deleted successfully" "${OUTPUT}/delete-record"
check_return "php-delete-record"

# Delete myDB and admin for the next run.
mysql --user='admin' --password='password' -e 'DROP DATABASE myDB'
mysql --user='root' --password='lxmptest' -e 'DROP USER admin@localhost'
