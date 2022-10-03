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
#SE05X_SLOT_LABEL=aktualizr
SE05X_TEST_LABEL=test_label

usage() {
    echo "\
    Usage: $0 [-p <pkcs11-tool>] [-s <true|false>]

    -p <pkcs11-tool>
        pkcs11-tool with all the options required. Default is:
        pkcs11-tool --module /usr/lib/libckteec.so.0.1
    -s <true|false>
        Initialize pkcs11 slot with random token.
        This checks whether auto-registration script
        can deal with alread initialized pkcs11.
        Default: false
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


while getopts "p:s:h" opts; do
    case "$opts" in
        p) PTOOL="${OPTARG}";;
        s) SLOT_INIT="${OPTARG}";;
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
systemctl status --no-pager lmp-el2go-auto-register
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

journalctl --no-pager -u lmp-el2go-auto-register | grep "Getting Certificate"
check_return "el2go-get-certificate"
journalctl --no-pager -u lmp-el2go-auto-register | grep "Retrieved Certificate"
check_return "el2go-retrieve-certificate"
journalctl --no-pager -u lmp-el2go-auto-register | grep "Deactivated successfully"
check_return "lmp-el2go-service-deactivate"
systemctl is-active aktualizr-lite
check_return "el2go-aklite-running"

# cleanup
echo "Cleanup SE050"
# reset se050
ssscli connect se05x t1oi2c none
ssscli se05x reset
ssscli disconnect
