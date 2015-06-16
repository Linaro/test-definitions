#!/bin/sh
test $# -lt 1 && echo "Please pass path to DPDK" && exit 1
cd $1
for n in $(./tools/dpdk_nic_bind.py --status | awk ' $2 ~ "82599" {print $1}')
do
   ./tools/dpdk_nic_bind.py --bind=igb_uio $n
done
