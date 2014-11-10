#!/bin/sh
#
# Author: Viresh Kumar <viresh.kumar@linaro.org>
#
# This script is used for isolating $1 (comma separated list of CPUs) CPUs from
# other kernel background activities.
#
# This runs task on the isolated CPUs and Figures out if CPUs are
# isolated or not by reading 'cat /proc/interrupts' for all interrupts.

# SCRIPT ARGUMENTS
# $1: CPUs to isolate (default 1), pass comma separated list here
# $2: number of samples to take (default 1)
# $3: Min Isolation Time Expected in seconds (default 10)

# Script arguments
ISOL_CPUS=1         # CPU to isolate, default 1. Comma-separated list of CPUs.
SAMPLE_COUNT=1      # How many samples to be taken
MIN_ISOLATION=10    # Minimum isolation expected

# Global variables
STRESS_DURATION=5000        # Run task for this duration
NON_ISOL_CPUS="0"           # CPU not to isolate, zero will always be there as we can't stop ticks on boot CPU.
DEBUG_SCRIPT=1              # Print debug messages, set 0 if not required
TASK="stress"               # Single threaded task to Run on Isolated CPUs
FUNC="all"                  # Perform complete isolation test by default
SCRIPT_VERSION=1.0          # To track release version
FILE="cat /proc/interrupts" # File to monitor for isolation
QUIRKS=""                   # IPI mask variable for known x86 IPI quirk, default 'null'
RESULT="PASS"

# Variables to keep an eye on total interrupt counts
old_count=0
new_count=0

# ROUTINES
# ------------------------------------

# Print debug messages, set DEBUG_SCRIPT to 0 if not required
isdebug() {
    if [ $DEBUG_SCRIPT -eq 1 ]; then
        $*
    fi
}

# Calls routine $1 for each Isolated CPU with parameter CPU-number
for_each_isol_cpu() {
    for i in `echo $ISOL_CPUS | sed 's/,/ /g'`; do
        $1 $i
    done
}

# Get rid of cpufreq-timer activities, pass CPU number in $1
cpufreq_fix_governor() {
    # Remove governor's background timers, i.e. use performance governor
    if [ -d /sys/devices/system/cpu/cpu$1/cpufreq ]; then
        echo performance > /sys/devices/system/cpu/cpu$1/cpufreq/scaling_governor
    fi
}

# dump all interrupts on standard output
dump_interrupts() {
    [ ! $1 ] && printf "\nInitial dump of /proc/interrupts\n"
    [ $1 ] && printf "\n\nInterrupted: new dump of /proc/interrupts\n"
    echo "----------------------------------------------"

    cat /proc/interrupts
    printf "\n\n"
}

# Check $1 is isol cpu or not
is_isol_cpu() {
    for i in `echo $ISOL_CPUS | sed 's/,/ /g'`; do
        if [ $i = $1 ]
        then
            echo 1 # isol cpu found
        fi
    done

    echo 0 # non-isol cpu
}

# update list of all non-ISOL CPUs
update_non_isol_cpus() {
    total_cpus=`nproc --all --ignore=1` #ignore CPU 0 as we already have that
    cpu=1

    while [ $cpu -le $total_cpus ]
    do
        [ "$(is_isol_cpu $cpu)" == 0 ] && NON_ISOL_CPUS="$NON_ISOL_CPUS,$cpu"
        let cpu=cpu+1
    done

    isdebug echo "Isolate: CPU "$ISOL_CPUS" and leave others: "$NON_ISOL_CPUS
    isdebug echo ""
}

# Find total number of interrupts for
# - one CPU, pass cpu number as parameter
# - all CPUs, pass "ALL" as parameter
total_interrupts() {
    (([ $QUIRKS ] && $FILE | egrep -v $QUIRKS) || $FILE) |
    awk -v isolate_cpu="$1" '
    BEGIN {
        line=0;
    }

    # Find total CPUs, do only on first row
    NR==1 {
        cpus = NF;
        next;
    }

    # Fill array with interrupt counts
    {
        for (cpu = 0; cpu < cpus; cpu++) {
            irqs[cpu, line] = $(cpu+2);
        }
        line++;
    }

    # Count total interrupts:
    END {
        for (cpu = 0; cpu < cpus; cpu++) {
            for (j = 0; j < line; j++) {
                count[cpu] += irqs[cpu,j];
                # for debugging
                # printf "%d: %d: %d\n",cpu, j,irqs[cpu,j];
            }

            if (isolate_cpu == "ALL")
                printf "%d ",count[cpu]
            else if (cpu == isolate_cpu)
                printf "%d ",count[cpu]

        }
        printf "\n"
    }

    # File to process
'
}

