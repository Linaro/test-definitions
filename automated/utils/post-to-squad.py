#!/usr/bin/env python

import argparse
import decimal
import json
import os
import subprocess
import sys
from collections import OrderedDict

try:
    import requests
except ImportError:
    subprocess.call(['pip', 'install', 'requests'])
    import requests


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-a', '--auth-token', dest='auth_token', required=True, help='Specify authentication token.')
    parser.add_argument('-t', '--testdata', dest='testdata', required=True, help='Specify test result file.')
    parser.add_argument('-m', '--metadata', dest='metadata', required=True, help='Specify metadata file.')
    parser.add_argument('-A', '--attachment', dest='attachment', help='Specify attachment file.')
    parser.add_argument('-T', '--team', dest='team', required=True, help='Team identifier.')
    parser.add_argument('-p', '--project', dest='project', required=True, help='Project identifier.')
    parser.add_argument('-b', '--build', dest='build', required=True, help='Build identifier.')
    parser.add_argument('-e', '--test-env', dest='test_env', required=True, help='Environmenr identitifer.')
    parser.add_argument('-u', '--url', dest='url', required=True, help='Dashboard url.')
    args = parser.parse_args()
    return args


def convert_result(testdata):
    with open(testdata) as f:
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
                    squad_metrics[key] = float(measurement)
                except decimal.InvalidOperation:
                    print('Invalid measurement: %s' % metric['measurement'])
                    print('Skipped adding: %s' % metric)

    if not squad_tests and not squad_metrics:
        print('No valid result found!')
        sys.exit(1)

    if squad_tests:
        # post_cmd.append('--form tests=@squad_tests.json')
        print('Generating squad_tests.json...')
        with open('squad_tests.json', 'wb') as f:
            f.write(json.dumps(squad_tests, encoding='utf-8'))

    if squad_metrics:
        # post_cmd.append('--form metrics=@squad_metrics.json')
        print('Generating squad_metrics.json...')
        with open('squad_metrics.json', 'wb') as f:
            f.write(json.dumps(squad_metrics, encoding='utf-8'))


def main():
    args = parse_args()
    url = '%s/api/submit/%s/%s/%s/%s' % (args.url, args.team, args.project, args.build, args.test_env)
    print('api: %s' % url)

    if os.path.exists(args.metadata):
        files = [('metadata', open(args.metadata, 'rb'))]
    else:
        print('metadata file is required for each upload!')
        sys.exit(1)
    if args.attachment is not None:
        if os.path.exists('args.attachment'):
            files.append(tuple(['attachment', open(args.attachment, 'rb')]))
        else:
            print('Attachment %s Not found' % args.attachment)
            print('Skipped uploading %s' % args.attachment)

    convert_result(args.testdata)
    if os.path.exists('squad_tests.json'):
        files.append(tuple(['tests', open('squad_tests.json', 'rb')]))
    if os.path.exists('squad_metrics.json'):
        files.append(tuple(['metrics', open('squad_metrics.json', 'rb')]))
    print('Files to post: %s' % files)

    headers = {'Auth-Token': args.auth_token}
    r = requests.post(url, headers=headers, files=files)
    print(r.text)

if __name__ == "__main__":
        main()
