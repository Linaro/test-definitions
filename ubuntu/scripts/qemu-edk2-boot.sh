#!/bin/bash
#
# A simple wrapper to run a expect based system test
#
# This expects the follow environment variables to be set:
#     QEMU_BIN - path to binary
#     QEMU_ARGS - arguments to run
#


pushd `dirname $0` > /dev/null
BASE=`pwd -P`
popd > /dev/null

lava-test-case qemu-edk2-boot-${TEST_NAME} --shell ${BASE}/qemu-edk2-boot.expect ${QEMU_BIN} ${QEMU_ARGS}

