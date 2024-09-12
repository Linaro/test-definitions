#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2024 Linaro Ltd.

# shellcheck disable=SC1091
. ../../lib/sh-test-lib
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

! check_root && error_msg "This script must be run as root"
create_out_dir "${OUTPUT}"
info_msg "Output directory: ${OUTPUT}"

# CONFIG_USB_GADGET=y
# CONFIG_USB_CONFIGFS=y
# CONFIG_USB_DUMMY_HCD=m
# CONFIG_USB_F_MASS_STORAGE=m

run_test() {
    local input="${1}"
    eval "${input}"
    local ret=$?
    # slugify
    local output
    output="$(echo "${input}" | sed 's|[-/> =]|_|g')"
    if [ ${ret} -eq 0 ]; then
        report_pass "${output}"
    else
        report_fail "${output}"
    fi
}

run_test "modprobe dummy_hcd"
#Setup USB Gadget in ConfigFS
mkdir /sys/kernel/config/usb_gadget/g1
cd /sys/kernel/config/usb_gadget/g1 || exit
echo 0x1d6b > idVendor    # Linux Foundation
echo 0x0104 > idProduct   # Multifunction Composite Gadget
mkdir strings/0x409
echo "0123456789" > strings/0x409/serialnumber
echo "My Gadget" > strings/0x409/manufacturer
echo "Test Device" > strings/0x409/product

run_test "dd bs=1M count=16 if=/dev/zero of=/tmp/lun0.img"

# Create function and configure endpoint (e.g., mass storage, serial)
mkdir -p functions/mass_storage.0

run_test "echo /tmp/lun0.img > functions/mass_storage.0/lun.0/file"

# Bind the gadget to the virtual controller
mkdir configs/c.1
ln -s functions/mass_storage.0 configs/c.1/
run_test "echo dummy_udc.0 > UDC"
cd - || exit
