#!/bin/bash

DIS="ubuntu"
START_DIR=$(pwd)
LTP_DIR="/opt/ltp"
SERVER_IP="172.31.1.4"
SERVER_NAME="server.ltp"

# overwrite test script
cp ./$DIS/scripts/ltp-networking/networktests.sh 	$LTP_DIR/testscripts/networktests.sh
cp ./$DIS/scripts/ltp-networking/tcp_cmds       	$LTP_DIR/runtest/tcp_cmds
cp ./$DIS/scripts/ltp-networking/tcp_cmds_addition	$LTP_DIR/runtest/tcp_cmds_addition
cp ./$DIS/scripts/ltp-networking/*	                $LTP_DIR/testcases/bin/
cp ./$DIS/scripts/ltp-networking/xinetd.conf       	/etc/xinetd.conf
cp ./$DIS/scripts/ltp-networking/udhcpd       	    /etc/default/udhcpd

# for rsh
cd ~
if [ -d .ssh ]; then
    rm -rf .ssh
fi
mkdir .ssh
cp $START_DIR/$DIS/scripts/ltp-networking/id_rsa ~/.ssh/id_rsa
cp $START_DIR/$DIS/scripts/ltp-networking/config ~/.ssh/config
chmod 600 ~/.ssh/id_rsa
chown -R $(whoami):$(whoami) .ssh

# network coufiguration
echo "===== network coufiguration ====="
echo 0 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
ifconfig eth1 up
ifconfig eth1 mtu 1500
#ifconfig eth1 172.31.1.246 #make sure having IP address even if dhcp fail
dhclient eth1
echo "+ +" > ~/.rhosts
echo "$SERVER_IP $SERVER_NAME" >> /etc/hosts
echo $(ifconfig eth1 | grep 'inet addr' | awk -F: '{print $2}' |awk '{print $1 " client.ltp"}')  >> /etc/hosts
echo "client.ltp" > /etc/hostname
hostname client.ltp

# check network status
ifconfig -a > ~/ifconfig.log
lava-test-run-attach ~/ifconfig.log text/plain
cat ~/ifconfig.log
ping -c 5 server.ltp > ~/ping.log
cat ~/ping.log
grep "100% packet loss" ~/ping.log && (echo "No network connection!!" ; exit 1)

# temporary modify server hostname
SERVER_ORI_NAME=$(rsh -n -l root $SERVER_IP hostname)
rsh -n -l root $SERVER_IP hostname $SERVER_NAME

echo "===== ltp networking test start ====="
cd $LTP_DIR
echo "===== multicast test ====="
./testscripts/networktests.sh -m > ~/ltp-networking-multicast.log
lava-test-run-attach ~/ltp-networking-multicast.log text/plain
cat ~/ltp-networking-multicast.log | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py

echo "===== nfs test ====="
./testscripts/networktests.sh -n > ~/ltp-networking-nfs.log
lava-test-run-attach ~/ltp-networking-nfs.log text/plain
cat ~/ltp-networking-nfs.log       | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py

echo "===== rpc test ====="
./testscripts/networktests.sh -r > ~/ltp-networking-rpc.log
lava-test-run-attach ~/ltp-networking-rpc.log text/plain
cat ~/ltp-networking-rpc.log       | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py

echo "===== tcp/ip test ====="
service xinetd restart
#service udhcpd restart #this test will start a dhcp server
./testscripts/networktests.sh -t > ~/ltp-networking-tcpip.log
lava-test-run-attach ~/ltp-networking-tcpip.log text/plain
cat ~/ltp-networking-tcpip.log     | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py
ifconfig eth1 mtu 1500 #ip test will modify mtu to 300

echo "===== sctp test ====="
modprobe sctp
./testscripts/networktests.sh -s > ~/ltp-networking-sctp.log
lava-test-run-attach ~/ltp-networking-sctp.log text/plain
cat ~/ltp-networking-sctp.log      | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py

echo "===== ipv6lib test ====="
./testscripts/networktests.sh -l > ~/ltp-networking-ipv6lib.log
lava-test-run-attach ~/ltp-networking-ipv6lib.log text/plain
cat ~/ltp-networking-ipv6lib.log   | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py

#echo "===== ipv6 test ====="
#./testscripts/networktests.sh -6 > ~/ltp-networking-lpv6.log
#lava-test-run-attach ~/ltp-networking-ipv6.log text/plain
#cat ~/ltp-networking-ipv6.log   | $START_DIR/$DIS/scripts/ltp-networking/ltp-networking-whole.py
echo "===== ltp networking test end ====="

# recover server hostname
rsh -n -l root $SERVER_IP hostname $SERVER_ORI_NAME

