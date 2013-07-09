#!/bin/bash
#
# PM-QA validation test suite for the power management on Linux
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
# Contributors:
#     Hongbo ZHANG <hongbo.zhang@linaro.org> (ST-Ericsson Corporation)
#       - initial API and implementation
#

# URL : https://wiki.linaro.org/WorkingGroups/PowerManagement/Doc/QA/Scripts#suspend_05


source ../include/functions.sh
source ../include/suspend_functions.sh

args_power_sleep=60

if [ "$suspend_power" -eq 0 ]; then
	log_skip "battery consumption test while suspend"
	exit 0
fi

if [ ! -d /proc/acpi/battery/ ]; then
	log_skip "acpi interface is not there"
	exit 0
fi

battery_count=`battery_count`
if [ "$battery_count" -eq 0 ]; then
	log_skip "no BATTERY detected for power test"
else
	save_timer_sleep="$timer_sleep"
	let timer_sleep="$args_power_sleep"

	ac_required 0
	phase

	# get start values
	date_before=`date +%s`
	bat_before=`battery_capacity`

	# Suspend
	check "battery drain during suspend" suspend_system "mem"
 	if [ $? -ne 0 ]; then
		cat "$LOGFILE" 1>&2
	fi

	# get end values
	date_after=`date +%s`
	bat_after=`battery_capacity`

	# do the calculations 
	let consumed="$bat_before - $bat_after"
	let elapsed="$date_after - $date_before"
	let usage="($consumed * 60*60) / $elapsed"

	# output the results
	ECHO "before: $bat_before mWh"
	ECHO "after: $bat_after mWh"
	ECHO "consumed: $consumed mW"
	ECHO "sleep seconds: $elapsed sec"
	ECHO "overall usage: $usage mW"

	report_battery="$usage mW"

	if [ $elapsed -lt 600 ]
	then
		ECHO "WARNING: the suspend was less than 10 minutes"
		ECHO "         to get reliable numbers increase the sleep time"
		report_battery="$report_battery (unreliable)"
	fi

	timer_sleep="$save_timer_sleep"
fi

restore_trace
test_status_show
rm -f "$LOGFILE"
