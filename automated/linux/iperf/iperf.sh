#!/bin/sh -e

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/iperf.txt"
# Test locahost by defualt, which tests the effificency of TCP/IP stack.
# To test physical network bandwidth, specify remote test server with '-c'.
# Execute 'iperf3 -s' on remote host to run iperf3 test server.
SERVER="127.0.0.1"
# Time in seconds to transmit for
TIME="10"
# Number of parallel client streams to run
THREADS="1"
# Specify iperf3 version for CentOS.
VERSION="3.1.4"

usage() {
    echo "Usage: $0 [-c server] [-t time] [-p number] [-v version] [-s true|false]" 1>&2
    exit 1
}

while getopts "c:t:p:v:s:h" o; do
  case "$o" in
    c) SERVER="${OPTARG}" ;;
    t) TIME="${OPTARG}" ;;
    p) THREADS="${OPTARG}" ;;
    v) VERSION="${OPTARG}" ;;
    s) SKIP_INSTALL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "iperf installation skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu|fedora)
            install_deps "iperf3"
            ;;
        centos)
            install_deps "wget gcc make"
            wget https://github.com/esnet/iperf/archive/"${VERSION}".tar.gz
            tar xf "${VERSION}".tar.gz
            cd iperf-"${VERSION}"
            ./configure
            make
            make install
            ;;
    esac
fi

# Run local iperf3 server as a daemon when testing localhost.
[ "${SERVER}" = "127.0.0.1" ] && iperf3 -s -D

# Run iperf test with unbuffered output mode.
stdbuf -o0 iperf3 -c "${SERVER}" -t "${TIME}" -P "${THREADS}" 2>&1 \
    | tee "${LOGFILE}"

# Parse logfile.
if [ "${THREADS}" -eq 1 ]; then
    egrep "(sender|receiver)" "${LOGFILE}" \
        | awk '{printf("iperf-%s pass %s %s\n", $NF,$7,$8)}' \
        | tee -a "${RESULT_FILE}"
elif [ "${THREADS}" -gt 1 ]; then
    egrep "[SUM].*(sender|receiver)" "${LOGFILE}" \
        | awk '{printf("iperf-%s pass %s %s\n", $NF,$6,$7)}' \
        | tee -a "${RESULT_FILE}"
fi

# Kill iperf test daemon if any.
pkill iperf3 || true
