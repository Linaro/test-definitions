#!/bin/bash

# This script start netmap pkt-gen on two interfaces, one used to transmit and
# the other to receive; the output of pkt-gen is saved in files to be parsed and
# passed to common/scripts/min_max_avg_parse.py
# Sample command: start-pkt-gen.sh eth0 eth1 tx.out rx.out
# where eth0 is used to send packets and eth1 to receive

test $# -lt 4 && echo "Please pass interfaces and rx and tx output files" && exit 1

netmap/examples/pkt-gen -i $1 -f tx -l 64 &> $2 &
sleep 4
netmap/examples/pkt-gen -i $3 -f rx &> $4 &
