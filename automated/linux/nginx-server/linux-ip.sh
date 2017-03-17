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

	ip address add "${server_ip}/24" dev "$vland_iface"
	ip link set "$vland_iface" up

	sysctl -w net.ipv4.ip_local_port_range="1500 65500"

	# when using write_config, we need to have /www mounted
	configure_ramdisk

	WRITE_CONFIG_CORE="worker_cpu_affinity auto;"
	WRITE_CONFIG_EVENTS=""
	WRITE_CONFIG_LISTEN="listen $server_ip:80 default_server reuseport so_keepalive=off;"
	echo <<-EOF
	WRITE_CONFIG_CORE=$WRITE_CONFIG_CORE
	WRITE_CONFIG_EVENTS=$WRITE_CONFIG_EVENTS
	WRITE_CONFIG_LISTEN=$WRITE_CONFIG_LISTEN
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

	ethtool -L "$vland_iface" combined "$cores"
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
	echo "-- INTERRUPTS $cores"
	grep "$vland_iface" /proc/interrupts
	echo "--- MPSTAT $cores"
	mpstat -P ALL | cat
}

echo "-- linux-ip NGiNX initialized" >&2
