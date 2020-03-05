#!/bin/sh -ex

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
LOGFILE="${OUTPUT}/iperf.txt"
# If SERVER is blank, we are the server, otherwise
# If we are the client, we set SERVER to the ipaddr of the server
SERVER=""
# Time in seconds to transmit for
TIME="10"
# Number of parallel client streams to run
THREADS="1"
# Specify iperf3 version for CentOS.
VERSION="3.1.4"
# By default, the client sends to the server,
# Setting REVERSE="-R" means the server sends to the client
REVERSE=""
# CPU affinity is blank by default, meaning no affinity.
# CPU numbers are zero based, eg AFFINITY="-A 0" for the first CPU
AFFINITY=""

usage() {
    echo "Usage: $0 [-c server] [-t time] [-p number] [-v version] [-A cpu affinity] [-R] [-s true|false]" 1>&2
    exit 1
}

while getopts "A:c:t:p:v:s:Rh" o; do
  case "$o" in
    A) AFFINITY="-A ${OPTARG}" ;;
    c) SERVER="${OPTARG}" ;;
    t) TIME="${OPTARG}" ;;
    p) THREADS="${OPTARG}" ;;
    R) REVERSE="-R" ;;
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
if [ "${SERVER}" = "" ]; then
    # We are running in server mode.
    # Start the server and report pass/fail
    cmd="iperf3 -s -D"
    ${cmd}
    if pgrep -f "${cmd}" > /dev/null; then
        result="pass"
    else
        result="fail"
    fi
    echo "iperf3_server_started ${result}" | tee -a "${RESULT_FILE}"
else
    # We are running in client mode
    # Run iperf test with unbuffered output mode.
    stdbuf -o0 iperf3 -c "${SERVER}" -t "${TIME}" -P "${THREADS}" "${REVERSE}" "${AFFINITY}" 2>&1 \
        | tee "${LOGFILE}"

    # Parse logfile.
    if [ "${THREADS}" -eq 1 ]; then
        grep -E "(sender|receiver)" "${LOGFILE}" \
            | awk '{printf("iperf_%s pass %s %s\n", $NF,$7,$8)}' \
            | tee -a "${RESULT_FILE}"
    elif [ "${THREADS}" -gt 1 ]; then
        grep -E "[SUM].*(sender|receiver)" "${LOGFILE}" \
            | awk '{printf("iperf_%s pass %s %s\n", $NF,$6,$7)}' \
            | tee -a "${RESULT_FILE}"
    fi
fi
