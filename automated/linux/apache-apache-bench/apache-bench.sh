#!/bin/sh

. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/ablog.txt"

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

NUMBER=1000
CONCURENT=100

while getopts "s:n:c:" o; do
  case "$o" in
    n) NUMBER="${OPTARG}" ;;
    c) CONCURENT="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    *) usage ;;
  esac
done

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# Install apache and use systemctl for service management. Tested on Ubuntu 16.04,
# Debian 8, CentOS 7 and Fedora 24. systemctl should available on newer releases
# as well.
if [ "${SKIP_INSTALL}" = "True" ] || [ "${SKIP_INSTALL}" = "true" ]; then
    warn_msg "Apache package installation skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      debian|ubuntu)
        pkgs="apache2 apache2-utils"
        install_deps "${pkgs}"
        systemctl restart apache2
        ;;
      centos|fedora)
        pkgs="httpd httpd-tools"
        install_deps "${pkgs}"
        systemctl start httpd.service
        ;;
      *)
        error_msg "Unsupported distribution!"
    esac
fi

cp ./html/* /var/www/html/

# Test Apachebench on Apache.
ab -n "${NUMBER}" -c "${CONCURENT}" "http://localhost/index.html" | tee "${LOGFILE}"
# shellcheck disable=SC2129
grep "Time taken for tests:" "${LOGFILE}" | awk '{print "Time-taken-for-tests pass " $5 " s"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Complete requests:" "${LOGFILE}" | awk '{print "Complete-requests pass " $3 " items"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Failed requests:" "${LOGFILE}" | awk '{ORS=""} {print "Failed-requests "; if ($3==0) {print "pass "} else {print "fail "}; print $3 " items\n" }' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Write errors:" "${LOGFILE}" | awk '{ORS=""} {print "Write-errors "; if ($3==0) {print "pass "} else {print "fail "}; print $3 " items\n" }' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Total transferred:" "${LOGFILE}" | awk '{print "Total-transferred pass " $3 " bytes"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "HTML transferred:" "${LOGFILE}" | awk '{print "HTML-transferred pass " $3 " bytes"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Requests per second:" "${LOGFILE}" | awk '{print "Requests-per-second  pass " $4 " #/s"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Time per request:" "${LOGFILE}" | grep -v "across" | awk '{print "Time-per-request-mean pass " $4 " ms"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Time per request:" "${LOGFILE}" | grep "across" | awk '{print "Time-per-request-concurent pass " $4 " ms"}' >> "${RESULT_FILE}"
# shellcheck disable=SC2129
grep "Transfer rate:" "${LOGFILE}" | awk '{print "Transfer-rate pass " $3 " kb/s"}' >> "${RESULT_FILE}"
