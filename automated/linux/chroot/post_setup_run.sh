#!/bin/bash

set -e

TEST_SUITE=${1}

(
cd /
awk "/cd \.\/automated\/linux/{flag=1; next} /send-to-lava\.sh/{flag=0} flag" new_root/testdef/automated/linux/"${TEST_SUITE}"/"${TEST_SUITE}".yaml | sed 's/^ *- *//' >> new_root/run.sh
)
