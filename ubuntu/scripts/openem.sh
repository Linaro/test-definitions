#!/bin/bash -x

mount -t tmpfs none /dev/shm
echo 400 > /proc/sys/vm/nr_hugepages

rm -rf ./Build
mkdir ./Build
cd ./Build

wget http://people.linaro.org/~maxim.uvarov/Intel_DPDK%20Code_1.5.0_8.zip
unzip Intel_DPDK\ Code_1.5.0_8.zip
mv DPDK-1.5.0 DPDK_1.5.0-8

git clone git://git.linaro.org/lng/eventmachine-code.git eventmachine-code.git

patch  -p0 < ./eventmachine-code.git/misc/linux-generic/patch/DPDK_1.5.0-8-linux-generic.patch
cd DPDK_1.5.0-8

sed -i 's/CONFIG_RTE_MAX_MEMZONE=2560/CONFIG_RTE_MAX_MEMZONE=131072/' ./config/defconfig_*
sed -i 's/CONFIG_RTE_MEMPOOL_CACHE_MAX_SIZE=512/CONFIG_RTE_MEMPOOL_CACHE_MAX_SIZE=2048/' ./config/defconfig_*
sed -i 's/CONFIG_RTE_MBUF_SCATTER_GATHER=y/CONFIG_RTE_MBUF_SCATTER_GATHER=n/' ./config/defconfig_*
sed -i 's/CONFIG_RTE_MBUF_REFCNT_ATOMIC=y/CONFIG_RTE_MBUF_REFCNT_ATOMIC=n/' ./config/defconfig_*
sed -i 's/CONFIG_RTE_PKTMBUF_HEADROOM=128/CONFIG_RTE_PKTMBUF_HEADROOM=192/' ./config/defconfig_*
make install T=generic_32-default-linuxapp-gcc

export RTE_SDK=`pwd`
export RTE_TARGET=generic_32-default-linuxapp-gcc
#export RTE_TARGET=generic_64-default-linuxapp-gcc

mkdir /mnt/huge
umount /mnt/huge
mount -t hugetlbfs nodev /mnt/huge

#EM
cd ../eventmachine-code.git/event_test/example/linux-generic
make real_clean && make em_clean
make

#run some tests:
./build/hello -c 0xfe -n 4 -- -p  | head -n 500    # (Run 'hello' on  7 cores using EM process-per-core mode(-p))
./build/hello -c 0xfcfc -n 4 -- -t | head -n 500       # (Run 'hello' on 12 cores using EM thread-per-core  mode(-t))
./build/perf -c 0xffff -n 4 -- -p  | head -n 500      # (Run 'perf' on 16 cores using EM process-per-core mode(-p))
./build/perf -c 0xfffe -n 4 -- -t  | head -n 500      # (Run 'perf' on 15 cores using EM thread-per-core  mode(-t))
./build/event_group -c 0x0c0c -n 4 -- -p | head -n 500 # (Run 'event_group' on 4 cores using EM process-per-core mode(-p))
./build/event_group -c 0x00f0 -n 4 -- -t | head -n 500 # (Run 'event_group' on 4 cores using EM thread-per-core  mode(-t))
./build/error -c 0x3 -n 4 -- -p |head -n 500         # (Run 'error' on 2 cores using EM process-per-core mode(-p))
./build/error -c 0x2 -n 4 -- -t |head -n 500         # (Run 'error' on 1 core  using EM thread-per-core  mode(-t))

echo "OPENEM TEST END!!!"

