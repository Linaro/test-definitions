#!/bin/sh
#
# Gator data streaming test for ubuntu
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

. include/sh-test-lib

# Creating a new directory called gator_files under tmp so that it can be uniformly used for both Ubuntu and OE instead of using root for session.xml file
mkdir -p /tmp/gator_files

# Location of XML template and data streaming result folder
xml_template="/tmp/gator_files/session.xml"
data_streaming_result="/tmp/gator_files/linaro-ubuntu-gator-data-streaming.apc"

# Create sample XML file as a template
echo "<?xml version=\"1.0\" encoding=\"US-ASCII\" ?> " > $xml_template
echo "<session version=\"1\" output_path=\"x\" call_stack_unwinding=\"yes\" parse_debug_info=\"yes\" " >> $xml_template
echo "high_resolution=\"no\" buffer_mode=\"streaming\" sample_rate=\"normal\" duration=\"10\" " >> $xml_template
echo "target_host=\"linaro-ubuntu-boards\" target_port=\"8080\"> " >> $xml_template
echo "</session>" >> $xml_template

## Test case definitions
# Check whether session.xml is available
test_session_xml_not_empty() {
    TEST="session_xml_not_empty"

    if [ ! -f $xml_template ]; then
    fail_test "Unable to find $xml_template"
    return 1
    fi

    session_file=`cat $xml_template`
    if [ -z "$session_file" ]; then
        fail_test "Empty template session XML file at $xml_template"
        return 1
    fi

    pass_test
}

# Check the gator data streaming command
test_gator_data_streaming_cmd() {
    TEST="gator_data_streaming_cmd"
    /usr/sbin/gatord -s $xml_template -o $data_streaming_result
    if [ $? -ne 0 ]; then
        fail_test "Run gator data streaming command failed"
        return 1
    fi

    pass_test
}

# Check whether data streaming result is available
test_gator_data_streaming_result() {
    TEST="gator_data_streaming_result"
    if [ ! -d $data_streaming_result ]; then
        fail_test "Gator data streaming result folder doesn't exist"
        return 1
    elif [ ! -f $data_streaming_result/captured.xml ]; then
        fail_test "File captured.xml doesn't exist"
        return 1
    elif [ ! -s $data_streaming_result/captured.xml ]; then
        fail_test "File captured.xml is empty"
        return 1
    fi

    # Print some necessary directory structure information
    ls -la $data_streaming_result

    pass_test
}

# run the tests
test_session_xml_not_empty
test_gator_data_streaming_cmd
test_gator_data_streaming_result

# clean exit so lava-test can trust the results
exit 0
