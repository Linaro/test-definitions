#!/bin/sh

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
# Set default values.
TESTS="stress_ng stress_oom stress_network"
DURATION=$((60 * 60 * 6))
INTERFACE="eth0"
LINK="http://192.168.0.1/files/stress-network.img"
MD5="cd573cfaace07e7949bc0c46028904ff"
NPROC=$(nproc)

usage()
{
    echo "Usage: $0 [-h] [-t tests] [-d duration] [-i interface] [-l link] [-m md5]"
    echo
    echo "Options"
    echo "    -h, --help        Print this help message"
    echo "    -t, --test        Run only specified test from the following:"
    echo "                          stress_ng"
    echo "                          stress_oom"
    echo "                          stress_network"
    echo "    -d, --duration    Set test duration in seconds for each stress test"
    echo "    -i, --interface   Run network stress on the specified interface."
    echo "    -l, --link        Specify file link for download test."
    echo "    -m, --md5         Set md5 value of the file used for download test."
    echo
    echo "Examples"
    echo "    Run all stress tests with defualt settings:"
    echo "        $0"
    echo "    Set test duration for each test to 1 hour:"
    echo "        $0 -d 3600"
    echo "    Run network stress test on eth0:"
    echo "        $0 -t stress_network -i eth0"
    echo "    Run stress_ng and stress_oom:"
    echo "        $0 -t 'stress_ng stress_oom'"
    echo
}

# Parse command line arguments.
while [ $# -gt 0 ]
do
    case $1 in
        -t|--test)
            TESTS="$2"
            ;;
        -d|--DURATION)
            DURATION="$2"
            ;;
        -i|--INTERFACE)
            INTERFACE="$2"
            ;;
        -l|--LINK)
            LINK="$2"
            ;;
        -m|--MD5)
            MD5=$2
            ;;
        -h|--help)
            usage
            exit 1
            ;;
        *)
            echo "Unknown option $*"
            usage
            exit 1
            ;;
    esac
    shift 2
done

stress_ng()
{
    workloads="cpu io fork switch vm pipe yield hdd cache sock fallocate flock affinity timer dentry urandom sem open sigq poll"
    workload_number=$(echo "$workloads" | wc -w)
    sub_duration=$(( DURATION / workload_number ))

    echo "CPU(s): $NPROC"
    echo "Workloads to run: $workloads"
    echo "Total stress_ng test duration: $DURATION seconds"
    echo "Test duration for each workload: $sub_duration seconds"

    count=1
    for i in $workloads
    do
        echo
        echo "[$count/$workload_number] Running $i workload..."
        if [ "$i" = "vm" ]; then
            # mmap 64M per vm process to avoid OOM, the default is 256M.
            stress-ng --"$i" "$NPROC" --vm-bytes 64m --timeout "$sub_duration" --metrics-brief --verbose
        else
            stress-ng --"$i" "$NPROC" --timeout "$sub_duration" --metrics-brief --verbose
        fi
        check_return stress-ng-"$i"
        count=$(( count + 1 ))
    done
}

stress_oom()
{
    mem=$(free | grep Mem | awk '{print $2}')
    swap=$(free | grep Swap | awk '{print $2}')
    total_mem=$(( mem + swap ))
    vm_bytes=$(( total_mem / NPROC ))

    echo
    echo "CPU(s): $NPROC"
    echo "Total Memory: $total_mem"
    echo "Stress OOM test duration: $DURATION seconds"
    echo "About to run $NPROC stress-ng-vm instances"

    # Clear dmesg and save new output continuously to a log file.
    dmesg --clear
    dmesg --follow > "${OUTPUT}/stress_oom_kern.log" 2>&1 &
    kernel_log=$!
    # Disable oom-killer on the log collecting process.
    # shellcheck disable=SC2039
    echo -17 > "/proc/${kernel_log}/oom_score_adj"

    # Run stress-ng-vm test to trigger oom-killer.
    # In stress-vm.c file, NO_MEM_RETRIES_MAX has been increased to 1000000000 for OOM stress test.
    echo "mmap ${vm_bytes}KB per vm process to occupy all memory to trigger oom-killer."
    stress-ng --vm "$NPROC" --vm-bytes "${vm_bytes}k" --timeout "$DURATION" --metrics-brief --verbose

    # Check if oom-killer triggered.
    kill $kernel_log
    oom_number=$(grep -c "Out of memory: Kill process" "$OUTPUT/stress_oom_kern.log")
    if [ "$oom_number" -eq 0 ]; then
        echo "Failed to active oom-killer."
        report_fail "stress-oom-test"
    else
        echo "oom-killer activated $oom_number times within $DURATION seconds"
        report_pass "stress-oom-test"
    fi
}

stress_network()
{
    echo "Stress network test duration: $DURATION"
    echo "Test interface: $INTERFACE"
    echo "File link: $LINK"
    echo "md5: $MD5"

    # Check if network set on the interface.
    gateway=$(ip route show default | grep -m 1 default | awk '{print $3}')
    if ! ping -c 10 -I "$INTERFACE" "$gateway"; then
        echo "Please check network connection and rerun this script"
        exit 1
    fi

    # Run 'stress-ng hdd' stress in the background.
    echo "About to run 'stress-ng --hdd 1' in background"
    stress-ng --hdd 1 > /dev/null 2>&1 &
    stress_ng_hdd=$!
    sleep 5

    end=$(( $(date +%s) + DURATION ))
    iteration=0
    while [ "$(date +%s)" -lt "$end" ]
    do
        echo
        echo "Running stress_network iteration $iteration"
        if ! pgrep -l "stress-ng-hdd"; then
            echo "'stress-ng --hdd 1' is dead, restarting..."
            stress-ng --hdd 1 > /dev/null 2>&1 &
            stress_ng_hdd=$!
        else
            echo "'stress-ng --hdd 1' is running in background"
        fi

        # Network enable/disable test.
        ip link set "$INTERFACE" down
        sleep 15
        ip link show dev "$INTERFACE" | grep "state DOWN"
        check_return "network-disable-$iteration"
        ip link set "$INTERFACE" up
        sleep 15
        ip link show dev "$INTERFACE" | grep "state UP"
        check_return "network-enable-$iteration"

        # Check if IP obtained.
        dhclient "$INTERFACE" > /dev/null 2>&1 || true
        ip=$(ip addr show "$INTERFACE" | grep -w inet | awk '{print $2}' | awk -F'/' '{print $1}')
        test -n "$ip"
        check_return "network-ip-check-$iteration"

        # File download test.
        test -e stress-network.img && rm -rf stress-network.img
        curl -O --interface "$ip" "$LINK"
        check_return "file-download-$iteration"
        local_md5=$(md5sum stress-network.img | awk '{print $1}')
        test "$local_md5" = "$MD5"
        check_return "file-md5-check-$iteration"

        iteration=$(( iteration + 1 ))
    done

    kill "$stress_ng_hdd"
}

## Setup environment and run tests.
! check_root && error_msg "You need to be root to run this test!"
[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}_$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}"

command -v curl || install_deps "curl"
if ! stress-ng -V; then
    echo "stress-ng not found, installing..."
    detect_abi
    # shellcheck disable=SC2154
    cp "bin/${abi}/stress-ng" /usr/bin/stress-ng
    chmod +x /usr/bin/stress-ng
    echo
fi

# Run tests.
for i in $TESTS
do
    "$i" 2>&1 | tee "${OUTPUT}/${i}.log"
done
