#!/usr/bin/python
import re
import sys
import os

max_threshold = int(sys.argv[1])
avg_threshold = int(sys.argv[2])
pass_max_threshold = "pass"
pass_avg_threshold = "pass"
max_latency = 0
avg_latency = 0
min_latency = max_threshold

# parse format:
# T:49 ( 4518) P:31 I:4243600 C:      2 Min:      8 Act:    8 Avg:    8 Max:       9
parser = re.compile("(?P<T>\d+)\D+(?P<T1>\d+)\D+(?P<P>\d+)\D+(?P<I>\d+)\D+(?P<C>\d+)\D+(?P<Min>\d+)\D+(?P<Act>\d+)\D+(?P<Avg>\d+)\D+(?P<Max>\d+)")

data = sys.stdin.readlines()

if len(data) == 0:
    print "test_case_id:Test program running result:fail measurement:0 units:none"
else:
    for line in data:
        result = parser.search(line)
        if result is not None:
            if int(result.group('Max')) > max_threshold:
                pass_max_threshold = "fail"

            if int(result.group('Avg')) > avg_threshold:
                pass_avg_threshold = "fail"

            if int(result.group('Max')) > max_latency:
                max_latency = int(result.group('Max'))

            if int(result.group('Avg')) > avg_latency:
                avg_latency = int(result.group('Avg'))

            if int(result.group('Min')) < min_latency:
                min_latency = int(result.group('Min'))

    print "test_case_id:Max latency bound (<" + str(max_threshold) + "us) result:" + pass_max_threshold + " measurement:" + str(max_latency) + " units:usecs"

    print "test_case_id:Avg latency bound (<" + str(avg_threshold) + "us) result:" + pass_avg_threshold + " measurement:" + str(avg_latency) + " units:usecs"

    # ignore min latency bound
    print "test_case_id:Min latency result:skip measurement:" + str(min_latency) + " units:usecs"
