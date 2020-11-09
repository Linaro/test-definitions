#!/bin/sh
#
# Copyright (C) 2020, Linaro Limited.
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
# Author: Anibal Limon <anibal.limon@linaro.org>
#

. ../../lib/sh-test-lib

usage() {
    echo "Usage: $0 <-b deqp_bin> <-d display> <-p egl_platform> [-c deqp_cases] [-e deqp_exclude] [-f deqp_fail] [-j deqp_runner_jobs] [-o deqp_options] [-r deqp_runner_options]" 1>&2
    exit 1
}

while getopts "b:d:p:c:e:f:j:o:r:" o; do
  case "$o" in
    b) DEQP_BIN="${OPTARG}" ;;
    d) DISPLAY="${OPTARG}" ;;
    p) EGL_PLATFORM="${OPTARG}" ;;
    c) DEQP_CASES="${OPTARG}" ;;
    e) DEQP_EXCLUDE="${OPTARG}" ;;
    f) DEQP_FAIL="${OPTARG}" ;;
    j) DEQP_RUNNER_JOBS="${OPTARG}" ;;
    o) DEQP_OPTIONS="${OPTARG}" ;;
    r) DEQP_RUNNER_OPTIONS="${OPTARG}" ;;
    *) usage ;;
  esac
done

if [ -z "${DEQP_BIN}" ] || [ -z "${DISPLAY}" ] || [ -z "${EGL_PLATFORM}" ]; then
    usage
fi

OUTPUT="$(pwd)/output"
mkdir -p "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE
DEQP_RESULT_FILE="${OUTPUT}/deqp_result.txt"
create_out_dir "${OUTPUT}"

export DISPLAY=${DISPLAY}
export EGL_PLATFORM=${EGL_PLATFORM}

test_set_name="$(basename "${DEQP_BIN}")"

report_set_start "$test_set_name"

set +e
# Disable next check because the variables are options and fails when are quoted.
# shellcheck disable=SC2086
deqp-runner --deqp ${DEQP_BIN} --output $DEQP_RESULT_FILE ${DEQP_CASES} ${DEQP_FAIL} ${DEQP_EXCLUDE} ${DEQP_RUNNER_OPTIONS} ${DEQP_RUNNER_JOBS} -- ${DEQP_OPTIONS}
DEQP_EXITCODE=$?
set -e

while IFS=, read -r test_case_name result;
do
    if [ "$result" = 'Pass' ]; then
        report_pass "$test_case_name"
    elif [ "$result" = 'Fail' ]; then
        report_fail "$test_case_name"
    elif [ "$result" = 'Skip' ]; then
        report_skip "$test_case_name"
    elif [ "$result" = 'Crash' ]; then
        report_fail "$test_case_name"
    elif [ "$result" = 'ExpectedFail' ]; then
        report_pass "$test_case_name"
    elif [ "$result" = 'Flake' ]; then
        report_fail "$test_case_name"
    elif [ "$result" = 'UnexpectedPass' ]; then
        report_fail "$test_case_name"
    else
        report_unknown "$test_case_name"
    fi
done < "$DEQP_RESULT_FILE"

if [ $DEQP_EXITCODE -eq 0 ]; then
    report_pass "$test_set_name"
else
    report_fail "$test_set_name"
    grep -E -v "(,Pass|,Skip|,ExpectedFail)" "$DEQP_RESULT_FILE"
fi

report_set_stop
