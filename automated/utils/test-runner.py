#!/usr/bin/env python
import argparse
import csv
import json
import logging
import os
import re
import shutil
import sys
import time
from uuid import uuid4


try:
    import pexpect
    import yaml
except ImportError as e:
    print(e)
    print('Please run the below command to install modules required')
    print('pip install -r ${REPO_PATH}/automated/utils/requirements.txt')
    sys.exit(1)


class TestPlan(object):
    """
    Analysis args specified, then generate test plan.
    """

    def __init__(self, args):
        self.output = args.output
        self.test_def = args.test_def
        self.test_plan = args.test_plan
        self.timeout = args.timeout
        self.skip_install = args.skip_install
        self.logger = logging.getLogger('RUNNER.TestPlan')

    def test_list(self):
        if self.test_def:
            if not os.path.exists(self.test_def):
                self.logger.error(' %s NOT found, exiting...' % self.test_def)
                sys.exit(1)

            test_list = [{'path': self.test_def}]
            test_list[0]['uuid'] = str(uuid4())
            test_list[0]['timeout'] = self.timeout
            test_list[0]['skip_install'] = self.skip_install
        elif self.test_plan:
            if not os.path.exists(self.test_plan):
                self.logger.error(' %s NOT found, exiting...' % self.test_plan)
                sys.exit(1)

            with open(self.test_plan, 'r') as f:
                test_plan = yaml.safe_load(f)
            try:
                test_list = test_plan['requirements']['tests']['automated']
                for test in test_list:
                    test['uuid'] = str(uuid4())
            except KeyError as e:
                self.logger.error("%s is missing from test plan" % str(e))
                sys.exit(1)
        else:
            self.logger.error('Plese specify a test or test plan.')
            sys.exit(1)

        return test_list


class TestSetup(object):
    """
    Create directories required, then copy files needed to these directories.
    """

    def __init__(self, test, args):
        self.output = os.path.realpath(args.output)
        self.test_name = os.path.splitext(test['path'].split('/')[-1])[0]
        self.uuid = test['uuid']
        self.test_uuid = self.test_name + '_' + self.uuid
        self.test_path = os.path.join(self.output, self.test_uuid)
        self.logger = logging.getLogger('RUNNER.TestSetup')

    def validate_env(self):
        # Inspect if environment set properly.
        try:
            self.repo_path = os.environ['REPO_PATH']
        except KeyError:
            self.logger.error('KeyError: REPO_PATH')
            self.logger.error("Please run '. ./bin/setenv.sh' to setup test environment")
            sys.exit(1)

    def create_dir(self):
        if not os.path.exists(self.output):
            os.makedirs(self.output)
            self.logger.info('Output directory created: %s' % self.output)

    def copy_test_repo(self):
        self.validate_env()
        shutil.rmtree(self.test_path, ignore_errors=True)
        shutil.copytree(self.repo_path, self.test_path, symlinks=True)
        self.logger.info('Test repo copied to: %s' % self.test_path)

    def create_uuid_file(self):
        with open('%s/uuid' % self.test_path, 'w') as f:
            f.write(self.uuid)


class TestDefinition(object):
    """
    Convert test definition to testdef.yaml, testdef_metadata and run.sh.
    """

    def __init__(self, test, args):
        self.output = os.path.realpath(args.output)
        self.test_def = test['path']
        self.test_name = os.path.splitext(self.test_def.split('/')[-1])[0]
        self.test_uuid = self.test_name + '_' + test['uuid']
        self.test_path = os.path.join(self.output, self.test_uuid)
        self.logger = logging.getLogger('RUNNER.TestDef')
        self.skip_install = args.skip_install
        if 'skip_install' in test:
            self.skip_install = test['skip_install']
        self.custom_params = None
        if 'parameters' in test:
            self.custom_params = test['parameters']
        if 'params' in test:
            self.custom_params = test['params']
        with open(self.test_def, 'r') as f:
            self.testdef = yaml.safe_load(f)

    def definition(self):
        with open('%s/testdef.yaml' % self.test_path, 'w') as f:
            f.write(yaml.dump(self.testdef, encoding='utf-8', allow_unicode=True))

    def metadata(self):
        with open('%s/testdef_metadata' % self.test_path, 'w') as f:
            f.write(yaml.dump(self.testdef['metadata'], encoding='utf-8', allow_unicode=True))

    def run(self):
        with open('%s/run.sh' % self.test_path, 'a') as f:
            f.write('#!/bin/sh\n')

            self.parameters = self.handle_parameters()
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

        ret_val.append('###custom parameters from test plan###\n')
        if self.custom_params:
            for param_name, param_value in list(self.custom_params.items()):
                if param_name is 'yaml_line':
                    continue
                ret_val.append('%s=\'%s\'\n' % (param_name, param_value))

        if self.skip_install:
            ret_val.append('SKIP_INSTALL="True"\n')
        ret_val.append('######\n')

        return ret_val


