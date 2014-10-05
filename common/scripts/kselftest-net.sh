#!/bin/bash

BASEDIR=$(readlink -f $(dirname ${BASH_SOURCE[0]}))
LAVA_ROOT="${BASEDIR}/../../"
TEST_DIR="${LAVA_ROOT}/kselftest/net"
TESTS="socket psock_fanout psock_tpacket"
cd ${TEST_DIR}

if /sbin/modprobe test_bpf; then
    /sbin/rmmod test_bpf;
    echo "test_bpf: pass";
else
    echo "test_bpf: fail";
fi

for t in $TESTS
do
    echo -e "\nRunning $t";
    ./$t;
    [ $? -ne 0 ] && echo "$t: fail" || echo "$t: pass";
done

