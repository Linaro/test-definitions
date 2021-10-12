#!/bin/bash

. ../../lib/sh-test-lib
GPIOD_PATH=${1:-"/opt/libgpiod/bin/"}

export PATH="${GPIOD_PATH}:$PATH"

trap 'exit_cleanup' EXIT
trap '_warn "interrupted, cleaning up..."; exit_cleanup; exit 1' INT

mount_debugfs

gpiod-test 2>&1| tee tmp.txt
sed 's/\[[0-9;]*m//g'  tmp.txt \
	| grep '\[TEST\]' \
	| sed 's/\[TEST\]//' \
	| sed -r "s/'//g; s/^ *//; s/-//; s/[^a-zA-Z0-9]/-/g; s/--+/-/g; s/-PASS/ pass/; s/-FAIL/ fail/; s/-SKIP/ skip/; s/-//;" 2>&1 \
	| tee -a result.txt
rm tmp.txt
