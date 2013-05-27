# Copyright (C) 2012, Linaro Limited.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# Author: Amit Pundir <amit.pundir@linaro.org>
# Modified-by: Naresh Kamboju <naresh.kamboju@linaro.org> 
#

usage()
{
        echo ""
        echo "usage: $0 [<option> <argument>] .."
        echo "Options: -a [Run all tests]"
        echo "         -b [Run all basic module and switcher tests]"
        echo "         -c [Run all cache-coherency tests]"
        echo "         -d [Run all data-corruption tests]"
        echo "         -i [Run all disk-io tests]"
        echo "         -g [Run all governor tests]"
        echo "         -m [Run all memory tests]"
        echo "         -p [Run all perf tests]"
        echo "         -s [Run only switcher tests]"
        echo "         -v [Run all vfp-ffmpeg tests]"
        echo "         -t <specify the test-id(s)> [Run the specified tests]"
        echo "            [ 1 : cache-coherency-a7]"
        echo "            [ 2 : cache-coherency-a15]"
        echo "            [ 3 : cache-coherency-switching]"
        echo "            [ 4 : data-corruption-a7]"
        echo "            [ 5 : data-corruption-a15]"
        echo "            [ 6 : data-corruption-switching]"
        echo "            [ 7 : disk-io-stress-a7]"
        echo "            [ 8 : disk-io-stress-a15]"
        echo "            [ 9 : disk-io-stress-switching]"
        echo "            [10 : mem-stress-a7]"
        echo "            [11 : mem-stress-a15]"
        echo "            [12 : mem-stress-switching]"
        echo "            [13 : bl-basic-tests]"
        echo "            [14 : switcher-tests]"
        echo "            [15 : vfp-ffmpeg-a7]"
        echo "            [16 : vfp-ffmpeg-a15]"
        echo "            [17 : vfp-ffmpeg-switching]"
        echo "            [18 : interactive-governor-test]"
	echo "            [19 : cache-coherency-simultaneous-thread-switching]"
	echo "            [20 : data-corruption-simultaneous-thread-switching]"
	echo "            [21 : disk-io-stress-simultaneous-thread-switching]"
	echo "            [22 : mem-stress-simultaneous-thread-switching]"
	echo "            [23 : vfp-ffmpeg-simultaneous-thread-switching]"
	echo "            [24 : perf-mem-stress-a7]"
	echo "            [25 : perf-mem-stress-a15]"
	echo "            [26 : perf-mem-stress-switching]"
	echo "            [27 : perf-disk-io-stress-a7]"
	echo "            [28 : perf-disk-io-stress-a15]"
	echo "            [29 : perf-disk-io-stress-switching]"
	echo "       	  [30 : cpu-freq-vs-cluster-freq]"
        echo ""
        exit 1
}

check_kernel_oops()
{
	KERNEL_ERR=`dmesg | grep "Unable to handle kernel "`
	if [ -n "$KERNEL_ERR" ]; then
		echo "Kernel OOPS. Abort!!"
		exit 1
	fi
}

test_insert_module()
{
	echo ""

	ANDROID_MOD_PATH=/system/modules
	UBUNTU_MOD_PATH=/lib/modules/`uname -r`/kernel/drivers/cpufreq
	if [ -d $ANDROID_MOD_PATH ]; then
   		 MOD_LOCATION=$ANDROID_MOD_PATH/arm-bl-cpufreq.ko
	else if [ -d $UBUNTU_MOD_PATH ]; then
    		MOD_LOCATION=$UBUNTU_MOD_PATH/arm-bl-cpufreq.ko
    		ONDEMAND_MOD_LOCATION=$UBUNTU_MOD_PATH/cpufreq_ondemand.ko
	else
    		echo "ERROR: No arm-bl-cpufreq.ko module found"
    		exit 1
		fi
	fi
	CPU_FREQ_KM=`lsmod | grep cpufreq | awk '{print $1}'`
	if [ -z "$CPU_FREQ_KM" ]; then
		if [ -d $ANDROID_MOD_PATH ]; then
	# on Android none of the module is expected to be loaded as default
			echo "" 
		elif [ -d $UBUNTU_MOD_PATH ]; then
	# On Ubuntu below two modules are expected to be loaded as default 
			insmod $MOD_LOCATION
			insmod $ONDEMAND_MOD_LOCATION
		fi
	fi
}