# Create per-cpu data plane cpuset
create_dplane_cpuset() {
    # Create per-cpu cpuset and set important fields
    [ -d /dev/cpuset/dplane/cpu$1 ] || mkdir /dev/cpuset/dplane/cpu$1

    echo 0 > /dev/cpuset/dplane/cpu$1/$CPUSET_PREFIX"mems"
    echo $1 > /dev/cpuset/dplane/cpu$1/$CPUSET_PREFIX"cpus"
    echo 0 > /dev/cpuset/dplane/cpu$1/$CPUSET_PREFIX"sched_load_balance"

    # exit early in case of non-stress app
    if [ "stress" != "$TASK" ]; then
        return
    fi

    # Move shell to isolated CPU
    echo $$ > /dev/cpuset/dplane/cpu$1/tasks

    # Start single cpu bound task
    stress -q --cpu 1 --timeout $STRESS_DURATION &

    # Move shell back to control plane CPU
    echo $$ > /dev/cpuset/cplane/tasks
}

# Remove per-cpu cpusets
remove_dplane_cpuset() {
    rmdir /dev/cpuset/dplane/cpu$1
}

# Update sysfs tunables to isolate CPU
update_sysfs_tunables() {
    # Call cpufreq_fix_governor for each isolated CPU
    for_each_isol_cpu cpufreq_fix_governor

    # Affine all irqs to CPU0
    for i in `find /proc/irq/* -name smp_affinity`; do
        echo 1 > $i > /dev/null;
    done

    # Try to disable sched_tick_max_deferment
    if [ -d /sys/kernel/debug -a -f /sys/kernel/debug/sched_tick_max_deferment ]; then
        echo -1 > /sys/kernel/debug/sched_tick_max_deferment
        echo "sched_tick_max_deferment set to:" `cat /sys/kernel/debug/sched_tick_max_deferment`
    else
        sysctl -e kernel.sched_tick_max_deferment=-1

    fi

    # Move bdi writeback workqueues to CPU0
    echo 1 > /sys/bus/workqueue/devices/writeback/cpumask

    # Delay the annoying vmstat timer far away (in seconds)
    sysctl vm.stat_interval=1000

    # Delay the annoying vmstat timer far away (in centiseconds)
    sysctl vm.dirty_writeback_centisecs=100000

    # Delay the annoying vmstat timer far away (in centiseconds)
    sysctl vm.dirty_expire_centisecs=100000

    # Shutdown nmi watchdog as it uses perf events
    sysctl -w kernel.watchdog=0
}

