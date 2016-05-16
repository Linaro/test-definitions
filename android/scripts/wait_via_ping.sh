#!/system/bin/sh

lava_server_ip=$1
timeout_val=$2

if [ -z "${lava_server_ip}" ]; then
    return
fi
if [ -z "${timeout_val}" ]; then
    timeout_val=10
fi

echo "Timeout value is ${timeout_val}"
sleep 5
ping_count=0
echo "ping start: $(date)"
while ! LC_ALL=C ping -W1 -c1 ${lava_server_ip} ; do
    sleep 1
    ping_count=$((ping_count + 1))
    if [ $ping_count -ge ${timeout_val} ]; then
        exit 1
    fi
done
# see how long it will take for the ip to available
echo "ping finished: $(date)"
ifconfig

exit 0
