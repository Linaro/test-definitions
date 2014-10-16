#!/system/bin/sh
#
# SD MMC test cases for Linaro Android
#
# Copyright (C) 2010 - 2014, Linaro Limited.
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

check_return_fail() {
    if [ $? -ne 0 ]; then
        fail_test "$1"
        return 0
    else
        return 1
    fi
}

fail_test() {
    local reason=$1
    echo "${TEST}: FAIL - ${reason}"
}

pass_test() {
    echo "${TEST}: PASS"
}

## Test case definitions
# Check if EXTERNAL_STORAGE is available
test_has_variable_external_storage() {
    TEST="has_variable_external_storage"

    # Add 1 minute sleep time to avoid SD card partition is unavailable during the system boot
    sleep 60

    if [ -z "$EXTERNAL_STORAGE" ]; then
        fail_test "The value of EXTERNAL_STORAGE is empty"
        return 1
    fi

    echo "The value of EXTERNAL_STORAGE is $EXTERNAL_STORAGE"

    pass_test
}

# Print the output of "df" command
test_print_df_output() {
    TEST="print_df_output"

    df_return=`df`
    if [ $? -ne 0 ]; then
        fail_test "Run df command failed"
        return 1
    fi

    if [ -z "$df_return" ]; then
        fail_test "The return value of df command is empty"
        return 1
    else
        echo "$df_return"
    fi

    pass_test
}

# Write to SD card partition
test_write_on_sd_card() {
    TEST="write_on_sd_card"

    if [ ! -d "$EXTERNAL_STORAGE" ]; then
        fail_test "Unable to find $EXTERNAL_STORAGE"
        return 1
    fi

    written_message="abcdefghijklmn"
    echo $written_message > $EXTERNAL_STORAGE/sd-mmc-test.txt

    if [ ! -f "$EXTERNAL_STORAGE/sd-mmc-test.txt" ]; then
        fail_test "Failed to write to external storage $EXTERNAL_STORAGE"
        return 1
    fi

    file_content=`cat $EXTERNAL_STORAGE/sd-mmc-test.txt`

    if [ "$file_content" != "$written_message" ]; then
        fail_test "Writing test on SD card failed, original string doesn't match the result"
        return 1
    fi

    echo "The content of SD MMC test file is: $file_content"

    pass_test
}

# run the tests
test_has_variable_external_storage
test_print_df_output
test_write_on_sd_card

# clean exit so lava-test can trust the results
exit 0
