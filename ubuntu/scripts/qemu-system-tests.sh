#!/bin/bash
#
# A simple wrapper to run a series of expect based system tests
#
# This expects the follow environment variables to be set:
#     QEMU_BIN - path to binary
#     QEMU_ARGS - arguments to run
#     KERNEL_ARGS - arguments to kernel
#
# It expects the system test image to be in /home/image
#
# The expect script that will control QEMU, prefix will be qemu- and suffix .expect
#

pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null

for test in $@; do
    lava-test-case qemu-${test} --shell ${BASE}/qemu-${test}.expect ${QEMU_BIN} ${QEMU_ARGS} -kernel /home/image -append "${KERNEL_ARGS}"
done
            
