#!/usr/bin/env python

import re
import sys

RESULT_MAP = {'PAS': 'pass',
              'FAL': 'fail',
              'SKP': 'skip',
              'ABT': 'fail',
              'WRN': 'fail',
              'ERR': 'fail'}
line = re.compile("(?P<owner>[a-z_]+)\\s*-(?P<field>[A-Z]+):(?P<content>.*)")
header = re.compile("(?P<gowner>[a-z]+):\\s(?P<group_name>[ ()a-zA-Z-_]+)")
result = re.compile("(?P<r>.*):\\s(?P<test_name>Test [0-9]),\\s(?P<comment>.*)")
summary = re.compile("(?P<passed_no>[0-9]+) passed, (?P<failed_no>[0-9]+) failed, (?P<warning_no>[0-9]+) warning, (?P<aborted_no>[0-9]+) aborted, (?P<skil_no>[0-9]+) skipped, (?P<info_no>[0-9]+) info only")

grouplist = {}

with open(sys.argv[1], 'r') as f:
    for l in f.readlines():
        linere = line.search(l)
        if linere:
            owner = linere.group('owner')
            field = linere.group('field')
            content = linere.group('content')
            if field == 'HED':
                headerre = header.search(content)
                if headerre:
                    group_name = headerre.group('group_name')
                    gt = {'name': group_name, 'subtests': [], 'result': ''}
                    grouplist[owner] = gt
            elif field in RESULT_MAP:
                resultre = result.search(content)
                if resultre:
                    test = {'test_name': resultre.group('test_name'),
                            'result': RESULT_MAP[field],
                            'comment': resultre.group('comment')}
                    grouplist[owner]['subtests'].append(test)
                else:
                    if 'comment' not in grouplist[owner]:
                        grouplist[owner]['comment'] = content
                    grouplist[owner]['result'] = RESULT_MAP[field]
            elif field == 'SUM':
                sumre = summary.search(content)
                if sumre:
                    if re.match("^0000", ''.join(sumre.groups())):   # 0 passed, 0 failed, 0 warning, 0 aborted
                        grouplist[owner]['result'] = 'skip'

for gname, t in grouplist.iteritems():
    if len(t['subtests']) == 0:
        t_result = 'skip'
        t_comment = t['name']
        if t['result']:
            t_result = t['result']
        if 'comment' in t:
            t_comment = t['comment']
        print("%s (%s): %s" % (gname, t_comment, t_result))
    else:
        for tt in t['subtests']:
            if tt['comment']:
                print("%s %s(%s): %s" % (gname, tt['test_name'], tt['comment'], tt['result']))
            else:
                print("%s %s(%s): %s" % (gname, tt['test_name'], t['name'], tt['result']))
