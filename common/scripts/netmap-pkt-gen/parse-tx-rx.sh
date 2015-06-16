#!/bin/bash

# This script parses the output from netmap and transforms it into something
# usable by common/script/min_max_avg_parse.py
# Sample command: parse-tx-rx.sh tx.in tx.out rx.in rx.out

test $# -lt 4 && echo "Please pass input and output files" && exit 1
cat $1 | grep main_thread | grep pps | awk '{print "tx_throughput: " $4}' > $2
cat $3 | grep main_thread | grep pps | awk '{print "rx_throughput: " $4}' > $4
