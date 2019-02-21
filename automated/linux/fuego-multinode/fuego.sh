#!/bin/sh -ex

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
BOARD="generic-armhf"
TOOLCHAIN="armhf"
TEST="Functional.hello_world"
SPEC="default"
SKIP_INSTALL="false"

usage() {
    echo "Usage: $0 [-b BOARD] [-c TOOLCHAIN] [-t TEST] [-s SPEC] [-S SKIP_INSTALL]" 1>&2
    exit 1
}

while getopts "b:c:t:s:S:h" o; do
  case "$o" in
    b) BOARD="${OPTARG}" ;;
    c) TOOLCHAIN="${OPTARG}" ;;
    t) TEST="${OPTARG}" ;;
    s) SPEC="${OPTARG}" ;;
    S) SKIP_INSTALL="${OPTARG}" ;;
    h|*) usage ;;
  esac
done

# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"
create_out_dir "${OUTPUT}"

# Install toolchain.
# Refer to http://fuegotest.org/wiki/Adding_a_toolchain for supported
# toolchains by the following installer.
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Toolchain ${TOOLCHAIN} installation skipped."
else
   /fuego-ro/toolchains/install_cross_toolchain.sh "${TOOLCHAIN}"
fi

# Add board configuration.
# FIXME: changes in LAVA are required to support additional docker run params.
# fuego uses '--net="host"' to make fuego host accessible for DUT. The feature
# is required by networking tests like NetPIPE, iperf, netperf
dut_ipaddr=$(grep "ipaddr" /tmp/lava_multi_node_cache.txt | awk -F"=" '{print $NF}')
board_config="/fuego-ro/boards/${BOARD}.board"
if [ -f "${board_config}" ] && grep "${dut_ipaddr}" "${board_config}"; then
    info_msg "Board configuration already added."
else
    sed -i "s/dut_ipaddr/${dut_ipaddr}/" "boards/${BOARD}.board"
    cp "boards/${BOARD}.board" /fuego-ro/boards/
    cat "/fuego-ro/boards/${BOARD}.board"
fi

# Set proper permissions.
chown -R jenkins.jenkins /fuego-rw/
chown -R jenkins.jenkins /fuego-ro/

# Add Jenkins node.
# Give Jenkins time to start.
sleep 30
if ftc list-nodes | grep "${BOARD}"; then
    info_msg "Node ${BOARD} already added."
else
    ftc add-nodes -b "${BOARD}" -f
fi

# Add test job.
if ftc list-jobs | grep "${BOARD}.${SPEC}.${TEST}"; then
    info_msg "Test job ${BOARD}.${SPEC}.${TEST} already added."
else
    ftc add-job -b "${BOARD}" -t "${TEST}" -s "${SPEC}"
fi

# Run test as user jenkins.
# timeout will be handled by LAVA. Set a super long time here.
# TODO: support dynamic-vars
ret_val=0
sudo -u jenkins ftc run-test -b "${BOARD}" -t "${TEST}" -s "${SPEC}" \
    --precleanup true \
    --postcleanup false \
    --rebuild false \
    --reboot false \
    --timeout 1d || ret_val=$?

# Parse result file run.json.
log_dir=$(find "/fuego-rw/logs/${TEST}/${BOARD}.${SPEC}"* -maxdepth 0 -type d | sort | tail -n 1)
python "${TEST_DIR}/parser.py" -s "${log_dir}/run.json" -d "${RESULT_FILE}"

if [ "${ret_val}" -ne 0 ]; then
    exit 1
else
    exit 0
fi
