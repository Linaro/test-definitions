#!/bin/bash
# shellcheck disable=SC1091
. ../../lib/sh-test-lib
. ./prune-lib.sh

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

! check_root && error_msg "You need to be root to run this script."
create_out_dir "${OUTPUT}"

if check_image hub.foundries.io/lmp-ci-testing-apps/shellhttpd; then
    report_pass "image-present"
else
    report_fail "image-present"
fi

get_image_sha

setup_callback

auto_register

wait_for_signal

if check_image_prune; then
    report_pass "update-prune"
else
    report_fail "update-prune"
fi

if compare_sha; then
    report_pass "check-sha"
else
    report_fail "check-sha"
fi

rm "$(pwd)/sha.txt"