class TestRun(object):
    def __init__(self, test, args):
        self.output = os.path.realpath(args.output)
        self.test_name = os.path.splitext(test['path'].split('/')[-1])[0]
        self.test_uuid = self.test_name + '_' + test['uuid']
        self.test_path = os.path.join(self.output, self.test_uuid)
        self.test_timeout = args.timeout
        if 'timeout' in test:
            self.test_timeout = test['timeout']
        self.logger = logging.getLogger('RUNNER.TestRun')
        self.logger.info('Executing %s/run.sh' % self.test_path)
        shell_cmd = '%s/run.sh 2>&1 | tee %s/stdout.log' % (self.test_path, self.test_path)
        self.child = pexpect.spawn('/bin/sh', ['-c', shell_cmd])

    def check_output(self):
        if self.test_timeout:
            self.logger.info('Test timeout: %s' % self.test_timeout)
            test_end = time.time() + self.test_timeout

        while self.child.isalive():
            if self.test_timeout and time.time() > test_end:
                self.logger.warning('%s test timed out, killing test process...' % self.test_uuid)
                self.child.terminate(force=True)
                break
            try:
                self.child.expect('\r\n')
                print(self.child.before)
            except pexpect.TIMEOUT:
                continue
            except pexpect.EOF:
                self.logger.info('%s test finished.\n' % self.test_uuid)
                break


class ResultParser(object):
    def __init__(self, test, args):
        self.output = os.path.realpath(args.output)
        self.test_name = os.path.splitext(test['path'].split('/')[-1])[0]
        self.test_uuid = self.test_name + '_' + test['uuid']
        self.result_path = os.path.join(self.output, self.test_uuid)
        self.metrics = []
        self.results = {}
        self.results['test'] = self.test_name
        self.results['id'] = self.test_uuid
        self.logger = logging.getLogger('RUNNER.ResultParser')

    def run(self):
        self.parse_stdout()
        self.dict_to_json()
        self.dict_to_csv()
        self.logger.info('Result files saved to: %s' % self.result_path)
        print('--- Printing result.csv ---')
        with open('%s/result.csv' % self.result_path) as f:
            print(f.read())

    def parse_stdout(self):
        with open('%s/stdout.log' % self.result_path, 'r') as f:
            for line in f:
                if re.match(r'\<(|LAVA_SIGNAL_TESTCASE )TEST_CASE_ID=.*', line):
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


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-o', '--output', default='/root/output', dest='output',
                        help='''
                        specify a directory to store test and result files.
                        Default: /root/output
                        ''')
    parser.add_argument('-p', '--test_plan', default=None, dest='test_plan',
                        help='''
                        specify an test plan file which has tests and related
                        params listed in yaml format.
                        ''')
    parser.add_argument('-d', '--test_def', default=None, dest='test_def',
                        help='''
                        base on test definition repo location, specify relative
                        path to the test definition to run.
                        Format example: "ubuntu/smoke-tests-basic.yaml"
                        ''')
    parser.add_argument('-t', '--timeout', type=int, default=None,
                        dest='timeout', help='Specify test timeout')
    parser.add_argument('-s', '--skip_install', dest='skip_install',
                        default=False, action='store_true',
                        help='skip install section defined in test definition.')
    args = parser.parse_args()
    return args


def main():
    # Setup logger.
    logger = logging.getLogger('RUNNER')
    logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s: %(levelname)s: %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    if os.geteuid() != 0:
        logger.error("Sorry, you need to run this as root")
        sys.exit(1)

    # Generate test plan.
    args = get_args()
    test_plan = TestPlan(args)
    test_list = test_plan.test_list()
    logger.info('Tests to run:')
    for test in test_list:
        print(test)

    # Run tests.
    for test in test_list:
        # Create directories and copy files needed.
        setup = TestSetup(test, args)
        setup.create_dir()
        setup.copy_test_repo()
        setup.create_uuid_file()

        # Convert test definition.
        test_def = TestDefinition(test, args)
        test_def.definition()
        test_def.metadata()
        test_def.run()

        # Run test.
        test_run = TestRun(test, args)
        test_run.check_output()

        # Parse test output, save results in json and csv format.
        result_parser = ResultParser(test, args)
        result_parser.run()

if __name__ == "__main__":
    main()
