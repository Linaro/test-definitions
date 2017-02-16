#!/bin/sh
# Busybox smoke tests.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

create_out_dir "${OUTPUT}"
cd "${OUTPUT}" || exit 1

busybox
exit_on_fail "busybox-existence"

busybox mkdir dir
check_return "mkdir"

busybox touch dir/file.txt
check_return "touch"

busybox ls dir/file.txt
check_return "ls"

busybox cp dir/file.txt dir/file.txt.bak
check_return "cp"

busybox rm dir/file.txt.bak
check_return "rm"

busybox echo 'busybox test' > dir/file.txt
check_return "echo"

busybox cat dir/file.txt
check_return "cat"

busybox grep 'busybox' dir/file.txt
check_return "grep"

# shellcheck disable=SC2016
busybox awk '{printf("%s: awk\n", $0)}' dir/file.txt
check_return "awk"

busybox free
check_return "free"

busybox df
check_return "df"
