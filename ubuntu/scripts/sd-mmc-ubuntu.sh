#!/bin/bash
#
# SD MMC test for ubuntu
#
# Copyright (C) 2013, Linaro Limited.
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
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Botao Sun <botao.sun@linaro.org>

function check_return_fail() {
    if [ $? -ne 0 ]; then
        fail_test "$1"
        return 0
    else
        return 1
    fi
}

function fail_test() {
    local reason=$1
    echo "${TEST}: FAIL - ${reason}"
}

function pass_test() {
    echo "${TEST}: PASS"
}

keyword="I/O error"

## Test case definitions
# Check whether I/O errors show up in dmesg output
test_sd_mmc_IO_errors() {
    TEST="sd_mmc_IO_errors"

    dmesg | grep "$keyword"
    if [ $? -eq 0 ]; then
        fail_test "I/O error found, SD MMC test failed"
        return 1
    fi

    pass_test
}

# run the tests
test_sd_mmc_IO_errors

# clean exit so lava-test can trust the results
exit 0