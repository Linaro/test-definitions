#!/bin/bash
set -o errexit

THIS_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
HTTPERF_RUNNER=${THIS_DIR}/httperf-runner.py
TEST_DEFS_DIR=$(readlink -f ${THIS_DIR}/../..)
GET_VLAND_IFACE=${TEST_DEFS_DIR}/automated/utils/vland/get_vland_interface.sh

# Configurable Environment variables

# name of the VLAND used
VLAND_NAME=${VLAND_NAME:-vlan_one}

# IP addresses
MY_IP=${MY_IP:-192.168.1.1}

# Server IP
SERVER_IP=${SERVER_IP:-192.168.1.4}

# CPU_AFFINITY: run httperf on this core
CPU_AFFINITY=${CPU_AFFINITY:-0}

# INITIAL_STEP
INITIAL_STEP=${INITIAL_STEP:-13000}

# INITIAL_RATE
INITIAL_RATE=${INITIAL_RATE:-25000}

# Sets IRQ affinity to the same core as httperf will run
function set_irq_affinity {
	local dev=$1
	local irq=0

	ethtool -L $dev combined 1

	for irq in $(grep $dev /proc/interrupts | cut -d : -f 1); do
		echo "-- CHANGING AFFINITY FOR IRQ $irq to $CPU_AFFINITY"
		echo "$CPU_AFFINITY" > /proc/irq/$irq/smp_affinity_list
	done
}

function configure_client {
	local dev=$($GET_VLAND_IFACE $VLAND_NAME)

	echo "--- CONFIGURE CLIENT DEVICE $dev"
	ip address add ${MY_IP}/24 dev $dev
	ip link set $dev up
	set_irq_affinity $dev
	echo "--- DEV $dev up"
	grep $dev /proc/interrupts

	sysctl -w net.ipv4.ip_local_port_range="1500 65500"
	sysctl net.ipv4.ip_local_port_range
}

if ! which lava-wait &>/dev/null; then
	echo "This script must be executed in LAVA"
	exit
fi

configure_client || exit 1

echo "<< WAIT num_cores"
lava-wait num_cores
num_cores=$(cat /tmp/lava_multi_node_cache.txt | cut -d = -f 2)
echo "-- Server has $num_cores cores"

echo ">> SEND client_ready"
lava-send client_ready

for num_cores in 1 $(seq 2 2 $num_cores); do
	echo "<< WAIT server_num_cores_${num_cores}_ready"
	lava-wait server_num_cores_${num_cores}_ready
	echo "-- START NUM CORES: $num_cores"
	# First do a simple wget to warm up caches
	wget -q -O /dev/null ${SERVER_IP}/index.html 
	csv=reqs_${num_cores}
	taskset -c $CPU_AFFINITY $HTTPERF_RUNNER --csv $csv \
		--server ${SERVER_IP} \
		--rate ${INITIAL_RATE} \
		--step ${INITIAL_STEP}
	result=$(head -n 1 $csv)
	echo "-- END ITERATION $num_cores, RESULT: $result"
	lava-test-case performance-${num_cores}-cores \
		--result pass \
		--measurement $result \
		--units trans/s
	echo ">> SEND client_num_cores_${num_cores}_done"
	lava-send client_num_cores_${num_cores}_done
done

echo ">> SEND client_done"
lava-send client_done
echo "A10"
