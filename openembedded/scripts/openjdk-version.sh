#!/bin/bash
#
# OpenJDK execution and version test.
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
# Author: Andrew McDermott <andrew.mcdermott@linaro.org>
#

if [ $# -eq 0 ]; then
    echo "usage: $0 <version>"
    exit 1
fi

version=$1

rm -f JavaVersion.java JavaVersion.class

echo '
class JavaVersion {
	public static void main(String[] args) {
		System.out.println(System.getProperty("java.version"));
	}
}' > JavaVersion.java

javac JavaVersion.java

if [ $? -ne 0 ]; then
	echo "openjdk-version: fail"
	exit 1
fi

actual_version=`java JavaVersion`

echo "actual   version: $actual_version"
echo "expected version: $version"

if [ $? -eq 0 ]; then
    if [[ "$actual_version" =~ "$version" ]]; then
	echo "openjdk-version: pass"
	exit 0
    else
	echo "openjdk-version: fail"
	exit 1
    fi
else
    echo "openjdk-version: fail"
    exit 1
fi
