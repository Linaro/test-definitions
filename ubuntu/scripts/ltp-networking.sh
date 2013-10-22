#!/bin/bash

DIS="ubuntu"
START_DIR=$(pwd)
LTP_DIR="/opt/ltp"
SERVER_IP="172.31.1.4"
SERVER_NAME="server.ltp"

# overwrite configuration
cp ./$DIS/scripts/ltp-networking-xinetd.conf /etc/xinetd.conf
cp ./$DIS/scripts/ltp-networking-udhcpd /etc/default/udhcpd
sed -i -e 's/RHOST\=/RHOST\=server.ltp/g' $LTP_DIR/testscripts/networktests.sh
sed -i -e 's/PASSWD\=/PASSWD\=2f70c6f33c8d78a717eb01296b8a4d59/g' $LTP_DIR/testscripts/networktests.sh

# disable some tests
sed -i -e '/rdist/d'    $LTP_DIR/runtest/tcp_cmds
sed -i -e '/sendfile/d' $LTP_DIR/runtest/tcp_cmds
sed -i -e '/dhcpd/d'    $LTP_DIR/runtest/tcp_cmds
sed -i -e '/xinetd/d'   $LTP_DIR/runtest/tcp_cmds_addition

# for rsh
cd ~
if [ -d .ssh ]; then
    rm -rf .ssh
fi
mkdir .ssh

cat > ~/.ssh/config <<-EOF
Host *
    StrictHostKeyChecking no
EOF

cat > ~/.ssh/id_rsa <<-EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA3vTpHWDooU7wd8iUDa9aWKl97xX5UGr9u2geNK3lcp1ZVdnq
qetd+oaUqMLXS9KvWxk0CDxRjk9S9HAvPlsj9XlvTOYEvI03M2Vl6zew489WPXAu
OrbGk26kReR1bWVi2BkEsu8BjZtBZ828ncNWb6s/IX7IkyIEi+3QyE2lr6KuE0iL
gc+4xX/iT+suuP8RK/UPhCTVqCvpIaiURykDokEEgTqTWvfVdFYLexntOG7C3VQQ
5WZF+20AlvFAHS2CKz0GO/D0MvveD0IRAsVLy+dOgG4muNAUFMsu/Zs+r+CpHQzI
LBsstP8QEEhSFtQM4RyqoOtTlNwQrzYa4b4HXwIDAQABAoIBAQDcjE4xRpS4RLsw
8pQqOWTYwckWgZkfSMb35JXErKSFTUt61lcAgRh04z4Y9qw8kAvwxKyo3OocKTG5
JWRGfafDgr1rxzm2Psb1K3+3P17W61m26sqAQB+M5ezQSp8yeRFfDNiOHElgB82a
XnUPZpSRYEfR3XWRvhvbQ4O9MLoOUrfS613osoAzaqav0OGSUHzSsvkX7aOMfAt1
TJj1iM/I41Le14LBovqvtfG1ltDDybTmu30gAHTD6e726IS+2qlTf0QhxpHGP5RS
pxAI8AZsv4HROQIiO9l1TT+8NnatXFS2v33sUwaFtU79eQ46nGxIKGdPNhJJUc8D
tTT5IO6pAoGBAP7jaJZG+YP1tvqAkPuCxQ+T3nLX7V8hE7aZg/LZCVy1pgCavTNp
jbg2gGsAw69D5J3309kQLPYd9i6N8D5WO/9vQ3yjOQlNrgJVvTw/0RMbZLeX6iQQ
bpGniqeqqF+NZgJ5kMHbJJbWUMvnY9cEh/zTG+78jzGfpDUfGnsahaxTAoGBAN/t
2WxawvbFh7u4Hnfcn3y378WdYsWogeF05GjPoCd9+V+78X4HWvkaVvhEQFkjAP5v
2OblNN7U7YwL33JwtvbdiaLtorvXiXvSbj6yhMWItb2bqfEOh6IFWuMU5UzDaxym
UaWcEg/n+hvq+W888zTDziJvoiLKH7+lfncRdHdFAoGAE0FsykWMXgq3Cw+hZE7J
wlaCbJyhYxllmtrYHAWHboiOhOcrufGUckEzzGGfZuMzJzfsui49p042Jeg1KRBs
sexe5dCS44AJ0EVX6XBMxCvCnRgN6TGQmNJWaDo9RBKzjSZP6EU862Q/cFgHs9u0
xkXQi2prCu2rgxPZdUlYpd8CgYBfV+Y7PGnGqFQimUJfxpAhii+M9HYZsqWaWSrn
dX+7UOfc2yj3gCo75fshue2sBjtmGjlAFldsiTybZHK/Rz6f3bO8q3GeiScAkZhf
GaNud8bp9F1nRch6M81+4ma/SHVSvX4GBW2rWBolyOZrdogW70fVYbKnHWhnMQ+n
osb0AQKBgQDh7ltYaoCRxAAcWPSQvzgdHOdAfEmhXTuWVQC7HzUTOO1vWgnF7SQj
olwZnFoETACvW4DRP5zhDmqFWgmqdvhEw36aBHMlJlumpWCO9WE248ljpXUcE5p0
HE+8/JeffV2tY0KTlT4Hh3kmr2IpSKTMQjBfBZG1xUxlVz/2ZlVspQ==
-----END RSA PRIVATE KEY-----
EOF

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
cat ~/ltp-networking-multicast.log  | $START_DIR/$DIS/scripts/ltp-networking-parser.py

echo "===== nfs test ====="
./testscripts/networktests.sh -n > ~/ltp-networking-nfs.log
lava-test-run-attach ~/ltp-networking-nfs.log text/plain
cat ~/ltp-networking-nfs.log        | $START_DIR/$DIS/scripts/ltp-networking-parser.py

echo "===== rpc test ====="
./testscripts/networktests.sh -r > ~/ltp-networking-rpc.log
lava-test-run-attach ~/ltp-networking-rpc.log text/plain
cat ~/ltp-networking-rpc.log        | $START_DIR/$DIS/scripts/ltp-networking-parser.py

echo "===== tcp/ip test ====="
service xinetd restart
#service udhcpd restart #this test will start a dhcp server
./testscripts/networktests.sh -t > ~/ltp-networking-tcpip.log
lava-test-run-attach ~/ltp-networking-tcpip.log text/plain
cat ~/ltp-networking-tcpip.log      | $START_DIR/$DIS/scripts/ltp-networking-parser.py
ifconfig eth1 mtu 1500 #ip test will modify mtu to 300

echo "===== sctp test ====="
modprobe sctp
./testscripts/networktests.sh -s > ~/ltp-networking-sctp.log
lava-test-run-attach ~/ltp-networking-sctp.log text/plain
cat ~/ltp-networking-sctp.log       | $START_DIR/$DIS/scripts/ltp-networking-parser.py

echo "===== ipv6lib test ====="
./testscripts/networktests.sh -l > ~/ltp-networking-ipv6lib.log
lava-test-run-attach ~/ltp-networking-ipv6lib.log text/plain
cat ~/ltp-networking-ipv6lib.log	| $START_DIR/$DIS/scripts/ltp-networking-parser.py

#echo "===== ipv6 test ====="
#./testscripts/networktests.sh -6 > ~/ltp-networking-lpv6.log
#lava-test-run-attach ~/ltp-networking-ipv6.log text/plain
cat ~/ltp-networking-ipv6.log	    | $START_DIR/$DIS/scripts/ltp-networking-parser.py
echo "===== ltp networking test end ====="

# recover server hostname
rsh -n -l root $SERVER_IP hostname $SERVER_ORI_NAME

