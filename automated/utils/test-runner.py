#!/usr/bin/env python
import sys
import os
import platform
import glob
import shutil
import time
import re
import yaml
import json
import csv
import subprocess
import pexpect
import argparse
import logging
from uuid import uuid4


class Agenda(object):
    """
    Analysis and convert agenda file.
    """

    def __init__(self):
        self.agenda = agenda
        with open(self.agenda, 'r') as f:
            self.agenda = yaml.safe_load(f)

    def validate(self):
        key_list = ['definitions']
        for item in key_list:
            if item not in self.agenda:
                print('%s field is missing from agenda file' % item)
                sys.exit(1)

    def agenda_dict(self):
        return self.agenda


class TestSetup(object):
    """
    Setup test.
    """

    def __init__(self):
        self.output = OUTPUT
        self.repo_path = REPO_PATH
        self.test_path = test_path
        self.uuid = uuid

    def create_dir(self):
        if not os.path.exists(self.output):
            os.makedirs(self.output)

    def copy_test_repo(self):
        shutil.rmtree(self.test_path, ignore_errors=True)
        shutil.copytree(self.repo_path, self.test_path, symlinks=True)

    def create_uuid_file(self):
        with open('%s/uuid' % self.test_path, 'w') as f:
            f.write(self.uuid)


class TestDefinition(object):
    """
    Analysis and convert test definition.
    """

    def __init__(self):
        self.test_def = test_path + '/' + test_def
        self.test_path = test_path
        self.skip_install = skip_install
        self.test_parameters = test_parameters
        # Read the YAML to create a testdef dict
        with open(self.test_def, 'r') as f:
            self.testdef = yaml.safe_load(f)
        self.parameters = self.handle_parameters()

    def definition(self):
        with open('%s/testdef.yaml' % self.test_path, 'w') as f:
            f.write(yaml.dump(self.testdef, encoding='utf-8', allow_unicode=True))

    def metadata(self):
        with open('%s/testdef_metadata' % self.test_path, 'w') as f:
            f.write(yaml.dump(self.testdef['metadata'], encoding='utf-8', allow_unicode=True))

    def run(self):
        with open('%s/run.sh' % self.test_path, 'a') as f:
            f.write('#!/bin/sh\n')

            if self.parameters:
                for line in self.parameters:
                    f.write(line)

            f.write('set -e\n')
            f.write('export TESTRUN_ID=%s\n' % self.testdef['metadata']['name'])
            f.write('cd %s\n' % self.test_path)
            f.write('UUID=`cat uuid`\n')
            f.write('echo "<STARTRUN $TESTRUN_ID $UUID>"\n')
            steps = self.testdef['run'].get('steps', [])
            if steps:
                for cmd in steps:
                    if '--cmd' in cmd or '--shell' in cmd:
                        cmd = re.sub(r'\$(\d+)\b', r'\\$\1', cmd)
                    f.write('%s\n' % cmd)
            f.write('echo "<ENDRUN $TESTRUN_ID $UUID>"\n')

        os.chmod('%s/run.sh' % self.test_path, 0755)

    def handle_parameters(self):
        ret_val = ['###default parameters from test definition###\n']

        if 'params' in self.testdef:
            for def_param_name, def_param_value in list(self.testdef['params'].items()):
                # ?'yaml_line'
                if def_param_name is 'yaml_line':
                    continue
                ret_val.append('%s=\'%s\'\n' % (def_param_name, def_param_value))
        elif 'parameters' in self.testdef:
            for def_param_name, def_param_value in list(self.testdef['parameters'].items()):
                if def_param_name is 'yaml_line':
                    continue
                ret_val.append('%s=\'%s\'\n' % (def_param_name, def_param_value))
        else:
            return None

        ret_val.append('######\n')

        ret_val.append('###test parameters from agenda file###\n')
        if self.test_parameters:
            for param_name, param_value in list(self.test_parameters.items()):
                if param_name is 'yaml_line':
                    continue
                ret_val.append('%s=\'%s\'\n' % (param_name, param_value))

        if self.skip_install:
            ret_val.append('SKIP_INSTALL="True"\n')
        ret_val.append('######\n')

        return ret_val


class TestRunner(object):
    def __init__(self):
        self.test_path = test_path
        self.test_uuid = test_uuid
        self.test_timeout = test_timeout
        logger.info('Executing %s/run.sh' % self.test_path)
        shell_cmd = '%s/run.sh 2>&1 | tee %s/stdout.log' % (self.test_path, self.test_path)
        self.child = pexpect.spawn('/bin/sh', ['-c', shell_cmd])

    def check_output(self):
        if self.test_timeout:
            logger.info('Test timeout: %s' % self.test_timeout)
            test_end = time.time() + self.test_timeout

        while self.child.isalive():
            if self.test_timeout and time.time() > test_end:
                logger.warning('%s test timed out, killing test process...' % self.test_uuid)
                self.child.terminate(force=True)
                break
            try:
                self.child.expect('\r\n')
                print(self.child.before)
            except pexpect.TIMEOUT:
                continue
            except pexpect.EOF:
                logger.info('%s test finished.\n' % self.test_uuid)
                break


