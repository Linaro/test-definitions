#!/usr/bin/python

import re
import sys
from numpy import *

values = []

r = re.compile(sys.argv[2] + "\s+(?P<measurement>[0-9.]+)")
f = open(sys.argv[1], "r")
for line in f.readlines():
    search = r.search(line)
    if search:
        values.append(float(search.group('measurement')))

try:
    sys.argv[4]
except IndexError:
    cmd_options = ""
else:
    cmd_options = sys.argv[4]

np_array = array(values)

format = "%-16s%-16s%-16s%-16s"
print format % (sys.argv[1].split('.', 1)[0] + cmd_options + "_min:", str(min(np_array)), sys.argv[3], "pass")
print format % (sys.argv[1].split('.', 1)[0] + cmd_options + "_max:", str(max(np_array)), sys.argv[3], "pass")
print format % (sys.argv[1].split('.', 1)[0] + cmd_options + "_avg:", str(mean(np_array)), sys.argv[3], "pass")
print format % (sys.argv[1].split('.', 1)[0] + cmd_options + "_mdn:", str(median(np_array)), sys.argv[3], "pass")
print format % (sys.argv[1].split('.', 1)[0] + cmd_options + "_std:", str(std(np_array)), sys.argv[3], "pass")
