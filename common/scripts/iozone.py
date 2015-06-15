#!/usr/bin/env python

import sys

item = ['kB', 'reclen', 'write', 'rewrite', 'read', 'reread',
        'random read', 'random write', 'bkwd read', 'record rewrite',
        'stride read', 'fwrite', 'frewrite', 'fread', 'freread']

data = sys.stdin.readlines()
for r in data:
    a = r.split()
    for i in a[2:]:
        print "%s-%s-kB-%s-reclen: %s pass" % (item[a.index(i)], a[0], a[1], i)
