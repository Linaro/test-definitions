#!/bin/sh

set -x

local_ip=$(ifconfig $1|grep "inet addr"|grep -v "127.0.0.1"|cut -d: -f2|cut -d' ' -f1)

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
ping -c 1 ${remote_ip} || exit 1
ping -c 30 ${remote_ip} | tee ~/output.txt | ./common/scripts/netperf2LAVA.py
for m in 64 128 256 512 1024 2048 4096 8192 16384; do netperf -H ${remote_ip} -l 20 -c -C -- -m $m -D; done | tee -a ~/output.txt | ./common/scripts/netperf2LAVA.py
for m in 64 128 256 512 1024 2048 4096 8192 16384; do netperf -H ${remote_ip} -l 20 -t UDP_STREAM -c -C -- -m $m -D; done | tee -a ~/output.txt | ./common/scripts/netperf2LAVA.py
for m in 1 32 64 128 512 1024 4096 8192 16384; do netperf -t TCP_RR -H ${remote_ip} -l 20 -c -C -- -r $m,$m -D; done | tee -a ~/output.txt | ./common/scripts/netperf2LAVA.py
for m in 1 32 64 128 512 1024 4096 8192 16384; do netperf -t UDP_RR -H ${remote_ip} -l 20 -c -C -- -r $m,$m -D; done | tee -a ~/output.txt | ./common/scripts/netperf2LAVA.py