test_remove_module()
{
	echo ""

	ANDROID_MOD_PATH=/system/modules
	UBUNTU_MOD_PATH=/lib/modules/`uname -r`/kernel/drivers/cpufreq

	CPU_FREQ_KM=`lsmod | grep cpufreq | awk '{print $1}'`
	if [ -n "$CPU_FREQ_KM" ]; then
		if [ -d $ANDROID_MOD_PATH ]; then
	# On Android remove module if any loaded 
			rmmod arm_bl_cpufreq > /dev/null 2>&1
		elif [ -d $UBUNTU_MOD_PATH ]; then
	# On Ubuntu remove modules if any loaded
	# /etc/init.d/ondemand will load cpufreq_ondemand after
	# 60 sec from the boot time. if we remove modules right
	# away. cpufreq_ondemand will load again which we do want.
	# we will wait here for 90 sec and remove modules
	# I know this is ugly hack, but left no other option.
	# TODO: if /etc/init.d/ondemand is not exists in distro
	# remove sleep
			sleep 90
			echo "list of modules present"
			lsmod
			echo "remove modules arm_bl_cpufreq & cpufreq_ondemand"
			rmmod arm_bl_cpufreq > /dev/null  2>&1
			rmmod cpufreq_ondemand > /dev/null  2>&1
		fi
	fi
}

test_remove_android_module()
{
	echo ""

	ANDROID_MOD_PATH=/system/modules

	CPU_FREQ_KM=`lsmod | grep cpufreq | awk '{print $1}'`
	if [ -n "$CPU_FREQ_KM" ]; then
		if [ -d $ANDROID_MOD_PATH ]; then
	# On Android remove module if any loaded before exit 
			rmmod arm_bl_cpufreq > /dev/null  2>&1
		fi
	fi
}

test_init() 
{
	# Remove the module(s). 
	# Let Each Test case will insert whenever it is required
	echo ""
	echo "test init"
	test_remove_module
}

test_cleanup()
{
	echo "test cleanup"
	# To make default Env Insert modules back on Ubuntu
	test_insert_module
	# To make default Env Remove module from Android
	test_remove_android_module
	# ensure every thing is perfect
	check_kernel_oops
	echo "cleanup done"
}

trap_handler() 
{
	echo "Abnormal Exit"
	test_cleanup
	echo "cleanup done"
	exit 1
}

get_no_of_cpu()
{
	TOTAL_ACTIVE_CPUS=`cat /proc/cpuinfo | grep processor | wc -l`
	echo ""
	echo "Number of CPUs successfully brought up during boot = $TOTAL_ACTIVE_CPUS"
	echo ""
	#TODO
	# For TC2
	if [ "$MODEL" = "V2P-CA15_CA7" ]; then
		EACH_CPU="-c 0 -c 1"
		NO_OF_CPUS="-n 0 1"
	# For RTSM
	else if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
		EACH_CPU="-c 0 -c 1 -c 2 -c 3"
		NO_OF_CPUS="-n 0 1 2 3"
	else
		echo " Unknown architecture"
		echo " Please add your architecture or model"
		echo " Provide number of cpu info"
		exit 1
	fi
	fi
}

set_userspce_governor()
{
	GOVERNOR="userspace"
	for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
	do echo $GOVERNOR > $file
	done
	sleep 5;
}

run_test()
{
	TOTAL_TESTS=$((TOTAL_TESTS+1))
	echo ""
	echo "Running $1 .."
	$2
	ERR_CODE=$?
	if [ $ERR_CODE -ne 0 ]; then
		echo "$1 : FAIL"
		FAIL_TESTS=$((FAIL_TESTS+1))
	else
		echo "$1 : PASS"
		PASS_TESTS=$((PASS_TESTS+1))
	fi
}

run_all_cache_coherency_tests()
{
	echo ""
	echo "Running all cache-coherency tests .."
	run_test cache-coherency-a7 "cache-coherency-switcher.sh -f little $EACH_CPU"
	run_test cache-coherency-a15 "cache-coherency-switcher.sh -f big $EACH_CPU"
	run_test cache-coherency-switching "cache-coherency-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test cache-coherency-simultaneous-thread-switching "cache-coherency-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
}

run_all_data_corruption_tests()
{
	echo ""
	echo "Running all data-corruption tests .."
	run_test data-corruption-a7 "data-corruption-switcher.sh -f little $EACH_CPU"
	run_test data-corruption-a15 "data-corruption-switcher.sh -f big $EACH_CPU"
	run_test data-corruption-switching "data-corruption-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test data-corruption-simultaneous-thread-switching "data-corruption-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
}

