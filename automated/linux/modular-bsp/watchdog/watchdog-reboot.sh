#!/bin/bash
#
# watchdog-reboot.sh
#
# Advantech BSP QA – Watchdog reboot test (separate LAVA job)
#
# Opens /dev/watchdog and does NOT write the keepalive magic close sequence
# so that the hardware watchdog fires after the configured timeout.
# LAVA must be configured with auto_login to detect the recovery.
#
# Copyright (c) 2024 Advantech Co., Ltd. All rights reserved
#

# shellcheck source=../lib/adv-test-lib.sh
. "$(dirname "$0")/../lib/adv-test-lib.sh"

create_out_dir

: "${WATCHDOG_DEV:=/dev/watchdog0}"
: "${WATCHDOG_TIMEOUT_S:=30}"

req_id="L-WATCHDOG-REBOOT-F"

if ! [ -e "${WATCHDOG_DEV}" ]; then
    report_skip "${req_id}"
    exit 0
fi

info_msg "Opening ${WATCHDOG_DEV} – system will reboot in ${WATCHDOG_TIMEOUT_S}s"

# Write result BEFORE triggering the reboot so that LAVA can pick it up after
# the board comes back online (the result file must persist across the reboot,
# e.g. on the rootfs or a mounted NFS share).
report_pass "${req_id}"

# Open watchdog and let it expire (do NOT close with magic 'V')
# Bash's exec keeps the fd open while the script sleeps
exec 9>"${WATCHDOG_DEV}"
sleep "${WATCHDOG_TIMEOUT_S}"

# Reaching here means the watchdog did NOT fire – the test has failed.
# Close the fd without writing 'V'; on drivers without magic-close support
# this may still trigger a reset, but the result is already recorded as fail.
truncate -s 0 "${RESULT_FILE}"
report_fail "${req_id}"
exec 9>&-
