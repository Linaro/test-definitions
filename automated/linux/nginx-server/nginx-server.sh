#!/bin/bash
set -o errexit
set -x

THIS_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
TEST_DEFS_DIR=$(readlink -f "${THIS_DIR}/../../..")
GET_VLAND_IFACE=${TEST_DEFS_DIR}/automated/utils/vland/get_vland_interface.sh

# vlnad name to use
VLAND_NAME=${VLAND_NAME:-vlan_one}
VLAND_IFACE=$($GET_VLAND_IFACE "$VLAND_NAME")

# Do not run tests on more than MAX_CORES cores
# 0 means use all cores
MAX_CORES=${MAX_CORES:-0}

# IP address of the server
SERVER_IP=${SERVER_IP:-192.168.1.4}

# What kind of configuration to use:
#   linux-ip: plain Linux IP stack
#   odp-dpdk: NGiNX with OFP+ODP+DPDK
CONFIG_TYPE=${CONFIG_TYPE:-linux-ip}

function configure_ramdisk {
	local ROOT=/www
	mkdir "$ROOT"
	mount -t tmpfs -o size=1M tmpfs "$ROOT"
	echo "-- Ramdisk created: "
	df -h "$ROOT"
	echo "-- END"
	lava-test-case server_www_ramdisk --result pass

	cat > "$ROOT/index.html" <<-EOF
	<html>
	<head><title>NGiNX test</title></head>
	<body>
	IT WORKS
	</body>
	</html>
	EOF
}

function write_config {
	local cores=${1}
	local config_file=${2:-/etc/nginx/nginx.conf}

	# Simple configuration file for NGiNX
	cat > "$config_file" <<-EOF
	user www-data;
	worker_processes $cores;
	timer_resolution 1s;
	worker_rlimit_nofile 4096;
	error_log /dev/null crit;
	${WRITE_CONFIG_CORE}

	events {
	    worker_connections 1024;
	    ${WRITE_CONFIG_EVENTS}
	}

	http {
	    access_log off;
	    sendfile on;
	    tcp_nopush on;
	    tcp_nodelay on;
	    keepalive_timeout 0;
	    open_file_cache max=10;
	    server {
	        # TODO: investigate backlog value
		${WRITE_CONFIG_LISTEN:-listen 80 default_server;}
	        location / {
	            root /www;
	        }
	    }
	}
	EOF
	echo "-- CONFIG FOR $1:"
	cat "$config_file"
	echo "-- END --"
}

function get_num_real_cores {
	local cores_socket
	local num_sockets
	local num_cores

	cores_socket=$(lscpu | awk -F : '/^Core\(s\) per/ {print $2;}')
	num_sockets=$(lscpu | awk -F : '/^Socket\(s\)/ {print $2;}')
	num_cores=$((cores_socket * num_sockets))

	if [ "${MAX_CORES}" -ne 0 ] && [ "${num_cores}" -gt "${MAX_CORES}" ]; then
		num_cores=$MAX_CORES
	fi
	echo "$num_cores"
}

test_functions="${THIS_DIR}/${CONFIG_TYPE}.sh"

if [ ! -f "$test_functions" ]; then
	echo "Invalid CONFIG_TYPE: $CONFIG_TYPE"
	exit 1
fi

echo "-- Sourcing $test_functions" >&2

# shellcheck disable=SC1090
. "$test_functions"

do_configure_system "$(get_num_real_cores)" "$VLAND_IFACE" "$SERVER_IP"

NUM_CORES=$(get_num_real_cores)
echo ">> SEND num_cores cores=$NUM_CORES"
lava-send num_cores cores="$NUM_CORES"

echo "<< WAIT client_ready"
lava-wait client_ready

for num_cores in 1 $(seq 2 2 "$NUM_CORES"); do
	echo "-- BEGIN $num_cores"
	echo "-- Stopping NGiNX"
	do_stop_nginx
	echo "-- Writing configuration file for $num_cores"
	do_write_nginx_config "$num_cores" "$VLAND_IFACE" "$SERVER_IP"
	echo "-- CALLING PRE-TEST CALLBACK $PRE_TEST_CB"
	do_pre_test_cb "$num_cores" "$VLAND_IFACE" "$SERVER_IP"
	echo "-- STARTING NGiNX for test $num_cores"
	do_start_nginx
	echo ">> SEND server_num_cores_${num_cores}_ready"
	lava-send "server_num_cores_${num_cores}_ready"
	echo "<< WAIT client_num_cores_${num_cores}_done"
	lava-wait "client_num_cores_${num_cores}_done"
	echo "-- CALLING POST-TEST CALLBACK $POST_TEST_CB"
	do_post_test_cb "$num_cores" "$VLAND_IFACE" "$SERVER_IP"
	echo "-- END $num_cores"
done

do_stop_nginx

echo "<< WAIT client_done"
lava-wait client_done
echo "A10"
