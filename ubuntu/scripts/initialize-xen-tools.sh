#! /bin/bash
#
# Xen script to initialize the host and check if everything is okay
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
# Author: Julien Grall <julien.grall@linaro.org>
#

dir=`dirname "$0"`
root="$dir/../.."

source "$dir/include/sh-test-lib"

set -x

# check we're root
if ! check_root; then
    error_msg "Please run the test case as root"
fi

# Create console log directory
mkdir -p /var/log/xen/console

# Override default configuration for xencommons
cp "$root/files/xencommons" /etc/default/xencommons

# Start xen daemon
/etc/init.d/xencommons start

# Test case: check that xl is running correctly
TEST="xl_is_running"
xl list

if [ $? -ne 0 ]; then
    fail_test "Xen tools daemon is not running?"
    exit 1
fi
pass_test

# clean exit so lava-test can trust the results
exit 0
