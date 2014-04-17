#!/bin/sh
set -x
usage()
{
	echo "usage:\n" \
	     " - $1 (interface.Primary traffic output interface.)\n" \
	     " - $2 (address.The IP address that the packages will be replayed to.)\n" \
	     " - $3 (rate.Replay packets at a given packets/sec.It takes an integer number or 'max' as its argument.)\n" \
	     " - $4 (loop number.Loop through the capture file X times.)"
}

if [  $# -ne 4 ]; then
	echo "param miss!"
	usage
	exit 1
fi

INTF=$1
ADDR=$2
RATE=$3
LOOP=$4

local_ip=$(ifconfig $INTF |grep "inet addr"|grep -v "127.0.0.1"|cut -d: -f2|cut -d' ' -f1)
remote_ip=$ADDR
local_mac=$(ifconfig $INTF | grep "HWaddr" | awk '{print $5}')
ping -c 1 ${remote_ip}
if [ $? -ne 0 ]; then
	echo "Address $remote_ip isn't reachable"
	exit 1
fi
remote_mac=$(arp -a | grep "${remote_ip}" | awk '{print $4}')

opt="-t"
if [ $RATE != 'max' ]; then
	opt="-p $RATE"
fi
infile="./common/scripts/pcapfiles/iperf.pcap"
tcpreplay -V
tcpprep -a client -i $infile -o tmpcap.cache
tcprewrite  --enet-smac=$local_mac,$remote_mac --enet-dmac=$remote_mac,$local_mac --endpoints=$local_ip:$remote_ip -c tmpcap.cache -i $infile -o out.tmpcap.pcap --skipbroadcast
tcpreplay -i eth0 -l 100 $opt -c tmpcap.cache out.tmpcap.pcap | ./common/scripts/netperf2LAVA.py
