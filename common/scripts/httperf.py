#!/usr/bin/python
import re
import sys
import os

request_rate = int(sys.argv[1])
connection_lower_threshold = int(0.9*float(request_rate))
connection_upper_threshold = int(1.1*float(request_rate))
pass_connection_threshold = "pass"
parser = re.compile("Connection rate: (?P<Conn>\d+\.\d+)")

data = sys.stdin.readlines()

if len(data) == 0:
    print "test_case_id:connection-rate measurement:0 units:none result:fail"
else:
    for line in data:
        result = parser.search(line)
        if result is not None:
            print "Found a line"
            if float(result.group('Conn')) > int(connection_lower_threshold):
                if float(result.group('Conn')) < int(connection_upper_threshold):
                    print str(result.group('Conn')) + " below upper threshold"
                    print "test_case_id:connection-rate measurement:" + str(result.group('Conn')) + " units:Connections/second result:pass"
