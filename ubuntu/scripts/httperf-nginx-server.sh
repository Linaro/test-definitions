#!/bin/bash
set -o errexit

THIS_DIR=$(dirname $(readlink -f "${BASH_SOURCE[0]}"))
TEST_DEFS_DIR=$(readlink -f ${THIS_DIR}/../..)
GET_VLAND_IFACE=${TEST_DEFS_DIR}/common/scripts/vland/get_vland_interface.sh
GET_VLAND_PCI_DEV=${TEST_DEFS_DIR}/common/scripts/vland/get_vland_pci_dev.sh

# vlnad name to use
VLAND_NAME=${VLAND_NAME:-vlan_one}
VLAND_IFACE=$($GET_VLAND_IFACE $VLAND_NAME)
VLAND_PCI_DEV=$($GET_VLAND_PCI_DEV $VLAND_NAME)

# Do not run tests on more than MAX_CORES cores
# 0 means use all cores
MAX_CORES=${MAX_CORES:-0}

# IP address of the server
SERVER_IP=${SERVER_IP:-192.168.1.4}

# What kind of configuration to use:
#   linux-ip: plain Linux IP stack
#   odp-dpdk: NGiNX with OFP+ODP+DPDK
CONFIG_TYPE=${CONFIG_TYPE:-linux-ip}

