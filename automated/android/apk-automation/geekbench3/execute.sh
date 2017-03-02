#!/bin/bash
# shellcheck disable=SC2034

# need to be defined for different benchmark apks
activity="com.primatelabs.geekbench3/.HomeActivity"
apk_file_name="com.primatelabs.geekbench3.apk"
apk_package="com.primatelabs.geekbench3"

# following should no need to modify
parent_dir=$(dirname "$0")
# shellcheck disable=SC1090
source "${parent_dir}/../common/common.sh"
timeout=30m
main "$@"