run_all_disk_io_tests()
{
	echo ""
	echo "Running all disk-io tests .."
	run_test disk-io-stress-a7 "disk-io-stress-switcher.sh -f little $EACH_CPU"
	run_test disk-io-stress-a15 "disk-io-stress-switcher.sh -f big $EACH_CPU"
	run_test disk-io-stress-switching "disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test disk-io-stress-simultaneous-thread-switching "disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
}

run_all_memory_tests()
{
	echo ""
	echo "Running all memory tests .."
	run_test mem-stress-a7 "mem-stress-switcher.sh -f little $EACH_CPU"
	run_test mem-stress-a15 "mem-stress-switcher.sh -f big $EACH_CPU"
	run_test mem-stress-switching "mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test mem-stress-simultaneous-thread-switching "mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
}

run_all_switching_tests()
{
	echo ""
	echo "Running all switching tests .."
	run_test mem-stress-switching "mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test data-corruption-switching "data-corruption-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test disk-io-stress-switching "disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test cache-coherency-switching "cache-coherency-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test vfp-ffmpeg-switching "vfp-ffmpeg-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test cache-coherency-simultaneous-thread-switching "cache-coherency-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
	run_test data-corruption-simultaneous-thread-switching "data-corruption-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
	run_test disk-io-stress-simultaneous-thread-switching "disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
	run_test mem-stress-simultaneous-thread-switching "mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
	run_test vfp-ffmpeg-simultaneous-thread-switching "vfp-ffmpeg-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
	run_test perf-mem-stress-switching "perf-mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test perf-disk-io-stress-switching "perf-disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
}

run_all_vfp_ffmpeg_tests()
{
	echo ""
	echo "Running all vfp-ffmpeg tests .."
	run_test vfp-ffmpeg-a7 "vfp-ffmpeg-switcher.sh -f little $EACH_CPU"
	run_test vfp-ffmpeg-a15 "vfp-ffmpeg-switcher.sh -f big $EACH_CPU"
	run_test vfp-ffmpeg-switching "vfp-ffmpeg-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test vfp-ffmpeg-simultaneous-thread-switching "vfp-ffmpeg-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
}

run_all_basic_module_switcher_tests()
{
	echo ""
	echo "Running basic module and switcher tests .."
	run_test bl-basic-tests "run-bl-basic-tests.sh"
	run_test switcher-tests "switcher-tests.sh"
	# This test intended for TC2 only
	if [ "$MODEL" = "V2P-CA15_CA7" ]; then
		run_test cpu-freq-vs-cluster-freq "cpu_freq_vs_cluster_freq.sh"
	fi
}

run_all_governor_tests()
{
	echo ""
	echo "Running governor tests .."
	run_test interactive-governor-tests "interactive-governor-test.sh"
}

run_all_perf_tests()
{
	echo ""
	echo "Running perf tests .."
	run_test perf-mem-stress-a7 "perf-mem-stress-switcher.sh -f little $EACH_CPU -a7 1"
	run_test perf-mem-stress-a15 "perf-mem-stress-switcher.sh -f big $EACH_CPU -a15 1"
	run_test perf-mem-stress-switching "perf-mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
	run_test perf-disk-io-stress-a7 "perf-disk-io-stress-switcher.sh -f little $EACH_CPU -a7 1"
	run_test perf-disk-io-stress-a15 "perf-disk-io-stress-switcher.sh -f big $EACH_CPU -a15 1"
	run_test perf-disk-io-stress-switching "perf-disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"

}

run_all_tests()
{
	echo ""
	echo "Running all tests .."
	run_all_basic_module_switcher_tests
	run_all_memory_tests
	run_all_disk_io_tests
	run_all_data_corruption_tests
	run_all_cache_coherency_tests
	run_all_vfp_ffmpeg_tests
	run_all_perf_tests
	run_all_governor_tests
}

summary()
{
	echo ""
	echo "Summary .."
	echo "Total Tests = $TOTAL_TESTS"
	echo "Tests Passed = $PASS_TESTS"
	echo "Tests Failed = $FAIL_TESTS"
}

if [ -z "$1" ]; then
	usage
fi

TOTAL_TESTS=0
PASS_TESTS=0
FAIL_TESTS=0

MODEL=`cat /proc/device-tree/model`

