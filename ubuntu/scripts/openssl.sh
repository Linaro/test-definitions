#!/bin/sh
#
# Openssl test.
#
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
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Author: Amit Khare <amit.khare@linaro.org>
#

test_func(){
    test_cmd=$1
    openssl speed $test_cmd 2>&1|grep "Doing $test_cmd"> /tmp/result.txt
    awk '{printf "%s-%s: %d sec pass\n" , $2, $6, $9/3}' /tmp/result.txt
}
test_func md5
test_func sha1
test_func sha256
test_func sha512
