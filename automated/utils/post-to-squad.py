#!/usr/bin/env python

import argparse
import datetime
import decimal
import json
import logging
import os
import requests
from collections import OrderedDict


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-r', '--result-file', dest='result_file',
                        required=True, default='./result.json',
                        help='Specify test result file.')
    parser.add_argument('-a', '--attachment', dest='attachment',
                        action='append', help='Specify attachment file.')
    parser.add_argument('-t', '--team', dest='team', required=True,
                        help='Team identifier. Defaults to "erp"')
    parser.add_argument('-p', '--project', dest='project',
                        help='Project identifier. Defaults to the name of the Linux distribution.')
    parser.add_argument('-b', '--build', dest='build', required=True,
                        help='Build identifier.')
    parser.add_argument('-e', '--test-env', dest='test_env',
                        help='Environment identifier. Defaults to board name.')
    parser.add_argument('-u', '--url', dest='url',
                        default='https://qa-reports.linaro.org',
                        help='Dashboard URL. Defaults to https://qa-reports.linaro.org.')
    parser.add_argument('-v', '--verbose', action='store_true', dest='verbose',
                        default=True, help='Set log level.')

    args = parser.parse_args()
    return args


def squad_result(results):
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
                    logger.info('Invalid measurement: %s' % metric['measurement'])
                    logger.info('Skipped adding: %s' % metric)
    assert squad_tests or squad_metrics, 'No valid result found!'
    return (squad_tests, squad_metrics)


def squad_metadata(results):
    test_plan = list(set(i['test_plan'] for i in results))
    test_version = list(set(i['version'] for i in results))

    assert len(test_plan) == 1, 'More then one test plan found!'
    assert len(test_version) == 1, 'More then one test version found!'

    squad_metadata = OrderedDict()
    test_plan = test_plan[0]
    test_plan_name = os.path.splitext(os.path.basename(test_plan))[0]
    squad_metadata['job_id'] = '{}_{}'.format(test_plan_name, datetime.datetime.utcnow().isoformat())
    squad_metadata['test_plan'] = test_plan
    squad_metadata['test_version'] = test_version[0]
    for key, value in results[-1]['environment'].items():
        if key != 'packages':
            squad_metadata[key] = value
    return squad_metadata


def main():
    auth_token = os.environ.get("SQUAD_AUTH_TOKEN")
    assert auth_token, "SQUAD_AUTH_TOKEN not provided in environment"

    with open(args.result_file, 'r') as f:
        results = json.load(f)
    metadata = squad_metadata(results)
    tests, metrics = squad_result(results)

    files = [('metadata', json.dumps(metadata)),
             ('tests', json.dumps(tests)),
             ('metrics', json.dumps(metrics)),
             ('attachment', open(args.result_file, 'rb'))]
    if args.attachment is not None:
        for item in args.attachment:
            if os.path.exists(item):
                logger.info('Adding {} to attachment list...'.format(item))
                files.append(tuple(['attachment', open(item, 'rb')]))
            else:
                logger.info('Attachment %s Not found' % args.attachment)
                logger.info('Skipped uploading %s' % args.attachment)
    logger.debug('Data to post: %s' % files)

    project = args.project or metadata['linux_distribution']
    test_env = args.test_env or metadata['board_name']
    url = '{}/api/submit/{}/{}/{}/{}'.format(args.url, args.team, project, args.build, test_env)
    logger.info('Posting to {}'.format(url))

    headers = {'Auth-Token': auth_token}
    r = requests.post(url, headers=headers, files=files)
    print(r.text)

if __name__ == "__main__":
    args = parse_args()

    logger = logging.getLogger('post-to-squad')
    logger.setLevel(logging.INFO)
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    main()