# I feel below three signal are good enough to handle
# trap trap_handler SIGINT SIGTERM SIGTSTP
trap trap_handler 2 15 20 
# get no of cpus online
get_no_of_cpu

# For TC2
if [ "$MODEL" = "V2P-CA15_CA7" ]; then
	# Test setup before real test start 
	set_userspce_governor
fi
# For RTSM
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	# Test setup before real test start 
	test_init
fi

while [ "$1" ]; do
	case "$1" in
	-a|--all)
		run_all_tests
		;;
	-b|--basic-tests)
		run_all_basic_module_switcher_tests
		;;
	-c|--cache-coherency)
		run_all_cache_coherency_tests
		;;
        -d|--data-corruption)
		run_all_data_corruption_tests
                ;;
	-i|--disk-io)
		run_all_disk_io_tests
		;;
	-g|--governor-test)
		run_all_governor_tests
		;;
	-m|--memory)
		run_all_memory_tests
		;;
	-p|--perf)
		run_all_perf_tests
		;;
        -s|--switching)
		run_all_switching_tests
                ;;
        -v|--vfp-ffmpeg)
        	run_all_vfp_ffmpeg_tests
                ;;
        -t|--test-id)
		if [ -z "$2" ]; then
			echo ""
			echo "Error: Specify the test-id(s) to run!!"
			echo "       [ 1 : cache-coherency-a7]"
			echo "       [ 2 : cache-coherency-a15]"
			echo "       [ 3 : cache-coherency-switching]"
			echo "       [ 4 : data-corruption-a7]"
			echo "       [ 5 : data-corruption-a15]"
			echo "       [ 6 : data-corruption-switching]"
			echo "       [ 7 : disk-io-stress-a7]"
			echo "       [ 8 : disk-io-stress-a15]"
			echo "       [ 9 : disk-io-stress-switching]"
			echo "       [10 : mem-stress-a7]"
			echo "       [11 : mem-stress-a15]"
			echo "       [12 : mem-stress-switching]"
			echo "       [13 : bl-basic-tests]"
			echo "       [14 : switcher-tests]"
			echo "       [15 : vfp-ffmpeg-a7]"
        		echo "       [16 : vfp-ffmpeg-a15]"
        		echo "       [17 : vfp-ffmpeg-switching]"
        		echo "       [18 : interactive-governor-test]"
			echo "       [19 : cache-coherency-simultaneous-thread-switching]"
			echo "       [20 : data-corruption-simultaneous-thread-switching]"
			echo "       [21 : disk-io-stress-simultaneous-thread-switching]"
			echo "       [22 : mem-stress-simultaneous-thread-switching]"
			echo "       [23 : vfp-ffmpeg-simultaneous-thread-switching]"
			echo "       [24 : perf-mem-stress-a7]"
			echo "       [25 : perf-mem-stress-a15]"
			echo "       [26 : perf-mem-stress-switching]"
			echo "       [27 : perf-disk-io-stress-a7]"
			echo "       [28 : perf-disk-io-stress-a15]"
			echo "       [29 : perf-disk-io-stress-switching]"
			echo "       [30 : cpu-freq-vs-cluster-freq]"
        		echo ""
			exit 1;
		fi

		while [ "$2" ]; do
			case "$2" in
			1)
				run_test cache-coherency-a7 "cache-coherency-switcher.sh -f little $EACH_CPU"
				;;
			2)
				run_test cache-coherency-a15 "cache-coherency-switcher.sh -f big $EACH_CPU"
				;;
			3)
				run_test cache-coherency-switching "cache-coherency-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			4)
				run_test data-corruption-a7 "data-corruption-switcher.sh -f little $EACH_CPU"
				;;
			5)
				run_test data-corruption-a15 "data-corruption-switcher.sh -f big $EACH_CPU"
				;;
			6)
				run_test data-corruption-switching "data-corruption-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			7)
				run_test disk-io-stress-a7 "disk-io-stress-switcher.sh -f little $EACH_CPU"
				;;
			8)
				run_test disk-io-stress-a15 "disk-io-stress-switcher.sh -f big $EACH_CPU"
				;;
			9)
				run_test disk-io-stress-switching "disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			10)
				run_test mem-stress-a7 "mem-stress-switcher.sh -f little $EACH_CPU"
				;;
			11)
				run_test mem-stress-a15 "mem-stress-switcher.sh -f big $EACH_CPU"
				;;
			12)
				run_test mem-stress-switching "mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			13)
				run_test bl-basic-tests "run-bl-basic-tests.sh"
				;;
			14)
				run_test switcher-tests "switcher-tests.sh"
				;;
			15)
				run_test vfp-ffmpeg-a7 "vfp-ffmpeg-switcher.sh -f little $EACH_CPU"
				;;
			16)
				run_test vfp-ffmpeg-a15 "vfp-ffmpeg-switcher.sh -f big $EACH_CPU"
				;;
			17)
				run_test vfp-ffmpeg-switching "vfp-ffmpeg-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			18)
				run_test interactive-governor-tests "interactive-governor-test.sh"
				;;
			19)
				run_test cache-coherency-simultaneous-thread-switching "cache-coherency-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
				;;
			20)
				run_test data-corruption-simultaneous-thread-switching "data-corruption-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
				;;
			21)
				run_test disk-io-stress-simultaneous-thread-switching "disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
				;;
			22)
				run_test mem-stress-simultaneous-thread-switching "mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
				;;
			23)
				run_test vfp-ffmpeg-simultaneous-thread-switching "vfp-ffmpeg-switcher.sh -f big -c 0 $NO_OF_CPUS -s 100 -S"
				;;
			24)
				run_test perf-mem-stress-a7 "perf-mem-stress-switcher.sh -f little $EACH_CPU -a7 1"
				;;
			25)
				run_test perf-mem-stress-a15 "perf-mem-stress-switcher.sh -f big $EACH_CPU -a15 1"
				;;
			26)
				run_test perf-mem-stress-switching "perf-mem-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			27)
				run_test perf-disk-io-stress-a7 "perf-disk-io-stress-switcher.sh -f little $EACH_CPU -a7 1"
				;;
			28)
				run_test perf-disk-io-stress-a15 "perf-disk-io-stress-switcher.sh -f big $EACH_CPU -a15 1"
				;;
			29)
				run_test perf-disk-io-stress-switching "perf-disk-io-stress-switcher.sh -f big -c 0 $NO_OF_CPUS -r 100 -l 1000"
				;;
			30)
				run_test cpu-freq-vs-cluster-freq "cpu_freq_vs_cluster_freq.sh"
				;;

			*)
				echo ""
				echo "Error: Unknown test-id \"$2\""
				echo "       Specify the correct test(s) to run!!"
				echo "       [ 1 : cache-coherency-a7]"
				echo "       [ 2 : cache-coherency-a15]"
				echo "       [ 3 : cache-coherency-switching]"
				echo "       [ 4 : data-corruption-a7]"
				echo "       [ 5 : data-corruption-a15]"
				echo "       [ 6 : data-corruption-switching]"
				echo "       [ 7 : disk-io-stress-a7]"
				echo "       [ 8 : disk-io-stress-a15]"
				echo "       [ 9 : disk-io-stress-switching]"
				echo "       [10 : mem-stress-a7]"
				echo "       [11 : mem-stress-a15]"
				echo "       [12 : mem-stress-switching]"
				echo "       [13 : bl-basic-tests]"
				echo "       [14 : switcher-tests]"
				echo "       [15 : vfp-ffmpeg-a7]"
        			echo "       [16 : vfp-ffmpeg-a15]"
        			echo "       [17 : vfp-ffmpeg-switching]"
        			echo "       [18 : interactive-governor-test]"
				echo "       [19 : cache-coherency-simultaneous-thread-switching]"
				echo "       [20 : data-corruption-simultaneous-thread-switching]"
				echo "       [21 : disk-io-stress-simultaneous-thread-switching]"
				echo "       [22 : mem-stress-simultaneous-thread-switching]"
				echo "       [23 : vfp-ffmpeg-simultaneous-thread-switching]"
				echo "       [24 : perf-mem-stress-a7]"
				echo "       [25 : perf-mem-stress-a15]"
				echo "       [26 : perf-mem-stress-switching]"
				echo "       [27 : perf-disk-io-stress-a7]"
				echo "       [28 : perf-disk-io-stress-a15]"
				echo "       [29 : perf-disk-io-stress-switching]"
				echo "       [30 : cpu-freq-vs-cluster-freq]"
				echo ""
				exit 1;
				;;
			esac
			shift;
		done
                ;;
	-h | --help | *)
		usage
		;;
	esac
	shift;
done

# For RTSM
if [ "$MODEL" = "RTSM_VE_CortexA15x4-A7x4" ]; then
	# Test cleanup before exit
	test_cleanup
fi

summary

exit 0
