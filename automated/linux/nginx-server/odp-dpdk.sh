#!/bin/bash

exit_error() {
	echo "-- SERVER ERROR"
	journalctl -u nginx
	lava-test-case server_up --status fail
}
trap exit_error ERR

do_configure_system() {
	local cores=$1
	local vland_iface=$2
	local server_ip=$3
	local driver=${DPDK_DRIVER:-igb_uio}
	local pci_dev=

	pci_dev=$(basename "$(readlink -f "/sys/class/net/${vland_iface}/device")")

	if ! which dpdk-devbind &>/dev/null; then
		echo "ERROR: dpdk not installed"
		exit 1
	fi

	modprobe "$driver"

	dpdk-devbind -u "$pci_dev"
	dpdk-devbind -b "$driver" "$pci_dev"
	dpdk-devbind -s

	apt-get install -y nginx
	systemctl stop nginx

	# when using write_config, we need to have /www mounted
	configure_ramdisk

	WRITE_CONFIG_CORE=""
	WRITE_CONFIG_EVENTS="use select;"
	WRITE_CONFIG_LISTEN="listen $server_ip:80 default_server so_keepalive=off;"

	# FIXME: for now NGiNX for OFP only supports one core worker
	echo "-- NOTICE: setting MAX_CORES to 1"
	MAX_CORES=1

	echo <<-EOF
	WRITE_CONFIG_CORE=$WRITE_CONFIG_CORE
	WRITE_CONFIG_EVENTS=$WRITE_CONFIG_EVENTS
	WRITE_CONFIG_LISTEN=$WRITE_CONFIG_LISTEN
	MAX_CORES=$MAX_CORES
	EOF

}

do_stop_nginx() {
	systemctl stop nginx
}

do_start_nginx() {
	systemctl start nginx
}

do_write_nginx_config() {
	local cores=$1
	local vland_iface=$2
	local server_ip=$3

	# when using write_config, we need to have /www mounted
	write_config "$cores" /etc/nginx/nginx.conf
}

do_pre_test_cb() {
	local cores=$1
	local vland_iface=$2
	local server_ip=$3

	rm -rf /dev/hugepages/*
}

do_post_test_cb() {
	local cores=$1
	local vland_iface=$2
	local server_ip=$3
	local pid

	systemctl status nginx
	echo "-- AFFINITY $cores"
	for pid in $(pgrep nginx); do
		taskset -p "$pid"
	done
}

echo "-- odp-dpdk NGiNX initialized" >&2
