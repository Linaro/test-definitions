#!/usr/bin/python
#
# Copyright (C) 2016, Linaro Limited.
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
# Author: Josep Puigdemont <josep.puigdemont@linaro.org>
#

from __future__ import print_function
import sys
import os
import subprocess
import re
from time import sleep, time
import datetime
import argparse


class httperf:
    HTTPERF_INIT = 0
    HTTPERF_RUNNING = 1
    HTTPERF_FINISHED = 2
    HTTPERF_ERROR = 3

    def __init__(self, rate=10000, server="localhost", duration=5, timeout=1):
        self.state = httperf.HTTPERF_INIT
        self.result = None
        self.errors = {}
        self.request_rate = 0

        self.rate = rate
        self.duration = duration
        self.timeout = timeout
        self.server = server

    def run(self):
        if self.state != httperf.HTTPERF_INIT:
            return 1

        self.state = httperf.HTTPERF_RUNNING
        self.proc = subprocess.Popen(
            [
                "httperf",
                "--hog",
                "--timeout",
                str(self.timeout),
                "--server",
                self.server,
                "--uri",
                "/index.html",
                "--rate",
                str(self.rate),
                "--num-conns",
                str(self.rate * self.duration),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True,
        )

        self.stdout, self.stderr = self.proc.communicate()

        if self.proc.returncode != 0:
            print("Error running httperf", file=sys.stderr)
            self.state = httperf.HTTPERF_ERROR
            return 1

        self.state = httperf.HTTPERF_FINISHED
        self.__parse_output()

        return 0

    def __parse_output(self):
        re1 = re.compile("^Errors: total")
        re2 = re.compile("^Errors: fd")
        re3 = re.compile("^Request rate")
        for line in self.stdout.split("\n"):
            values = line.split()
            if re1.match(line):
                self.errors["total"] = int(values[2])
                self.errors["client-timo"] = int(values[4])
                self.errors["socket-timo"] = int(values[6])
                self.errors["connrefused"] = int(values[8])
                self.errors["connreset"] = int(values[10])
            elif re2.match(line):
                self.errors["fd-unavail"] = int(values[2])
                self.errors["addrunavail"] = int(values[4])
                self.errors["ftab-full"] = int(values[6])
                self.errors["other"] = int(values[8])
            elif re3.match(line):
                self.request_rate = float(values[2])

    def get_errors(self, kind):
        if self.state != httperf.HTTPERF_FINISHED:
            print("get_errors: not finished", file=sys.stderr)
            # FIXME: raise exception
            return 0

        if kind not in self.errors:
            print("Error type %s not valid" % kind)
            # FIXME: raise exception
            return 0

        return self.errors[kind]

    def get_error_list(self):
        return self.errors.keys()

    def write(self, filename="httperf.txt"):
        if self.state != httperf.HTTPERF_FINISHED:
            return 1

        with open(filename, "w") as f:
            f.write(self.output())

        return 0

    def output(self):
        if self.state == httperf.HTTPERF_FINISHED:
            return self.stdout
        return None


class httperf_runner:
    IDLE = 0
    RUNNING = 1
    SUCCESS = 2
    FAILED = 3
    FINISHED = 4
    ERROR = 5

    def __init__(
        self,
        step=10000,
        rate=10000,
        min_step=200,
        duration=5,
        server="localhost",
        sleep_time=61,
        tolerance={},
        attempts=1,
    ):
        self.state = httperf_runner.IDLE
        self.step = step
        self.rate = rate
        self.min_step = min_step
        self.duration = duration
        self.server = server
        self.sleep_time = sleep_time
        self.tolerance = tolerance
        self.attempts = attempts

        self.max_rate = 0
        self.max_run = None
        self.elapsed_time = 0

    def __has_errors(self, cmd):
        if cmd:
            for kind in cmd.get_error_list():
                if kind == "total":
                    continue
                count = cmd.get_errors(kind)
                if count == 0:
                    continue
                if kind in self.tolerance:
                    if count <= self.tolerance[kind]:
                        continue
                return True

        return False

    def run(self):
        step = self.step
        rate = self.rate
        lower_limit = 0
        upper_limit = 0
        self.state = httperf_runner.RUNNING

        start_time = time()
        while self.state == httperf_runner.RUNNING:
            cmd = None
            attempt = 0
            while attempt < self.attempts:
                attempt += 1

                if self.__has_errors(cmd):
                    print("--- SLEEP", self.sleep_time, "and RETRY")
                    sleep(self.sleep_time)

                print(
                    "--- RANGE: [%0.1f, %0.1f], STEP: %d"
                    % (lower_limit, upper_limit, step)
                )
                print("--- BEGIN", rate, ", ATTEMPT %d/%d" % (attempt, self.attempts))
                self.state = httperf_runner.RUNNING
                cmd = httperf(rate=rate, duration=self.duration, server=self.server)
                cmd.run()
                print(cmd.output())
                print("--- END")

                if self.__has_errors(cmd):
                    self.state = httperf_runner.FAILED
                    print("--- ERRORS:", cmd.get_errors("total"))
                else:
                    break

            if self.state == httperf_runner.FAILED:
                if upper_limit == 0 or rate < upper_limit:
                    upper_limit = rate
            else:
                # NO errors, we might have found a NEW HIGH
                if cmd.request_rate > lower_limit:
                    print("--- NEW HIGH:", cmd.request_rate)
                    lower_limit = cmd.request_rate
                    # save this httperf object
                    self.max_run = cmd
                else:
                    # NOTE: we end up here if we tried a higher rate but we
                    # actually got lower replies/second, without errors.
                    # If we don't do anything, we'll keep trying the same rate
                    # over and over.
                    # To avoid this situation, we reduce the upper_limit by 10%.
                    # Eventually we will find a better rate or exit the loop.
                    print("--- REDUCING UPPER LIMIT BY 10%")
                    upper_limit = int(upper_limit * 0.9)

            if upper_limit == 0:
                rate = int(lower_limit) + step
                self.state = httperf_runner.RUNNING
            else:
                diff = upper_limit - lower_limit
                if diff <= self.min_step:
                    self.state = httperf_runner.FINISHED
                else:
                    rate = int((upper_limit + lower_limit) / 2)
                    self.state = httperf_runner.RUNNING

        self.elapsed_time = time() - start_time
        self.max_rate = lower_limit

        return 0

    def output(self):
        if self.max_run:
            return self.max_run.output()

    def write(self, filename="httperf.txt"):
        if self.max_run:
            self.max_run.write(filename)


class ParseTolerance(argparse.Action):
    def __call__(self, parser, namespace, values, option_string=None):
        i = iter(values)
        ret = dict(zip(i, i))
        for key in ret:
            try:
                ret[key] = int(ret[key])
            except ValueError:
                print(
                    "Warning: Ignoring value",
                    ret[key],
                    "for",
                    key,
                    ": not an integer",
                    file=sys.stderr,
                )
                ret[key] = 0

        setattr(namespace, self.dest, ret)


parser = argparse.ArgumentParser(description="Find highest rate using httperf")
parser.add_argument(
    "--attempts",
    "-a",
    type=int,
    default=[2],
    nargs=1,
    help="Number of attempts for each rate under test (default 2)",
)
parser.add_argument(
    "--csv",
    nargs=1,
    help="Save the results in the given file. The file will "
    + "have one column which is later easy to import in a "
    + "spreadsheet. If the file exists, data will be "
    + "appended to it.",
)
parser.add_argument(
    "--dir",
    "-d",
    nargs=1,
    default=None,
    help="Put all output files in this directory (default CWD)",
)
parser.add_argument(
    "--duration",
    nargs=1,
    default=[5],
    type=int,
    help="Duration of each httperf run (default 5)",
)
parser.add_argument(
    "--iterations",
    "-i",
    default=[1],
    nargs=1,
    type=int,
    help="Runs the script this amount of times (default 1)",
)
parser.add_argument(
    "--min-step",
    "-m",
    nargs=1,
    default=[200],
    type=int,
    help="The minimum step to consider (default 200)",
)
parser.add_argument(
    "--output",
    "-o",
    default="httperf_max_rate",
    help="Stores the result in the OUTPUT file, with the "
    + "iteration number appended (default httperf_max_rate)",
)
parser.add_argument(
    "--rate",
    "-r",
    type=int,
    default=[10000],
    nargs=1,
    help="The initial request rate to try (default 10000)",
)
parser.add_argument(
    "--step",
    "-s",
    type=int,
    default=[10000],
    nargs=1,
    help="The initial step (default 10000)",
)
parser.add_argument(
    "--server", default="localhost", help="Server to connet to (defaut localhost)"
)
parser.add_argument(
    "--tolerance",
    nargs="+",
    action=ParseTolerance,
    default={"client-timo": 20},
    help="list of key value pairs of errors accepted by "
    + "httperf. Ex: --tolerance client-timo 20 other 5",
)

args = parser.parse_args()

if args.dir:
    if not os.path.exists(args.dir[0]):
        os.mkdir(args.dir[0])
    elif not os.path.isdir(args.dir[0]):
        print(
            "Error:", args.dir[0], "exists but it is not a directory", file=sys.stderr
        )
        exit(1)
else:
    args.dir = ["."]

if not os.access(args.dir[0], os.W_OK):
    print("Error: can not write to ", os.path.realpath(args.dir[0]), file=sys.stderr)
    exit(1)

if args.csv:
    csv_file = os.path.join(args.dir[0], args.csv[0])
else:
    csv_file = None

ofile = os.path.join(args.dir[0], args.output)

start_time = time()
for i in range(args.iterations[0]):
    print("\n--- ITERATION", i)
    runner = httperf_runner(
        step=args.step[0],
        rate=args.rate[0],
        server=args.server,
        min_step=args.min_step[0],
        duration=args.duration[0],
        tolerance=args.tolerance,
        attempts=args.attempts[0],
    )

    if runner.run():
        print("There was an error, exiting.", file=sys.stderr)
        exit(1)

    print("--- MAX RATE: %0.1f" % runner.max_rate)
    print("--- ELAPSED TIME:", str(datetime.timedelta(seconds=runner.elapsed_time)))

    runner.write(ofile + str(i))

    if csv_file:
        with open(csv_file, "a") as f:
            print(runner.max_rate, file=f)

print("\n--- TOTAL ELAPSED TIME:", str(datetime.timedelta(seconds=time() - start_time)))
