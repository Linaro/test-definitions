#!/bin/sh -e

# SysBench is a modular, cross-platform and multi-threaded benchmark tool.
# Current features allow to test the following system parameters:
# * file I/O performance
# * scheduler performance
# * memory allocation and transfer speed
# * POSIX threads implementation performance
# * database server performance

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
SKIP_INSTALL="false"

# sysbench test parameters.
NUM_THREADS="NPROC"
# TESTS="cpu memory threads mutex fileio oltp"
TESTS="cpu memory threads mutex fileio"

usage() {
    echo "usage: $0 [-n <num-threads>] [-t <test>] [-s <true|false>] 1>&2"
    exit 1
}

while getopts ":n:t:s:" opt; do
    case "${opt}" in
        n) NUM_THREADS="${OPTARG}" ;;
        t) TESTS="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        *) usage ;;
    esac
done
[ "${NUM_THREADS}" = "NPROC" ] && NUM_THREADS=$(nproc)

install_sysbench() {
    git clone https://github.com/akopytov/sysbench
    cd sysbench
    git checkout 0.4
    ./autogen.sh
    if echo "${TESTS}" | grep "oltp"; then
        ./configure
    else
        ./configure --without-mysql
    fi
    make install
    cd ../
}

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

# Test installation.
if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "sysbench installation skipped"
else
    dist_name
    # shellcheck disable=SC2154
    case "${dist}" in
        debian|ubuntu)
            install_deps "git build-essential automake libtool"
            if echo "${TESTS}" | grep "oltp"; then
                install_deps "libmysqlclient-dev mysql-server"
                systemctl start mysql
            fi
            install_sysbench
            ;;
        fedora|centos)
            install_deps "git gcc make automake libtool"
            if echo "${TESTS}" | grep "oltp"; then
                install_deps "mysql-devel mariadb-server mariadb"
                systemctl start mariadb
            fi
            install_sysbench
            ;;
        oe-rpb)
            # Assume all dependent packages are already installed.
            install_sysbench
            ;;
        *)
            warn_msg "Unsupported distro: ${dist}! Package installation skipped!"
            ;;
    esac
fi

# Verify test installation.
sysbench --version

general_parser() {
    # if $1 is there, let's append to test name in the result file
    # shellcheck disable=SC2039
    local tc="$tc$1"
    ms=$(grep -m 1 "total time" "${logfile}" | awk '{print substr($NF,1,length($NF)-1)}')
    add_metric "${tc}-total-time" "pass" "${ms}" "s"

    ms=$(grep "total number of events" "${logfile}" | awk '{print $NF}')
    add_metric "${tc}-total-number-of-events" "pass" "${ms}" "times"

    ms=$(grep "total time taken by event execution" "${logfile}" | awk '{print $NF}')
    add_metric "${tc}-total-time-taken-by-event-execution" "pass" "${ms}" "s"

    for i in min avg max approx; do
        ms=$(grep -m 1 "$i" "${logfile}" | awk '{print substr($NF,1,length($NF)-2)}')
        add_metric "${tc}-response-time-$i" "pass" "${ms}" "ms"
    done

    ms=$(grep "events (avg/stddev)" "${logfile}" |  awk '{print $NF}')
    ms_avg=$(echo "${ms}" | awk -F'/' '{print $1}')
    ms_stddev=$(echo "${ms}" | awk -F'/' '{print $2}')
    add_metric "${tc}-events-avg" "pass" "${ms_avg}" "times"
    add_metric "${tc}-events-stddev" "pass" "${ms_stddev}" "times"

    ms=$(grep "execution time (avg/stddev)" "${logfile}" |  awk '{print $NF}')
    ms_avg=$(echo "${ms}" | awk -F'/' '{print $1}')
    ms_stddev=$(echo "${ms}" | awk -F'/' '{print $2}')
    add_metric "${tc}-execution-time-avg" "pass" "${ms_avg}" "s"
    add_metric "${tc}-execution-time-stddev" "pass" "${ms_stddev}" "s"
}

