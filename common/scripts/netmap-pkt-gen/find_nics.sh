#/bin/bash

test $# -lt 1 && echo "Please pass NIC pattern" && exit 1
NIC=$1

truncate -s 0 pci_ids
truncate -s 0 sys_net
truncate -s 0 ifs
lspci -nn | grep -i $NIC | awk '{print $1}' > pci_ids
for i in $(ls /sys/class/net/); do ln=$(readlink -f /sys/class/net/$i/device); echo $i $ln >> sys_net; done
for i in $(cat pci_ids); do cat sys_net | grep $i | awk '{print $1}' >> ifs; done
