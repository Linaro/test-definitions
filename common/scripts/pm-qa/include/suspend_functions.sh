#!/bin/bash
#
# Script to automate suspend / resume
#
# Copyright (C) 2008-2009 Canonical Ltd.
#
# Authors:
#  Michael Frey <michael.frey@canonical.com>
#  Andy Whitcroft <apw@canonical.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 2,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

#
# Script to automate suspend / resume
#
# We set a RTC alarm that wakes the system back up and then sleep
# for  seconds before we go back to sleep.
#
# Changelog:
#
# Version for Linaro PM-QA:
#  - this script is edited and integrated into Linaro PM-QA
#  - hongbo.zhang@linaro.org, March, 2012
#


LOGDIR='/var/lib/pm-utils'
LOGFILE="$LOGDIR/stress.log"

# Options Config
dry=0
auto=1
pm_trace=1
timer_sleep=20

# root is needed to fiddle with the clock and use the rtc wakeups.
if [ $(id -u) != 0 ]; then
	log_skip "run as non-root"
	exit 0
fi

# Ensure the log directory exists.
mkdir -p "$LOGDIR"

setup_wakeup_timer ()
{
	timeout="$1"

	# Request wakeup from the RTC or ACPI alarm timers.  Set the timeout
	# at 'now' + $timeout seconds.
	ctl='/sys/class/rtc/rtc0/wakealarm'
	if [ -f "$ctl" ]; then
		# Cancel any outstanding timers.
		echo "0" >"$ctl"
		# rtcN/wakealarm can use relative time in seconds
		echo "+$timeout" >"$ctl"
		return 0
	fi
	ctl='/proc/acpi/alarm'
	if [ -f "$ctl" ]; then
		echo `date '+%F %H:%M:%S' -d '+ '$timeout' seconds'` >"$ctl"
		return 0
	fi

	echo "no method to awaken machine automatically" 1>&2
	exit 1
}

suspend_system ()
{
	if [ "$dry" -eq 1 ]; then
		echo "DRY-RUN: suspend machine for $timer_sleep"
		sleep 1
		return
	fi

	setup_wakeup_timer "$timer_sleep"

	dmesg >"$LOGFILE.dmesg.A"

	# Initiate suspend in different ways.
	case "$1" in
		dbus)
			dbus-send --session --type=method_call \
			--dest=org.freedesktop.PowerManagement \
			/org/freedesktop/PowerManagement \
			org.freedesktop.PowerManagement.Suspend \
			>> "$LOGFILE" || {
				ECHO "FAILED: dbus suspend failed" 1>&2
				return 1
			}
		;;
		pmsuspend)
			pm-suspend >> "$LOGFILE"
		;;
		mem)
			`echo "mem" > /sys/power/state` >> "$LOGFILE"
		;;
	esac

	# Wait on the machine coming back up -- pulling the dmesg over.
	echo "v---" >>"$LOGFILE"
	retry=30
	while [ "$retry" -gt 0 ]; do
		let "retry=$retry-1"

		# Accumulate the dmesg delta.
		dmesg >"$LOGFILE.dmesg.B"
		diff "$LOGFILE.dmesg.A" "$LOGFILE.dmesg.B" | \
			grep '^>' >"$LOGFILE.dmesg"
		mv "$LOGFILE.dmesg.B" "$LOGFILE.dmesg.A"

		echo "Waiting for suspend to complete $retry to go ..." \
							>> "$LOGFILE"
		cat "$LOGFILE.dmesg" >> "$LOGFILE"

		if [ "`grep -c 'Back to C!' $LOGFILE.dmesg`" -ne 0 ]; then
			break;
		fi
		sleep 1
	done
	echo "^---" >>"$LOGFILE"
	rm -f "$LOGFILE.dmesg"*
	if [ "$retry" -eq 0 ]; then
		ECHO "SUSPEND FAILED, did not go to sleep" 1>&2
		return 1
	fi
}

ECHO ()
{
	echo "$@" | tee -a "$LOGFILE"
}

enable_trace()
{
	if [ -w /sys/power/pm_trace ]; then
		echo 1 > '/sys/power/pm_trace'
	fi
}

disable_trace()
{
	if [ -w /sys/power/pm_trace ]; then
		echo 0 > '/sys/power/pm_trace'
	fi
}

trace_state=-1

save_trace()
{
	if [ -r /sys/power/pm_trace ]; then
		trace_state=`cat /sys/power/pm_trace`
	fi
}

restore_trace()
{
	if [ "$trace_state" -ne -1 -a -w /sys/power/pm_trace ]; then
		echo "$trace_state" > '/sys/power/pm_trace'
	fi
}

battery_count()
{
	cat /proc/acpi/battery/*/state 2>/dev/null | \
	awk '
		BEGIN			{ total = 0 }
		/present:.*yes/		{ total += 1 }
		END			{ print total }
	'
}

battery_capacity()
{
	cat /proc/acpi/battery/*/state 2>/dev/null | \
	awk '
		BEGIN			{ total = 0 }
		/remaining capacity:/	{ total += $3 }
		END			{ print total }
	'
}

ac_needed=-1
ac_is=-1
ac_becomes=-1

ac_required()
{
	ac_check

	ac_needed="$1"
	ac_becomes="$1"
}

ac_transitions()
{
	ac_check

	ac_needed="$1"
	ac_becomes="$2"
}

ac_online()
{
	cat /proc/acpi/ac_adapter/*/state 2>/dev/null | \
	awk '
		BEGIN			{ online = 0; offline = 0 }
		/on-line/		{ online = 1 }
		/off-line/		{ offline = 1 }
		END			{
						if (online) {
							print "1"
						} else if (offline) {
							print "0"
						} else {
							print "-1"
						}
					}
	'
}

ac_check()
{
	typeset ac_current=`ac_online`

	if [ "$ac_becomes" -ne -1 -a "$ac_current" -ne -1 -a \
			"$ac_current" -ne "$ac_becomes" ]; then
		ECHO "*** WARNING: AC power not in expected state" \
			"($ac_becomes) after test"
	fi
	ac_is="$ac_becomes"
}

phase=0
phase_first=1
phase_interactive=1

phase()
{
	typeset sleep

	let phase="$phase+1"

	if [ "$ac_needed" -ne "$ac_is" ]; then
		case "$ac_needed" in
		0) echo "*** please ensure your AC cord is detached" ;;
		1) echo "*** please ensure your AC cord is attached" ;;
		esac
		ac_is="$ac_needed"
	fi
	
	if [ "$timer_sleep" -gt 60 ]; then
		let sleep="$timer_sleep / 60"
		sleep="$sleep minutes"
	else
		sleep="$timer_sleep seconds"
	fi
	echo "*** machine will suspend for $sleep"

	if [ "$auto" -eq 1 ]; then
		:

	elif [ "$phase_interactive" -eq 1 ]; then
		echo "*** press return when ready"
		read x

	elif [ "$phase_first" -eq 1 ]; then
		echo "*** NOTE: there will be no further user interaction from this point"
		echo "*** press return when ready"
		phase_first=0
		read x
	fi
}

save_trace

if [ "$pm_trace" -eq 1 ]; then
	enable_trace
else
	disable_trace
fi

