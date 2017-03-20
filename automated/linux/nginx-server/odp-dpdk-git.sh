#!/bin/bash

exit_error() {
	echo "-- SERVER ERROR"
	lava-test-case server_up --status fail
}
trap exit_error ERR

do_configure_system() {
	local cores=$1
	local vland_iface=$2
	local server_ip=$3
	local driver=${DPDK_DRIVER:-igb_uio}
	local pci_dev

	pci_dev=$(basename "$(readlink -f "/sys/class/net/${vland_iface}/device")")

	if ! which dpdk-devbind &>/dev/null; then
		echo "ERROR: dpdk not installed"
		exit 1
	fi

	modprobe uio
	insmod "$RTE_SDK/$RTE_TARGET/lib/modules/$(uname -r)/extra/dpdk/${driver}.ko"

	dpdk-devbind -u "$pci_dev"
	dpdk-devbind -b "$driver" "$pci_dev"
	dpdk-devbind -s

	# when using write_config, we need to have /www mounted
	configure_ramdisk

	# shellcheck disable=SC2034
	WRITE_CONFIG_CORE=""
	WRITE_CONFIG_EVENTS="use select;"
	WRITE_CONFIG_LISTEN="listen $server_ip:80 default_server so_keepalive=off;"
	echo <<-EOF
	WRITE_CONFIG_CORE=$WRITE_CONFIG_CORE
	WRITE_CONFIG_EVENTS=$WRITE_CONFIG_EVENTS
	WRITE_CONFIG_LISTEN=$WRITE_CONFIG_LISTEN
	EOF
}

do_stop_nginx() {
	if [ -f "${BASE_DIR}/install/run/nginx.pid" ]; then
		stop_nginx.sh 1
	fi
}

do_start_nginx() {
	start_nginx.sh 1
}

do_write_nginx_config() {
	local cores=$1

	# when using write_config, we need to have /www mounted
	write_config "$cores" "${BASE_DIR}/install/etc/nginx/nginx.conf"
}

do_pre_test_cb() {
	rm -rf /dev/hugepages/*
}

do_post_test_cb() {
	local cores=$1
	local pid

	echo "-- AFFINITY $cores"
	for pid in $(pgrep nginx); do
		taskset -p "$pid"
	done
}

BASE_DIR=${BASE_DIR:-/build}

if [ ! -f "${BASE_DIR}/environ" ]; then
	echo "ERROR: ${BASE_DIR}/environ file not found!" >&2
	exit 1
fi

# shellcheck disable=SC1090
. "${BASE_DIR}/environ"

echo "-- odp-dpdk-git NGiNX initialized" >&2
