#!/bin/sh

#set -e
#set -x

LEN=${1}
PACKET=${2}
TIME=${3}
TEST_CASE="Bandwidth"

lava-wait server-ready
server_ip=$(cat /tmp/lava_multi_node_cache.txt | cut -d = -f 2)
opts="-c ${server_ip} -l ${LEN} -t ${TIME}"
[ "${PACKET}" = "UDP" ] && opts="${opts} -u"
echo "iperf client:"
echo "Running iperf ${opts}"
iperf ${opts} 2>&1 | tee result.log
echo -n "${TEST_CASE}: "
grep "^\[" result.log | tail -n 1 | awk '{print $7 " " $8 " pass"}'
lava-test-case iperf-client --shell [ -z "`grep "Connection refused" result.log`" ] && true || false
lava-test-case-attach iperf-client result.log
lava-send client-done

