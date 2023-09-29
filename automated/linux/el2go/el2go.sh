#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
SLOT_INIT=False
PTOOL="pkcs11-tool --module /usr/lib/libckteec.so.0.1.0"
SO_PIN=12345678
PIN=87654321
AKLITE_TOKEN_LABEL=aktualizr
AKLITE_CERT_LABEL=SE_83000043
SE05X_TEST_LABEL=test_label
RESET_SE05X=True
AWS_ENDPOINT=""
AWS_CONTAINER=""

usage() {
    echo "\
    Usage: $0 [-p <pkcs11-tool>] [-s <true|false>] [-r <true|false>] [-e <AWS endpoint>] [-c <AWS container>]

    -p <pkcs11-tool>
        pkcs11-tool with all the options required. Default is:
        pkcs11-tool --module /usr/lib/libckteec.so.0.1
    -s <true|false>
        Initialize pkcs11 slot with random token.
        This checks whether auto-registration script
        can deal with alread initialized pkcs11.
        Default: false
    -r <true|false>
        Reset SE050 element to factory settings
        Default: true
    -e <AWS IoT Endpoint URL>
    -c <AWS test container>
        Container connects to the endpoint to create
        AWS IoT Thing
    "
}

systemd_variable_value() {
    # shellcheck disable=SC2039
    local var="$1"
    # shellcheck disable=SC2039
    local service="$2"
    result=$(systemctl show --property "${var}" "${service}")
    if [ -n "${result}" ]; then
        echo "${result#*=}"
    else
        echo ""
    fi
}


while getopts "p:s:r:e:c:h" opts; do
    case "$opts" in
        p) PTOOL="${OPTARG}";;
        s) SLOT_INIT="${OPTARG}";;
        r) RESET_SE05X="${OPTARG}";;
        e) AWS_ENDPOINT="${OPTARG}";;
        c) AWS_CONTAINER="${OPTARG}";;
        h|*) usage ; exit 1 ;;
    esac
done

# the script works only on builds with aktualizr-lite
# and lmp-el2go-auto-register

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

# Disable reboot after
mkdir -p /etc/sota/conf.d
cp z-99-el2go.toml /etc/sota/conf.d/

if [ "${SLOT_INIT}" = "True" ] || [ "${SLOT_INIT}" = "true" ]; then
    # do this to test the pkcs11 initialization in lmp-el2go-auto-register
    # Initialize slot in SE05X device
    # shellcheck disable=SC2086
    $PTOOL --init-token --label "${SE05X_TEST_LABEL}" --so-pin "${SO_PIN}"
    # shellcheck disable=SC2086
    $PTOOL --init-pin --so-pin "${SO_PIN}" --pin "${PIN}"
fi

echo "Enabe lmp-el2go-auto-register"
systemctl unmask lmp-el2go-auto-register
systemctl enable --now lmp-el2go-auto-register
echo "Wait for auto-registration"

while systemctl is-active lmp-el2go-auto-register; do
    sleep 5
    echo "... waiting for lmp-el2go-auto-register to finish"
done
# check if the device was registered

echo "Check if the device is properly registered"
systemctl status --no-pager --full lmp-el2go-auto-register
# should be 0 - exit without error
EXEC_STATUS=$(systemd_variable_value ExecMainStatus lmp-el2go-auto-register)
if [  "${EXEC_STATUS}" = 0 ]; then
    report_pass lmp-el2go-auto-register-exit
else
    report_fail lmp-el2go-auto-register-exit
fi
# should be 1 - exited
EXEC_CODE=$(systemd_variable_value ExecMainCode lmp-el2go-auto-register)
if [ "${EXEC_CODE}" = 1 ]; then
    report_pass lmp-el2go-auto-register-running
else
    report_fail lmp-el2go-auto-register-running
fi

journalctl --no-pager -u lmp-el2go-auto-register

. /etc/os-release
$PTOOL --pin "${PIN}" --token-label "${AKLITE_TOKEN_LABEL}" --read-object --label "${AKLITE_CERT_LABEL}" --type cert --output-file cert.der
# LMP_FACTORY is set in /etc/os-release
openssl x509 -in cert.der -issuer -noout | grep "${LMP_FACTORY}"
check_return "el2go-retrieve-certificate"
if [ -s /var/sota/sota.toml ]; then
    report_pass "sota_toml_created"
else
    report_fail "sota_toml_created"
fi
journalctl --no-pager -u lmp-el2go-auto-register | grep "Deactivated successfully"
check_return "lmp-el2go-service-deactivate"
systemctl is-active aktualizr-lite
check_return "el2go-aklite-running"

# test AWS
# This only works if AWS IoT JIT is configured properly
if [ -n "${AWS_ENDPOINT}" ] && [ -n "${AWS_CONTAINER}" ]; then
    docker run -it -e AWS_ENDPOINT="${AWS_ENDPOINT}" --device=/dev/tee0:/dev/tee0 "${AWS_CONTAINER}"
    check_return "el2go-aws-iot"
else
    report_skip "el2go-aws-iot"
fi

# cleanup
if [ "${RESET_SE05X}" = "True" ] || [ "${RESET_SE05X}" = "true" ]; then
    echo "Cleanup SE050"
    # stop aklite to prevent TA panic
    systemctl stop aktualizr-lite
    fio-se05x-cli --factory-reset --se050
fi
