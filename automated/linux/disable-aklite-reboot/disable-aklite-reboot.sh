#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021 Foundries.io Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

mkdir -p /etc/sota/conf.d
cp z-99-aklite-callback.toml /etc/sota/conf.d/
report_pass "create-aklite-toml"

systemctl enable --now lmp-device-auto-register

# the below aklite status call is added for debugging
# aklite should take it's config from the .toml file and the
# following should be included in the output:
#    info: Reading config: \"/etc/sota/conf.d/z-99-aklite-callback.toml\"
# reboot_command = \"/bin/true\"
sleep 5
aktualizr-lite status --loglevel 0
# exit with code 0 to allow result collection in case of race
# between aklite systemd service and above call
exit 0
