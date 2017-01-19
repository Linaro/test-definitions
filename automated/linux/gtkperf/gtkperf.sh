#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
TMP_FILE="${OUTPUT}/tmp.txt"
export RESULT_FILE

usage() {
    echo "Usage: $0 [-s <true|false>]" 1>&2
    exit 1
}

while getopts "s:h" o; do
  case "$o" in
    s) SKIP_INSTALL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

install() {
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
      Debian|Ubuntu|Fedora|CentOS) install_deps "gtkperf" "${SKIP_INSTALL}";;
      Unknown) warn_msg "Unsupported distro: package install skipped" ;;
    esac
}

# Test run.
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

install
gtkperf -a  2>&1 | tee "${TMP_FILE}"
grep "Total time" ${TMP_FILE}  \
     | awk '{printf("gtkperf pass %s s\n", $3)}' \
     | tee -a "${RESULT_FILE}"