# Test run.
for tc in ${TESTS}; do
    echo
    info_msg "Running sysbench ${tc} test..."
    logfile="${OUTPUT}/sysbench-${tc}.txt"
    case "${tc}" in
        percpu)
            processor_id="$(awk '/^processor/{print $3}' /proc/cpuinfo)"
            for i in ${processor_id}; do
                taskset -c "$i" sysbench --num-threads=1 --test=cpu run | tee "${logfile}"
                general_parser "$i"
            done
            ;;
        cpu|threads|mutex)
            sysbench --num-threads="${NUM_THREADS}" --test="${tc}" run | tee "${logfile}"
            general_parser
            ;;
        memory)
            sysbench --num-threads="${NUM_THREADS}" --test=memory run | tee "${logfile}"
            general_parser

            ms=$(grep "Operations" "${logfile}" | awk '{print substr($4,2)}')
            add_metric "${tc}-ops" "pass" "${ms}" "ops"

            ms=$(grep "transferred" "${logfile}" | awk '{print substr($4, 2)}')
            units=$(grep "transferred" "${logfile}" | awk '{print substr($5,1,length($NF)-1)}')
            add_metric "${tc}-transfer" "pass" "${ms}" "${units}"
            ;;
        fileio)
            mkdir fileio && cd fileio
            for mode in seqwr seqrewr seqrd rndrd rndwr rndrw; do
                tc="fileio-${mode}"
                logfile="${OUTPUT}/sysbench-${tc}.txt"
                sync
                echo 3 > /proc/sys/vm/drop_caches
                sleep 5
                sysbench --num-threads="${NUM_THREADS}" --test=fileio --file-total-size=2G --file-test-mode="${mode}" prepare
                # --file-extra-flags=direct is needed when file size is smaller then RAM.
                sysbench --num-threads="${NUM_THREADS}" --test=fileio --file-extra-flags=direct --file-total-size=2G --file-test-mode="${mode}" run | tee "${logfile}"
                sysbench --num-threads="${NUM_THREADS}" --test=fileio --file-total-size=2G --file-test-mode="${mode}" cleanup
                general_parser

                ms=$(grep "transferred" "${logfile}" | awk '{print substr($NF, 2,(length($NF)-8))}')
                units=$(grep "transferred" "${logfile}" | awk '{print substr($NF,(length($NF)-6),6)}')
                add_metric "${tc}-transfer" "pass" "${ms}" "${units}"

                ms=$(grep "Requests/sec" "${logfile}" | awk '{print $1}')
                add_metric "${tc}-ops" "pass" "${ms}" "ops"
            done
            cd ../
            ;;
        oltp)
            # Use the same passwd as lamp and lemp tests.
            mysqladmin -u root password lxmptest  > /dev/null 2>&1 || true
            # Delete sysbench in case it exists.
            mysql --user='root' --password='lxmptest' -e 'DROP DATABASE sysbench' > /dev/null 2>&1 || true
            # Create sysbench database.
            mysql --user="root" --password="lxmptest" -e "CREATE DATABASE sysbench"

            sysbench --num-threads="${NUM_THREADS}" --test=oltp --db-driver=mysql --oltp-table-size=1000000 --mysql-db=sysbench --mysql-user=root --mysql-password=lxmptest prepare
            sysbench --num-threads="${NUM_THREADS}" --test=oltp --db-driver=mysql --oltp-table-size=1000000 --mysql-db=sysbench --mysql-user=root --mysql-password=lxmptest run | tee "${logfile}"

            # Parse test log.
            general_parser

            for i in "read" write other total; do
                ms=$(grep "${i}:" "${logfile}" | awk '{print $NF}')
                add_metric "${tc}-${i}-queries" "pass" "${ms}" "queries"
            done

            for i in transactions deadlocks "read/write requests" "other operations"; do
                ms=$(grep "${i}:" sysbench-oltp.txt | awk '{print substr($(NF-2),2)}')
                i=$(echo "$i" | sed 's/ /-/g; s|/|-|')
                add_metric "${tc}-${i}" "pass" "${ms}" "ops"
            done

            # cleanup
            mysql --user='root' --password='lxmptest' -e 'DROP DATABASE sysbench'
            ;;
    esac
done
