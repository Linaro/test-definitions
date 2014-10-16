#!/system/bin/sh
#
# Gator data streaming test for Linaro Android
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

check_root() {
    if [ `whoami` = "root" ]; then
        return 0
    else
        return 1
    fi
}

# Create sample XML file as a template
echo "<?xml version=\"1.0\" encoding=\"US-ASCII\" ?> " > $EXTERNAL_STORAGE/session.xml
echo "<session version=\"1\" output_path=\"x\" call_stack_unwinding=\"yes\" parse_debug_info=\"yes\" " >> $EXTERNAL_STORAGE/session.xml
echo "high_resolution=\"no\" buffer_mode=\"streaming\" sample_rate=\"normal\" duration=\"10\" " >> $EXTERNAL_STORAGE/session.xml
echo "target_host=\"linaro-android-boards\" target_port=\"8080\"> " >> $EXTERNAL_STORAGE/session.xml
echo "</session>" >> $EXTERNAL_STORAGE/session.xml

## Test case definitions

# Check whether session.xml is available
test_session_xml_not_empty() {
    TEST="session_xml_not_empty"

    if [ ! -f $EXTERNAL_STORAGE/session.xml ]; then
    fail_test "Unable to find $EXTERNAL_STORAGE/session.xml"
    return 1
    fi

    session_file=`cat $EXTERNAL_STORAGE/session.xml`
    if [ -z "$session_file" ]; then
        fail_test "Empty template session XML file at $EXTERNAL_STORAGE/session.xml"
        return 1
    fi

    pass_test
}

# Check the gator data streaming command
test_gator_data_streaming_cmd() {
    TEST="gator_data_streaming_cmd"
    /system/bin/gatord -s $EXTERNAL_STORAGE/session.xml -o $EXTERNAL_STORAGE/linaro-android-gator-data-streaming.apc
    if [ $? -ne 0 ]; then
        fail_test "Run gator data streaming command failed"
        return 1
    fi

    pass_test
}

# Check whether data streaming result is available
test_gator_data_streaming_result() {
    TEST="gator_data_streaming_result"
    if [ ! -d $EXTERNAL_STORAGE/linaro-android-gator-data-streaming.apc ]; then
        fail_test "Gator data streaming result folder doesn't exist"
        return 1
    elif [ ! -f $EXTERNAL_STORAGE/linaro-android-gator-data-streaming.apc/captured.xml ]; then
        fail_test "File captured.xml doesn't exist"
        return 1
    elif [ ! -s $EXTERNAL_STORAGE/linaro-android-gator-data-streaming.apc/captured.xml ]; then
        fail_test "File captured.xml is empty"
        return 1
    fi

    pass_test
}

# run the tests
test_session_xml_not_empty
test_gator_data_streaming_cmd
test_gator_data_streaming_result

# clean exit so lava-test can trust the results
exit 0
