#!/usr/bin/env python

import argparse
import decimal
import json
import subprocess
import sys
from collections import OrderedDict

parser = argparse.ArgumentParser()
parser.add_argument('-a', '--auth-token', dest='auth_token', required=True, help='Specify authentication token.')
parser.add_argument('-i', '--input-file', dest='input_file', required=True,
                    help='Specify local json file.')
parser.add_argument('-t', '--type', dest='type', required=True, choices=['testdata', 'metadata', 'attachment'],
                    help='Input file data type')
parser.add_argument('-m', '--team', dest='team', required=True, help='Team identifier.')
parser.add_argument('-p', '--project', dest='project', required=True, help='Project identifier.')
parser.add_argument('-b', '--build', dest='build', required=True,
                    help='''
                    Build identifier. It can be a git commit hash, a Android manifest hash, or anything really. Extra
                    information on the build can be submitted as an attachment. If a build timestamp is not informed
                    there, the time of submission is assumed.
                    ''')
parser.add_argument('-e', '--test-env', dest='test_env', required=True,
                    help='Environmenr identitifer. It will be created automatically if does not exist before.')
args = parser.parse_args()
# TODO: Change the host addr to qa-reports.l.o or add a argument for it.
post_url = 'http://127.0.0.1:8000/api/submit/%s/%s/%s/%s' % (args.team, args.project, args.build, args.test_env)
post_cmd = ['curl', '--header "Auth-Token: %s"' % args.auth_token]
data_type = str(args.type)

if data_type == 'testdata':
    result_file = args.input_file
    tests = OrderedDict()
    metrics = OrderedDict()

    with open(result_file) as f:
        try:
            results = json.load(f)
        except ValueError as e:
            print('ValueError: %s' % str(e))
            print('Please check if a valid result file in JSON format specified.')
            sys.exit(1)

    squad_tests = OrderedDict()
    squad_metrics = OrderedDict()
    for result in results:
        for metric in result['metrics']:
            key = '%s/%s' % (result['name'], metric['test_case_id'])
            if not metric['measurement']:
                # Collect pass/fail test results.
                squad_tests[key] = metric['result']
            else:
                # Collect performance test results.
                try:
                    measurement = decimal.Decimal(metric['measurement'])
                    squad_metrics[key] = float(metric['measurement'])
                except decimal.InvalidOperation:
                    print('Invalid measurement: %s' % metric['measurement'])
                    print('Skipped adding: %s' % metric)

    if not squad_tests and not squad_metrics:
        print('No valid result found!')
        sys.exit(1)
    if squad_tests:
        post_cmd.append('--form tests=@squad_tests.json')
    if squad_metrics:
        post_cmd.append('--form metrics=@squad_metrics.json')

    print('Generating squad_tests.json...')
    with open('squad_tests.json', 'wb') as f:
        f.write(json.dumps(squad_tests, encoding='utf-8'))
    print('Generating squad_metrics.json...')
    with open('squad_metrics.json', 'wb') as f:
        f.write(json.dumps(squad_metrics, encoding='utf-8'))
elif data_type == 'metadata':
    # TODO: Generate metadata file.
    post_cmd.append('--form metadata=@%s' % args.input_file)
elif data_type == 'attachment':
    post_cmd.append('--form metadata=@%s' % args.input_file)

post_cmd.append(post_url)
post_cmd = ' '.join(post_cmd)
print('Uploading %s with post_cmd: %s' % (data_type, post_cmd))
subprocess.call(post_cmd, shell=True)
