#!/bin/bash

dmidecode > dmidecode.txt

if grep -E 'SMBIOS [0-9]+.[0-9] present.' dmidecode.txt
then
	lava-test-case user-space-dmidecode-smbios-present --result pass
else
	lava-test-case user-space-dmidecode-smbios-present --result fail
fi

if grep 'BIOS Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-bios-has-info --result pass
else
	lava-test-case user-space-dmidecode-bios-has-info --result fail
fi

if grep 'System Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-system-has-info --result pass
else
	lava-test-case user-space-dmidecode-system-has-info --result fail
fi

if grep 'Base Board Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-baseboard-has-info --result pass
else
	lava-test-case user-space-dmidecode-baseboard-has-info --result fail
fi

if grep 'Chassis Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-chassis-has-info --result pass
else
	lava-test-case user-space-dmidecode-chassis-has-info --result fail
fi

if grep 'Processor Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-processor-has-info --result pass
else
	lava-test-case user-space-dmidecode-processor-has-info --result fail
fi

if grep 'Memory Device' dmidecode.txt
then
	lava-test-case user-space-dmidecode-memory-has-info --result pass
else
	lava-test-case user-space-dmidecode-memory-has-info --result fail
fi

if grep 'Cache Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-cache-has-info --result pass
else
	lava-test-case user-space-dmidecode-cache-has-info --result fail
fi

if grep 'Connector Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-connector-has-info --result pass
else
	lava-test-case user-space-dmidecode-connector-has-info --result fail
fi

if grep 'System Slot Information' dmidecode.txt
then
	lava-test-case user-space-dmidecode-slot-has-info --result pass
else
	lava-test-case user-space-dmidecode-slot-has-info --result fail
fi

cat dmidecode.txt
rm dmidecode.txt
