#!/bin/sh

set -x

local_ip=$(ifconfig|grep "inet addr"|grep -v "127.0.0.1"|cut -d: -f2|cut -d' ' -f1)

for line in `lava-group | grep server | awk '{print $1}'` ; do
	echo $line
	# get the ipv4 for this device
	STR=`lava-network query $line ipv4`
	echo "STR: "$STR
	# strip off the prefix for ipv4
	DUT=`echo $STR | sed -e 's/.*addr://'`
	echo "DUT: "$DUT
	if [ "${local_ip}" != "${DUT}" ]; then
		remote_ip=${DUT}
		echo ${remote_ip}
		break
	fi
done

if [ -z ${remote_ip} ]
then
	echo "Missing remote ip!"
	exit 1
fi

ifconfig -a
local_mac=$(ifconfig eth0 | grep "HWaddr" | awk '{print $5}')
ping -c 1 ${remote_ip} || exit 1
remote_mac=$(arp -a | grep "${remote_ip}" | awk '{print $4}')

tcpprep -a client -i telnet.cap -o telnet.cache
tcprewrite  --enet-smac=$local_mac,$remote_mac --enet-dmac=$remote_mac,$local_mac --endpoints=$local_ip:$remote_ip -c telnet.cache -i telnet.cap -o out.telnet.pcap --skipbroadcast
tcpreplay -i eth0 -l 100 -t -c telnet.cache out.telnet.pcap | ./common/scripts/netperf2LAVA.py

