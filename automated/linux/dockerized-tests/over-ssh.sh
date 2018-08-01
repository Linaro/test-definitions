#!/bin/sh -e
# shellcheck disable=SC1090
# shellcheck disable=SC2154

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
LOGFILE="${OUTPUT}/stdout.txt"
RESULT_FILE="${OUTPUT}/result.txt"

SKIP_INSTALL="false"
TEST="automated/linux/smoke/smoke.yaml"
TARGET_IP="lava-target-ip"
SSH_USER="osf"
SSH_PASSWD="osf"
DOCKER_IMG="chaseqi/test-definitions:9f8918d"

usage() {
    echo "Usage: $0 [-s <skip_install>] [-t <test>] [-i <target_ip>] [-u <ssh_user>] [-p <ssh_passwd>] [-d <docker_img>]" 1>&2
    exit 1
}

while getopts "s:t:o:i:u:p:d:h" opt; do
    case "$opt" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        t) TEST="${OPTARG}" ;;
        i) TARGET_IP="${OPTARG}" ;;
        u) SSH_USER="${OPTARG}" ;;
        p) SSH_PASSWD="${OPTARG}" ;;
        d) DOCKER_IMG="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"
create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

[ "${TARGET_IP}" = "lava-target-ip" ] && TARGET_IP="$(lava-target-ip)"
ssh_cmd="sshpass -p ${SSH_PASSWD} ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ${SSH_USER}@${TARGET_IP}"

install_deps sshpass "${SKIP_INSTALL}"
# Assume docker pre-installed on test target.
# Installation on remote ssh target isn't supported yet.
eval "${ssh_cmd}" which docker | grep 'docker' || error_msg "docker not found on test target!"

# When using ssh, to avoid 'x509: certificate has expired or is not yet valid',
# set time to client's date, which more likely has ntp sync enabled. 
client_date="$(date +%Y%m%d)"
echo "${SSH_PASSWD}" | eval ${ssh_cmd} sudo -S date +%Y%m%d -s ${client_date}

# Trigger test run.
eval "${ssh_cmd}" docker run "${DOCKER_IMG}" test-runner -d "${TEST}" | tee -a "${LOGFILE}"

# Parse test log.
awk '/^<TEST_CASE_ID/ {gsub(/(<|>|=|TEST_CASE_ID|RESULT|UNITS|MEASUREMENT)/,""); print}' "${LOGFILE}" | tee -a "${RESULT_FILE}"
