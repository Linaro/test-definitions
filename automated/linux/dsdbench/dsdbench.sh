#!/bin/sh -e

# This test script run docker storage driver benchmarks and tests.
# Test suite source https://github.com/dmcgowan/dsdbench

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
    s) SKIP_INSTALL="${OPTARG}" && export SKIP_INSTALL ;;
    h|*) usage ;;
  esac
done

dist_name
# shellcheck disable=SC2154
case "${dist}" in
    debian|ubuntu)
        dist_info
        # shellcheck disable=SC2154
        if [ "${Codename}" = "jessie" ]; then
            install_deps "git libdevmapper-dev"
            install_deps "-t jessie-backports golang"
        else
            install_deps "git golang libdevmapper-dev"
        fi
        ;;
    fedora|centos)
        install_deps "git golang device-mapper-devel"
        ;;
esac

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"
mkdir -p "${OUTPUT}/golang"
cd "${OUTPUT}"
export GOPATH="${OUTPUT}/golang"
git clone https://github.com/dmcgowan/dsdbench
cd dsdbench
cp -r vendor/ "${GOPATH}/src"

if [ "${TEST_SUITE}" = "BENCHMARKS" ]; then
    # Run benchmarks.
    DOCKER_GRAPHDRIVER=overlay2 go test -run=NONE -v -bench . \
        | tee "${LOG_FILE}"

    # Parse log file.
    egrep "^Benchmark.*op$" "${LOG_FILE}" \
        | awk '{printf("%s pass %s %s\n", $1,$3,$4)}' \
        | tee -a "${RESULT_FILE}"
elif [ "${TEST_SUITE}" = "TESTS" ]; then
    # Run tests.
    DOCKER_GRAPHDRIVER=overlay2 go test -v . \
        | tee "${LOG_FILE}"

    # Parse log file.
    for result in PASS FAIL SKIP; do
        grep "\-\-\- ${result}" "${LOG_FILE}" \
            | awk -v result="${result}" '{printf("%s %s\n", $3,result)}' \
            | tee -a "${RESULT_FILE}"
    done
fi
