#!/bin/bash

/root/netmap/examples/pkt-gen -i $2 -f tx -l 64 &> /root/pkt-gen-tx.txt &
sleep 4
/root/netmap/examples/pkt-gen -i $1 -f rx &> /root/pkt-gen-rx.txt &