class ResultPaser(object):
    def __init__(self):
        self.output = OUTPUT
        self.result_path = test_path
        self.metrics = []
        self.results = {}
        self.results['test'] = test_name
        self.results['id'] = test_uuid

    def run(self):
        self.parse_lava_test_case()

        self.dict_to_json()
        self.dict_to_csv()
        logger.info('Result files saved to: %s' % self.result_path)
        print('--- Printing result.csv ---')
        with open('%s/result.csv' % self.result_path) as f:
            print(f.read())

    def parse_lava_test_case(self):
        with open('%s/stdout.log' % self.result_path, 'r') as f:
            for line in f:
                if re.match(r'\<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=.*', line):
                    line = line.strip('\n').strip('<>').split(' ')
                    data = {'test_case_id': '',
                            'result': '',
                            'measurement': '',
                            'units': ''}

                    for string in line:
                        parts = string.split('=')
                        if len(parts) == 2:
                            key, value = parts
                            key = key.lower()
                            data[key] = value

                    self.metrics.append(data.copy())

        self.results['metrics'] = self.metrics

    def dict_to_json(self):
        with open('%s/result.json' % self.result_path, 'w') as f:
            json.dump(self.results, f, indent=4)

    def dict_to_csv(self):
        with open('%s/result.csv' % self.result_path, 'w') as f:
            fieldnames = ['test_case_id', 'result', 'measurement', 'units']
            writer = csv.DictWriter(f, fieldnames=fieldnames)

            writer.writeheader()
            for metric in self.results['metrics']:
                writer.writerow(metric)

        with open('%s/result.csv' % self.output, 'a') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)

            for metric in self.results['metrics']:
                writer.writerow(metric)

# Parse arguments.
parser = argparse.ArgumentParser()
parser.add_argument('-o', '--output', default='/root/output', dest='OUTPUT',
                    help='''
                    specify a directory to store test and result files.
                    Default: /root/output
                    ''')
parser.add_argument('-a', '--agenda', default=None, dest='agenda',
                    help='''
                    specify an agenda file which has tests and related
                    params listed in yaml format.
                    ''')
parser.add_argument('-d', '--test', default=None, dest='test_def',
                    help='''
                    base on test definition repo location, specify relative path
                    to the test definition to run.
                    Format example: "ubuntu/smoke-tests-basic.yaml"
                    ''')
parser.add_argument('-t', '--timeout', type=int, default=None,
                    dest='test_timeout', help='Specify test timeout')
parser.add_argument('-s', '--skip_install', dest='skip_install',
                    default=False, action='store_true',
                    help='skip install section defined in test definition.')

args = parser.parse_args()

# Obtain values from arguments.
OUTPUT = os.path.realpath(args.OUTPUT)
agenda = args.agenda
test_def = args.test_def
test_timeout = args.test_timeout

# Create a logger.
logger = logging.getLogger('RUNNER')
logger.setLevel(logging.DEBUG)
ch = logging.StreamHandler()
ch.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(name)s: %(levelname)s: %(message)s')
ch.setFormatter(formatter)
logger.addHandler(ch)

try:
    REPO_PATH = os.environ['REPO_PATH']
except KeyError:
    logger.error("KeyError: REPO_PATH")
    logger.error("Please run '. ./setenv.sh' to setup environment variables")
    sys.exit(1)

# Generate test list.
if test_def:
    test_list = [{'path': test_def}]
elif agenda:
    test_agenda = Agenda()
    test_agenda.validate()
    agenda_dict = test_agenda.agenda_dict()
    test_list = agenda_dict['definitions']
    for item in test_list:
        if 'path' not in item:
            logger.error('Relative path is needed for each test')
            sys.exit(1)
else:
    logger.error('Plese specify either agenda file or test_def argument.')
    sys.exit(1)

logger.info('Tests to run:')
for test in test_list:
    print(test)

# Run tests.
for test in test_list:
    # Check if testdef exists.
    test_def = test['path']
    test_def_path = os.path.join(REPO_PATH, test_def)
    if not os.path.exists(test_def_path):
        logger.error(' %s NOT found, exiting...' % test_def_path)
        sys.exit(1)
    else:
        logger.info('About to run: %s' % test_def_path)

    # Use the values defined in agenda file.
    if 'timeout' in test:
        test_timeout = test['timeout']
    skip_install = args.skip_install
    if 'skip_install' in test:
        skip_install = test['skip_install']
    test_parameters = None
    if 'parameters' in test:
        test_parameters = test['parameters']
    if 'params' in test:
        test_parameters = test['params']
    if test_parameters:
        print('Test parameters from agenda file: %s' % test_parameters)

    # Fixup variables with uuid.
    uuid = str(uuid4())
    test_name = os.path.splitext(test_def.split('/')[-1])[0]
    test_uuid = test_name + '_' + uuid
    logger.info('test-name_uuid: %s' % test_uuid)
    test_path = os.path.join(OUTPUT, test_uuid)
    logger.info('Test path: %s' % test_path)

    # Create directories and copy files needed.
    setup = TestSetup()
    setup.create_dir()
    setup.copy_test_repo()
    setup.create_uuid_file()

    # Convert test definition to the files needed by lava-test-runner.
    test_def = TestDefinition()
    test_def.definition()
    test_def.metadata()
    test_def.run()

    # Test run.
    test_run = TestRunner()
    test_run.check_output()

    # Parse test output, save results in json and csv format.
    result_parser = ResultPaser()
    result_parser.run()
