#!/bin/sh

. ../../lib/sh-test-lib

start_test() {
	echo "=============================================="
	echo "$1"
	echo "=============================================="
	dmesg_capture_start
}

result() {
	result=$1
	shift

	dmesg_capture_result
	if [ "$result" = 'FAIL' ];then
		report_fail "$1"
		return
	fi
	if [ "$result" = 'SKIP' ];then
		report_skip "$1"
		return
	fi
	if [ "$result" -eq 127 ];then
		report_skip "$1"
		return
	fi
	if [ "$result" -eq 0 ];then
		report_pass "$1"
	else
		report_fail "$1"
	fi
}

OUTPUT="$(pwd)/output"
mkdir -p "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"

# for all crypto algorithm to load by testing them via the tcrypt module
start_test "Test kernel crypto via the tcrypt module"
modprobe tcrypt 2> "$OUTPUT_DIR/tcrypt.err"
RET=$?
cat "$OUTPUT_DIR/tcrypt.err"
if [ $RET -eq 0 ];then
	# should never happen in classic testing (non-FIPS)
	# TODO test for FIPS mode
	echo "WARN: should not happen"
	result 0 "crypto-tcrypt"
else
	if [ $RET -eq 1 ];then
		# normal case, check error message
		# by default tcrypt return EAGAIN in non-FIPS mode
		grep -q 'Resource temporarily unavailable' "$OUTPUT_DIR/tcrypt.err"
		RET=$?
		if [ $RET -eq 0 ];then
			echo "DEBUG: This is a real tcrypt success in non-FIPS mode"
			result 0 "crypto-tcrypt"
		else
			grep -q 'module tcrypt not found' "$OUTPUT_DIR/tcrypt.err"
			RET=$?
			if [ $RET -eq 0 ];then
				result "SKIP" "crypto-tcrypt"
			else
				result 0 "crypto-tcrypt"
			fi
		fi
	else
		echo "DEBUG: unknow return code $RET"
		result $RET "crypto-tcrypt"
	fi
fi

# check for some result
# tcrypt generate error -2 for non-present algs
start_test "Verify crypto errors"
dmesg | grep -vE 'is unavailable$|[[:space:]]-2$|This is intended for developer use only|alg: No test for stdrng' |grep alg:
RET=$?
if [ $RET -eq 0 ];then
	result 1 "crypto-error-log"
else
	result 0 "crypto-error-log"
fi


# verify each algorithm if thet pass or fail selftests
while read -r line
do
	SECTION=$(echo "$line" |cut -d' ' -f1)
	case $SECTION in
	driver)
		DRIVER=$(echo "$line" | sed 's,.*[[:space:]],,' | sed 's,[()],_',g)
	;;
	type)
		TYPE=$(echo "$line" | sed 's,.*[[:space:]],,')
	;;
	selftest)
		SELFTEST=$(echo "$line" | sed 's,.*[[:space:]],,')
	;;
	"")
		if [ "$SELFTEST" = 'passed' ];then
			report_pass "$TYPE-$DRIVER"
		else
			report_fail "$TYPE-$DRIVER"
		fi
	;;
	*)
	;;
	esac
done < /proc/crypto
