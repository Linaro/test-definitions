#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

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
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

# Install lamp and use systemctl for service management. Tested on Ubuntu 16.04,
# Debian 8, CentOS 7 and Fedora 24. systemctl should available on newer releases
# as well.
if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    warn_msg "LAMP package installation skipped"
else
    dist_name
    case "${dist}" in
      Debian|Ubuntu)
        if [ "${dist}" = "Debian" ]; then
            pkgs="apache2 mysql-server php5-mysql php5-common libapache2-mod-php5"
        elif [ "${dist}" = "Ubuntu" ]; then
            pkgs="apache2 mysql-server php-mysql php-common libapache2-mod-php"
        fi
        install_deps "curl ${pkgs}"
        echo "extension=mysqli.so" >> /etc/php5/apache2/php.ini
        systemctl restart apache2
        systemctl restart mysql
        ;;
      CentOS|Fedora)
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
curl -o "${OUPUT}/index.html" "http://localhost/index.html"
grep "Test Page for the Apache HTTP Server" "${OUPUT}/index.html"
check_return "apache2-test-page"

# Test MySQL.
mysqladmin -u root password lamptest
mysql --user="root" --password="lamptest" -e "show databases"
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
