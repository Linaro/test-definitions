#!/bin/sh

delay=10
SNMPSET="/usr/bin/snmpset"
CONTROL_OID=".1.3.6.1.4.1.318.1.1.4.4.2.1.3."

usage() {
    printf "usage: control-chamelium.py [-h] --hostname HOSTNAME --port PORT --command
                            {off,on,reboot} [--delay DELAY]\n
optional arguments:
  -h, --help            show this help message and exit
  --hostname HOSTNAME   The pdu you wish to control - e.g. pdu05
  --port PORT           The pdu port you wish to control, e.g. 4 or 15
  --command {off,on,reboot}
                        What you wish to do with the port 'off', 'on',
                        'reboot'
  --delay DELAY         Delay in seconds when rebooting between power off and
                        power on (default 10 seconds)\n"
}

send_command() {
    control_oid="${CONTROL_OID}${port}"
    echo "Turn ${hostname} port ${port} $1"
    if [ "$1" = "on" ]; then
        cmd="1"
    else
        cmd="2"
    fi

    ${SNMPSET} -v 1 -c private "${hostname}" "${control_oid}" i "${cmd}"
}

while [ $# -gt 0 ]
do
    key="$1"

    case $key in
        -h|--help)
            usage
            exit 0
            ;;
        --hostname)
            hostname="$2"
            shift
            shift
            ;;
        --port)
            port="$2"
            shift
            shift
            ;;
        --command)
            command="$2"
            shift
            shift
            ;;
        --delay)
            delay="$2"
            shift
            shift
            ;;
        *)
            usage
            exit 0
            ;;
    esac 
done

if [ -z "$(ls ${SNMPSET})" ]; then
    echo "Can not find ${SNMPSET}"
    exit 1
fi
if [ -z "${hostname}" ] || [ -z "${port}" ] || [ -z "${command}" ]; then
    usage
    exit 1
fi
if [ "${command}" != "off" ] && [ "${command}" != "on" ] && [ "${command}" != "reboot" ]; then
    usage
    exit 1
fi

if [ "${command}" = "reboot" ]; then
    send_command "off"
    sleep "${delay}"
    send_command "on"
else
    send_command "${command}"
fi
