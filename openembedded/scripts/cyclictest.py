#!/usr/bin/python
import re
import sys
import os

threshold = 10000
pass_threshold = True
max_lentency = 0

#parse format:
# T:49 ( 4518) P:31 I:4243600 C:      2 Min:      8 Act:    8 Avg:    8 Max:       9
parser = re.compile("(?P<T>\d+)\D+(?P<T1>\d+)\D+(?P<P>\d+)\D+(?P<I>\d+)\D+(?P<C>\d+)\D+(?P<Min>\d+)\D+(?P<Act>\d+)\D+(?P<Avg>\d+)\D+(?P<Max>\d+)")

data = sys.stdin.readlines()

if len(data) == 0:
    print "test_case_id:Test program running result:fail measurement:0 units:none"
else:
    print "test_case_id:Test program running result:pass measurement:0 units:none"

    for line in data:
        result = parser.search(line)
        if result is not None:
            if int(result.group('Max')) > threshold:
                pass_threshold = False

            if int(result.group('Avg')) > threshold:
                pass_threshold = False

            if int(result.group('Min')) > threshold:
                pass_threshold = False

            if int(result.group('Max')) > max_lentency:
                max_lentency = int(result.group('Max'))

    if pass_threshold is True:
        print "test_case_id:Latency bound (<10ms) result:pass measurement:" + str(max_lentency) + " units:usecs"
    else:
        print "test_case_id:Latency bound (<10ms) result:fail measurement:" + str(max_lentency) + " units:usecs"