# DEB_URL
DEB_URL=${DEB_URL:-http://people.linaro.org/~josep.puigdemont/debs}

function exit_error {
	echo "-- SERVER ERROR"
	journalctl -u nginx
	lava-test-case server_up --status fail
}
trap exit_error ERR

# Use this function to configure Linux IP stack
function config_linux_ip {
	ip address add ${SERVER_IP}/24 dev $VLAND_IFACE
	ip link set $VLAND_IFACE up
	lava-test-case server_ifup --result pass

	sysctl -w net.ipv4.ip_local_port_range="1500 65500"
	sysctl net.ipv4.ip_local_port_range
}

# Use this function to configure a device for DPDK usage
# FIXME: this should use a repository
function config_dpdk_dev {
	local driver=${1:-igb_uio}
	local DEBS="libofp-odp-dpdk0_1.1+git3+4ec95a1-0linaro1linarojessie1_amd64.deb"

	if ! $(which dpdk-devbind &>/dev/null); then
		echo "ERROR: dpdk not installed"
		exit 1
	fi

	modprobe $driver

	dpdk-devbind -u $VLAND_PCI_DEV
	dpdk-devbind -b ${driver} $VLAND_PCI_DEV
	dpdk-devbind -s

	apt-get install -y nginx
	systemctl stop nginx

	# we want our version of libofp, with CONFIG_WEBSERVER set
	apt-get remove -y libofp-odp-dpdk0 nginx-common
	mkdir ofp
	cd ofp
	for deb in $DEBS; do
		wget -q $DEB_URL/ofp-config-webserver/$deb
		dpkg -i $deb
	done
	cd ..
}

# Callback to call before starting nginx when using OFP-DPDK
# First parameter of callback is the number of cores
function odp_dpdk_pre_cb {
	local cores=$1
	local DEBS="nginx-common_1.9.10-1~linaro1linarojessie1_all.deb \
		    nginx-full_1.9.10-1~linaro1linarojessie1_amd64.deb \
		    nginx_1.9.10-1~linaro1linarojessie1_all.deb"

	apt-get remove -y nginx-common

	# clean hugepages
	rm -rf /dev/hugepages/*

	mkdir -p iter_${cores}
	cd iter_${cores}
	for deb in $DEBS; do
		wget -q $DEB_URL/nginx-ofp-odp-dpdk/${cores}_queue/$deb
		dpkg --force-confold -i $deb
	done
	cd ..
}

function odp_dpdk_post_cb {
	local cores=$1

	systemctl status nginx
	echo "-- AFFINITY $cores"
	for pid in $(pgrep nginx); do
		taskset -p $pid
	done
}

function linux_ip_pre_cb {
	local cores=$1

	ethtool -L $VLAND_IFACE combined $cores
}

function linux_ip_post_cb {
	local cores=$1

	systemctl status nginx
	echo "-- AFFINITY $cores"
	for pid in $(pgrep nginx); do
		taskset -p $pid
	done
	echo "-- INTERRUPTS $cores"
	grep $VLAND_IFACE /proc/interrupts
	echo "--- MPSTAT $cores"
	mpstat -P ALL | cat
}

function configure_ramdisk {
	local ROOT=/www
	mkdir $ROOT
	mount -t tmpfs -o size=1M tmpfs $ROOT
	echo "-- Ramdisk created: "
	df -h $ROOT
	echo "-- END"
	lava-test-case server_www_ramdisk --result pass

	cat > $ROOT/index.html <<-EOF
	<html>
	<head><title>NGiNX test</title></head>
	<body>
	IT WORKS
	</body>
	</html>
	EOF
}

function write_config {
	# Simple configuration file for NGiNX
	cat > /etc/nginx/nginx.conf <<-EOF
	user www-data;
	worker_processes $1;
	timer_resolution 1s;
	worker_rlimit_nofile 4096;
	error_log /dev/null crit;
	pid /run/nginx.pid;
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
	        listen ${SERVER_IP}:80 default_server ${REUSEPORT} so_keepalive=off;
	        location / {
	            root /www;
	        }
	    }
	}
	EOF
	echo "-- CONFIG FOR $1:"
	cat /etc/nginx/nginx.conf
	echo "-- END --"
}

function get_num_real_cores {
	local cores_socket=$(lscpu | awk -F : '/^Core\(s\) per/ {print $2;}')
	local num_sockets=$(lscpu | awk -F : '/^Socket\(s\)/ {print $2;}')
	local num_cores=$((cores_socket * num_sockets))

	if [ $MAX_CORES -ne 0 -a $num_cores -gt $MAX_CORES ]; then
		num_cores=$MAX_CORES
	fi
	echo $num_cores
}

configure_ramdisk

case ${CONFIG_TYPE} in
	linux-ip)
		echo "-- CONFIGURING Linux Kernel IP stack"
		config_linux_ip
		PRE_TEST_CB="linux_ip_pre_cb"
		POST_TEST_CB="linux_ip_post_cb"
		WRITE_CONFIG_CORE="worker_cpu_affinity auto;"
		WRITE_CONFIG_EVENTS=""
		REUSEPORT="reuseport"
		;;
	odp-dpdk)
		echo "-- CONFIGURING OFP IP Stack"
		config_dpdk_dev
		PRE_TEST_CB="odp_dpdk_pre_cb"
		POST_TEST_CB="odp_dpdk_post_cb"
		WRITE_CONFIG_CORE=""
		WRITE_CONFIG_EVENTS="use select;"
		REUSEPORT=""
		;;
	*)
		echo "Invalid CONFIG_TYPE: $CONFIG_TYPE"
		exit 1
		;;
esac

NUM_CORES=$(get_num_real_cores)
echo ">> SEND num_cores cores=$NUM_CORES"
lava-send num_cores cores=$NUM_CORES

echo "<< WAIT client_ready"
lava-wait client_ready

for num_cores in 1 $(seq 2 2 $NUM_CORES); do
	echo "-- BEGIN $num_cores"
	echo "-- Stopping NGiNX"
	systemctl stop nginx
	echo "-- Writing configuration file for $num_cores"
	write_config $num_cores
	echo "-- CALLING PRE-TEST CALLBACK $PRE_TEST_CB"
	$PRE_TEST_CB $num_cores
	echo "-- STARTING NGiNX for test $num_cores"
	systemctl start nginx
	echo ">> SEND server_num_cores_${num_cores}_ready"
	lava-send server_num_cores_${num_cores}_ready
	echo "<< WAIT client_num_cores_${num_cores}_done"
	lava-wait client_num_cores_${num_cores}_done
	echo "-- CALLING POST-TEST CALLBACK $POST_TEST_CB"
	$POST_TEST_CB $num_cores
	echo "-- END $num_cores"
done

echo "<< WAIT client_done"
lava-wait client_done
echo "A10"