# routine to isolate a CPU
isolate_cpu() {
    isdebug echo ""
    isdebug echo "Started Isolating CPUs - via CPUSETS"
    isdebug echo "------------------------------------"
    isdebug echo ""

    # Update list of non isol CPUs
    update_non_isol_cpus

    # Update sysfs tunables
    update_sysfs_tunables

    # Check that we have cpusets enabled in the kernel
    if ! grep -q -s cpuset /proc/filesystems ; then
        echo "Error: Kernel is lacking support for cpuset!"
        exit 1
    fi

    # make sure that the /dev/cpuset dir exits
    # and mount the cpuset filesystem if needed
    [ -d /dev/cpuset ] || mkdir /dev/cpuset
    mount | grep /dev/cpuset > /dev/null || mount -t cpuset none /dev/cpuset

    # Create 2 cpusets. One control plane and one data plane
    [ -d /dev/cpuset/cplane ] || mkdir /dev/cpuset/cplane
    [ -d /dev/cpuset/dplane ] || mkdir /dev/cpuset/dplane

    # check if platform needs a prefix for cpuset
    [ -f /dev/cpuset/cplane/cpus ] && CPUSET_PREFIX=""
    [ -f /dev/cpuset/cplane/cpuset.cpus ] && CPUSET_PREFIX="cpuset."

    # Give same mems to both
    echo 0 > /dev/cpuset/cplane/$CPUSET_PREFIX"mems"
    echo 0 > /dev/cpuset/dplane/$CPUSET_PREFIX"mems"

    # Setup the cplane domain: CPU0
    echo $NON_ISOL_CPUS > /dev/cpuset/cplane/$CPUSET_PREFIX"cpus"

    # Setup the NOHZ domain: CPU1
    echo $ISOL_CPUS > /dev/cpuset/dplane/$CPUSET_PREFIX"cpus"

    # Try to move all processes in top set to the cplane set.
    for pid in `cat /dev/cpuset/tasks`; do
        if [ -d /proc/$pid ]; then
            echo $pid > /dev/cpuset/cplane/tasks 2>/dev/null
            if [ $? != 0 ]; then
                isdebug echo -n "Cannot move PID $pid: "
                isdebug echo "$(cat /proc/$pid/status | grep ^Name | cut -f2)"
            fi
        fi
    done

    # Disable load balancing on top level (otherwise the child-sets' setting won't take effect.)
    echo 0 > /dev/cpuset/$CPUSET_PREFIX"sched_load_balance"

    # Enable load balancing withing the cplane domain
    echo 1 > /dev/cpuset/cplane/$CPUSET_PREFIX"sched_load_balance"

    # But disallow load balancing within the NOHZ domain
    echo 0 > /dev/cpuset/dplane/$CPUSET_PREFIX"sched_load_balance"

    # Quiesce CPU: i.e. migrate timers/hrtimers away
    echo 1 > /dev/cpuset/dplane/$CPUSET_PREFIX"quiesce"

    # Restart $ISOL_CPUS to migrate all tasks to CPU0
    # Commented-out: as we should get good numbers without this HACK
    # echo 0 > /sys/devices/system/cpu/cpu$ISOL_CPUS/online
    # echo 1 > /sys/devices/system/cpu/cpu$ISOL_CPUS/online

    # Call create_dplane_cpuset for each isolated CPU
    for_each_isol_cpu create_dplane_cpuset
}

# Count total number of interrupts for all isolated CPUs
count_interrupts_on_isol_cpus() {
    temp=($*)
    count=0

    for i in `echo $ISOL_CPUS | sed 's/,/ /g'`; do
        count=$(( $count + ${temp[i]} ))
    done

    echo $count
}

# Scan all interrupts again and find total for isolated-cores
refresh_interrupts() {
    # Get interrupt count for all CPUs
    interrupts=($(total_interrupts "ALL"))

    # Find total count of all interrupts on isol CPUs
    new_count=$(count_interrupts_on_isol_cpus ${interrupts[@]})

    [ $1 ] && isdebug echo "Counts for all CPUs: ${interrupts[@]}, total isol-cpus interrupts: $new_count"
}

# Sense infinite isolation
sense_infinite_isolation() {
    # process interrupts
    refresh_interrupts "print"
    old_count=$new_count

    # Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
    T1="$(date +%s)"

    while [ $new_count -eq $old_count ]
    do
        # process interrupts
        refresh_interrupts

        ps h -C $TASK -o pid > /dev/null
        if [ $? != 0 ]; then
            T2="$(date +%s)"
            T=$(($T2-$T1))

            echo "Quitting. Infinite Isolation detected: No interrupts for last: $T seconds"
            echo "test_case_id:Min-isolation $MIN_ISOLATION secs result:$RESULT measurement:$T units:secs"
            exit
        fi
    done

    # Interrupted, dump interrupts
    isdebug dump_interrupts 1
}

# routine to report CPU isolation time
get_isolation_duration() {
    isdebug echo ""
    isdebug echo ""
    isdebug echo "Capture Isolation time"
    isdebug echo "----------------------"

    isdebug echo "No. of samples requested:" $SAMPLE_COUNT", min isolation required:" $MIN_ISOLATION
    isdebug echo ""

    isdebug dump_interrupts

    # Get time as a UNIX timestamp (seconds elapsed since Jan 1, 1970 0:00 UTC)
    T2="$(date +%s)"

    x=0; AVG=0; MIN=99999999; MAX=0

    while [ $x -lt $SAMPLE_COUNT ]
    do
        let x=x+1

        T1=$T2
        isdebug echo "Start Time in seconds: ${T1}"

        # sometimes there are two or more continuous ticks, skip them by sleeping for 100 ms.
        sleep .1

        # Sense infinite isolation
        sense_infinite_isolation

        T2="$(date +%s)"
        T=$(($T2-$T1))

        isdebug echo "End Time in seconds: ${T2}, time diff: "
        echo "$T seconds"
        isdebug echo ""

        # Calculations to show results
        let AVG=AVG+T

        if [ $T -lt $MIN_ISOLATION -a $RESULT="PASS" ]; then
            RESULT="FAIL"
        fi

        # Record minimum and maximum isolation
        if [ $T -lt $MIN ]; then
            MIN=$T
        fi
        if [ $T -gt $MAX ]; then
            MAX=$T
        fi
    done

    let AVG=AVG/$SAMPLE_COUNT

    isdebug echo "Result:"
    echo "test_case_id:Min-isolation "$MIN_ISOLATION" secs result:"$RESULT" measurement:"$AVG" units:secs"
    echo "Min isolation is: "$MIN", Max isolation is: "$MAX" and Average isolation time is: "$AVG
    isdebug echo ""
}

