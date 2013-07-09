#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
#
# Copyright (C) 2011, Linaro Limited.
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
# Contributors:
#     Daniel Lezcano <daniel.lezcano@linaro.org> (IBM Corporation)
#       - initial API and implementation
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#cpuidle_03

source ../include/functions.sh

CPUIDLE_KILLER=./cpuidle_killer

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

restore_cpus() {
    for_each_cpu set_online
}

check_cpuidle_kill() {

    if [ "$1" = "cpu0" ]; then
	log_skip "skipping cpu0"
	return 0
    fi

    set_offline $1
    check "cpuidle program runs successfully (120 secs)" "./$CPUIDLE_KILLER"
}

if [ $(id -u) != 0 ]; then
    log_skip "run as non-root"
    exit 0
fi

trap "restore_cpus; sigtrap" SIGHUP SIGINT SIGTERM

for_each_cpu check_cpuidle_kill
restore_cpus
test_status_show
