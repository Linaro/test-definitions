#!/bin/sh

#set -e
#set -x

LEN=${1}
PACKET=${2}
TIME=${3}

opts="-s"
[ "${PACKET}" = "UDP" ] && opts="${opts} -u"
server_ip=$(ifconfig `route -n|grep "^0"|awk '{print $NF}'`|grep -o "inet addr:[0-9\.]*"|cut -d':' -f 2)
echo "iperf server:"
echo "Server IP: ${server_ip}"
echo "Runing iperf ${opts}"
iperf ${opts} &
echo $! > /tmp/iperf-server.pid
lava-send server-ready server_ip=${server_ip}
lava-wait client-done
lava-test-case iperf-server --shell kill -9 `cat /tmp/iperf-server.pid`
