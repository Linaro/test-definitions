#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
TEST_SUITE="BENCHMARKS"
RESULT_FILE="${OUTPUT}/result.txt"
LOG_FILE="${OUTPUT}/dsbench.txt"

usage() {
    echo "Usage: $0 [-t <benchmarks|tests>] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "t:s:h" o; do
  case "$o" in
    t) TEST_SUITE="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

dist_name
# shellcheck disable=SC2154
case "${dist}" in
    Debian|Ubuntu) pkgs="git golang libdevmapper-dev" ;;
    Fedora|CentOS) pkgs="git golang device-mapper-devel" ;;
esac
install_deps "${pkgs}" "${SKIP_INSTALL}"

! check_root && error_msg "You need to be root to run this script."
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}/golang"
cd "${OUTPUT}"
export GOPATH="${OUTPUT}/golang"
git clone https://github.com/dmcgowan/dsdbench
cd dsdbench
cp -r vendor/ "${GOPATH}/src"

if [ "${TEST_SUITE}" = "BENCHMARKS" ]; then
    # Run benchmarks.
    DOCKER_GRAPHDRIVER=overlay2 go test -run=NONE -v -bench . 2>&1 \
        | tee "${LOG_FILE}"

    # Parse log file.
    egrep "^Benchmark.*op$" "${LOG_FILE}" \
        | awk '{printf("%s pass %s %s\n", $1,$3,$4)}' \
        | tee -a "${RESULT_FILE}"
elif [ "${TEST_SUITE}" = "TESTS" ]; then
    # Run tests.
    DOCKER_GRAPHDRIVER=overlay2 go test -v . 2>&1 \
        | tee "${LOG_FILE}"

    # Parse log file.
    for result in PASS FAIL SKIP; do
        grep "\-\-\- ${result}" "${LOG_FILE}" \
            | awk -v result="${result}" '{printf("%s %s\n", $3,result)}' \
            | tee -a "${RESULT_FILE}"
    done
fi
