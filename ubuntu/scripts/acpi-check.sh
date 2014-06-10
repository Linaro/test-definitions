#! /bin/sh

DSDTPASS=

echo -n "Testing presence of /sys/firmware/acpi: "
if [ -d /sys/firmware/acpi ]; then
	echo PASS
else
	echo FAIL
fi

echo -n "Testing presence of /sys/firmware/acpi/tables/DSDT: "
if [ -f /sys/firmware/acpi/tables/DSDT ]; then
	echo PASS
	DSDTPASS=pass
else
	echo FAIL
fi

echo -n "Can decompile DSDT: "
if [ -x /usr/bin/iasl -a -n "$DSDTPASS" ]; then
	cp /sys/firmware/acpi/tables/DSDT /tmp/
	ERROR=`/usr/bin/iasl -d /tmp/DSDT 2>&1 | grep DSDT.dsl`
	if [ -n "$ERROR" ]; then
		echo PASS
	else
		echo FAIL
	fi
	rm /tmp/DSDT /tmp/DSDT.dsl
else
	echo SKIP
fi

