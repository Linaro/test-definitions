#!/bin/bash

test $# -lt 2 && echo "Please pass input and output files" && exit 1
cat $1 | grep main_thread | grep pps | awk '{print "tx_throughput: " $4}' > $2
