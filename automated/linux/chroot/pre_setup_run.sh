#!/bin/bash

set -e

TEST_SUITE=${1}
TESTDEF_URL=${2}

(
cd /
git clone "${TESTDEF_URL}" new_root/testdef
echo "cat /etc/os-release" > new_root/run.sh
echo "cd /testdef/automated/linux/\"${TEST_SUITE}\"/" >> new_root/run.sh
awk "/params/{flag=1; next} /run/{flag=0} flag" new_root/testdef/automated/linux/"${TEST_SUITE}"/"${TEST_SUITE}".yaml | sed 's/^ *//; s/: */=/' >> new_root/run.sh
)
