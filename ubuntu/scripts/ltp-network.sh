#!/bin/sh
#
# Run LTP network tests on Linux Linaro ubuntu
#
# Copyright (C) 2010 - 2014, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Maintainer:
#   vincent.hsu@linaro.org
#   milosz.wasilewski@linaro.org
#   fathi.boudra@linaro.org

DIS="ubuntu"
START_DIR=$(pwd)
LTP_DIR="/opt/ltp"
INTERFACE=$1 # TEST_INTERFACE: from Dispatcher Job File
SERVER_IP=$2 # TEST_SERVER: from Dispatcher Job File
SERVER_NAME="server.ltp"
SERVER_PASSWD="2f70c6f33c8d78a717eb01296b8a4d59"

# overwrite configuration
cp $START_DIR/$DIS/scripts/ltp-network-xinetd.conf /etc/xinetd.conf
cp $START_DIR/$DIS/scripts/ltp-network-udhcpd /etc/default/udhcpd

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
ifconfig $INTERFACE up
ifconfig $INTERFACE mtu 1500
dhclient $INTERFACE
echo "+ +" > ~/.rhosts
echo "$SERVER_IP $SERVER_NAME" >> /etc/hosts
echo $(ifconfig $INTERFACE | grep 'inet addr' | awk -F: '{print $2}' |awk '{print $1 " client.ltp"}')  >> /etc/hosts
echo "client.ltp" > /etc/hostname
hostname client.ltp

# check network status
ifconfig -a > ~/ifconfig.log
cat ~/ifconfig.log
ping -c 5 server.ltp > ~/ping.log
cat ~/ping.log
grep "100% packet loss" ~/ping.log && (echo "No network connection!!" ; exit 1)

# temporary modify server hostname
SERVER_ORI_NAME=$(rsh -n -l root $SERVER_IP hostname)
rsh -n -l root $SERVER_IP hostname $SERVER_NAME

echo "===== ltp network test start ====="
cd $LTP_DIR

# form networktests.sh
RHOST=$SERVER_NAME
export RHOST
PASSWD=$SERVER_PASSWD
export PASSWD

# for nfs test
echo "/ *(rw,sync,no_root_squash,no_subtree_check)" > /etc/exports
sed -i -e "s/$RPCMOUNTDOPTS --no-nfs-version 3/$RPCMOUNTDOPTS/g"  /etc/init.d/nfs-kernel-server
service nfs-kernel-server restart

# for sctp test
modprobe sctp

# for tcp test
service xinetd restart
#service udhcpd restart # this test need to start a dhcp server

# run test
./runltp -q -p -f multicast,nfs,rpc,sctp,ipv6_lib,tcp_cmds,tcp_cmds_addition -S $START_DIR/$DIS/scripts/ltp-network-skiplist
ifconfig $INTERFACE mtu 1500 # ip test will modify mtu to 300

# print test result
find ./results -name "LTP_RUN_ON*" -print0 |xargs -0 cat

# recover server hostname
rsh -n -l root $SERVER_IP hostname $SERVER_ORI_NAME
echo "===== ltp network test end ====="
