#!/bin/sh -x
# shellcheck disable=SC2154
# shellcheck disable=SC1091

. ../../lib/sh-test-lib
. ../../lib/android-test-lib

install_latest_adb
wait_boot_completed "300"
adb root
adb_join_wifi