# Clear/remove all CPUsets, kill all instances of 'stess'
clear_cpusets() {
    isdebug echo ""
    isdebug echo "Started cleaning CPUSETS"
    isdebug echo "------------------------"
    isdebug echo ""

    #
    # Cleanup
    #

    # kill all instances of task
    for i in `ps | grep $TASK | sed 's/^\ *//g' | cut -d' ' -f1`;
    do
        kill -9 $i;
    done

    # Try to move all from cplane back to root
    for pid in `cat /dev/cpuset/cplane/tasks`; do
        if [ -d /proc/$pid ]; then
            echo $pid > /dev/cpuset/tasks 2>/dev/null
            if [ $? != 0 ]; then
                isdebug echo -n "Cannot move PID $pid: "
                isdebug echo "$(cat /proc/$pid/status | grep ^Name | cut -f2)"
            fi
        fi
    done

    # Remove the CPUsets
    for_each_isol_cpu remove_dplane_cpuset

    # delay required b/w cpu* cpusets and dplane cpuset for some reason,
    # other wise we get this: Device or resource busy
    sleep .1

    rmdir /dev/cpuset/cplane
    rmdir /dev/cpuset/dplane
}


# Execution starts from HERE

USAGE="Usage: $0 [-hvq] [-ctfsd args] [-h <help>] [-v <script version>] [-q <quirks: X86_IPI>][-c <Comma separated isol cpulist (default cpu1)>] [-t <Task name for isolation (default stress)>] [-f <Function type options: isolate, duration, clear, all (default all)>] [-s <Number of samples to take (default 1)>] [-d <Min Isolation duration expected in seconds (default 10)>]"

# Run isolation test for $FUNC
run_func()
{
    isdebug echo ""
    isdebug echo "Function type: $FUNC"

    case "$FUNC" in
        "isolate")
        isolate_cpu
        ;;

        "duration")
        get_isolation_duration
        ;;

        "clear")
        clear_cpusets
        ;;

        "nonisol_list")
        update_non_isol_cpus
        ;;

        "all")
        isolate_cpu
        get_isolation_duration
        clear_cpusets
        ;;

        *)
        echo "Invalid [-f] function type"
        ;;
    esac
}

# Parse isol arguments
parse_arguments()
{
    while getopts hvc:t:f:s:d:q: arguments 2>/dev/null
    do
        case $arguments in
            h) # --help
                echo "$USAGE"
                exit 0
                ;;

            v) # --script version
                isdebug echo "$0 Version $SCRIPT_VERSION"
                exit 0
                ;;

            c) # --cpu (comma separated isol cpulist, default cpu1)
                ISOL_CPUS=$OPTARG
                ;;

            t) # --task (task to run, default stress)
                TASK=$OPTARG
                ;;

            f) # --func_type (Function to perform: Isolate, Duration,
                # Clear, Nonisol_list, all. default all)
                FUNC=$OPTARG
                ;;

            s) # --sample_count (no of samples to take, default 1)
                SAMPLE_COUNT=$OPTARG
                ;;

            d) # --duration (min isolation time duration, default 10)
                MIN_ISOLATION=$OPTARG
                ;;

            q) # --quirk
                # Known Quirks:
                # - X86_IPI: Spurious IPI's break isolation

                if [ $OPTARG = X86_IPI ]; then
                    QUIRKS="interrupts|RTR|TLB|MCE|MCP|ERR|MIS"
                    isdebug echo "Enabled Quriks: $OPTARG"
                else
                    echo "Invalid Quirk passed. Valid options: X86_IPI"
                fi
                ;;

            \?) # getopts issues an error message
                echo "$USAGE "
                exit 1
                ;;
        esac
    done
}

# Parse isol arguments
parse_arguments $@

# Run isolation test for requested functionality
run_func
