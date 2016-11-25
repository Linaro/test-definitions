#!/usr/bin/env python
import argparse
import csv
import cmd
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

    def test_list(self, kind="automated"):
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
                test_list = []
                for requirement in test_plan['requirements']:
                    if 'tests' in requirement.keys():
                        if requirement['tests'] and \
                                kind in requirement['tests'].keys() and \
                                requirement['tests'][kind]:
                            for test in requirement['tests'][kind]:
                                test_list.append(test)
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
        self.repo_test_path = test['path']
        self.uuid = test['uuid']
        self.test_uuid = self.test_name + '_' + self.uuid
        self.test_path = os.path.join(self.output, self.test_uuid)
        self.logger = logging.getLogger('RUNNER.TestSetup')
        self.test_kind = args.kind

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
        if self.test_kind == 'manual':
            test_dir_path = os.path.join(self.repo_path, self.repo_test_path.rsplit("/", 1)[0])
            shutil.copytree(test_dir_path, self.test_path, symlinks=True)
            self.logger.info('Test copied to: %s' % self.test_path)
        else:
            if self.repo_path in self.test_path:
                self.logger.error("Cannot copy repository into itself. Please choose output directory outside repository path")
                sys.exit(1)
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
        self.test = test
        self.args = args
        self.output = os.path.realpath(args.output)
        self.test_def = test['path']
        self.test_name = os.path.splitext(self.test_def.split('/')[-1])[0]
        self.test_uuid = self.test_name + '_' + test['uuid']
        self.test_path = os.path.join(self.output, self.test_uuid)
        self.logger = logging.getLogger('RUNNER.TestDef')
        self.skip_install = args.skip_install
        self.is_manual = False
        if 'skip_install' in test:
            self.skip_install = test['skip_install']
        self.custom_params = None
        if 'parameters' in test:
            self.custom_params = test['parameters']
        if 'params' in test:
            self.custom_params = test['params']
        self.exists = False
        if os.path.isfile(self.test_def):
            self.exists = True
            with open(self.test_def, 'r') as f:
                self.testdef = yaml.safe_load(f)
                if self.testdef['metadata']['format'].startswith("Manual Test Definition"):
                    self.is_manual = True

    def definition(self):
        with open('%s/testdef.yaml' % self.test_path, 'w') as f:
            f.write(yaml.dump(self.testdef, encoding='utf-8', allow_unicode=True))

    def metadata(self):
        with open('%s/testdef_metadata' % self.test_path, 'w') as f:
            f.write(yaml.dump(self.testdef['metadata'], encoding='utf-8', allow_unicode=True))

    def run(self):
        if not self.is_manual:
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

    def get_test_run(self):
        if self.is_manual:
            return ManualTestRun(self.test, self.args)
        return AutomatedTestRun(self.test, self.args)

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
        self.logger = logging.getLogger('RUNNER.TestRun')
        self.test_timeout = args.timeout
        if 'timeout' in test:
            self.test_timeout = test['timeout']

    def run(self):
        raise NotImplementedError

    def check_result(self):
        raise NotImplementedError


class AutomatedTestRun(TestRun):
    def run(self):
        self.logger.info('Executing %s/run.sh' % self.test_path)
        shell_cmd = '%s/run.sh 2>&1 | tee %s/stdout.log' % (self.test_path, self.test_path)
        self.child = pexpect.spawn('/bin/sh', ['-c', shell_cmd])

    def check_result(self):
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


class ManualTestShell(cmd.Cmd):
    def __init__(self, test_dict, result_path):
        cmd.Cmd.__init__(self)
        self.test_dict = test_dict
        self.result_path = result_path
        self.current_step_index = 0
        self.steps = self.test_dict['run']['steps']
        self.expected = self.test_dict['run']['expected']
        self.prompt = "%s > " % self.test_dict['metadata']['name']
        self.result = None
        self.intro = """
        Welcome to manual test executor. Type 'help' for available commands.
        This shell is meant to be executed on your computer, not on the system
        under test. Please execute the steps from the test case, compare to
        expected result and record the test result as 'pass' or 'fail'. If there
        is an issue that prevents from executing the step, please record the result
        as 'skip'.
        """

    def do_quit(self, line):
        """
        Exit test execution
        """
        if self.result is not None:
            return True
        if line.find("-f") >= 0:
            self._record_result("skip")
            return True
        print "Test result not recorded. Use -f to force. Forced quit records result as 'skip'"

    do_EOF = do_quit

    def do_description(self, line):
        """
        Prints current test overall description
        """
        print self.test_dict['metadata']['description']

    def do_steps(self, line):
        """
        Prints all steps of the current test case
        """
        for index, step in enumerate(self.steps):
            print "%s. %s" % (index, step)

    def do_expected(self, line):
        """
        Prints all expected results of the current test case
        """
        for index, expected in enumerate(self.expected):
            print "%s. %s" % (index, expected)

    def do_current(self, line):
        """
        Prints current test step
        """
        self._print_step()

    do_start = do_current

    def do_next(self, line):
        """
        Prints next test step
        """
        if len(self.steps) > self.current_step_index + 1:
            self.current_step_index += 1
            self._print_step()

    def _print_step(self):
        print "%s. %s" % (self.current_step_index, self.steps[self.current_step_index])

    def _record_result(self, result):
        print "Recording %s in %s/stdout.log" % (result, self.result_path)
        with open("%s/stdout.log" % self.result_path, "a") as f:
            f.write("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s RESULT=%s>" %
                    (self.test_dict['metadata']['name'], result))

    def do_pass(self, line):
        """
        Records PASS as test result
        """
        self.result = "pass"
        self._record_result(self.result)
        return True

    def do_fail(self, line):
        """
        Records FAIL as test result
        """
        self.result = "fail"
        self._record_result(self.result)
        return True

    def do_skip(self, line):
        """
        Records SKIP as test result
        """
        self.result = "skip"
        self._record_result(self.result)
        return True


class ManualTestRun(TestRun, cmd.Cmd):
    def run(self):
        print self.test_name
        with open('%s/testdef.yaml' % self.test_path, 'r') as f:
            self.testdef = yaml.safe_load(f)

        ManualTestShell(self.testdef, self.test_path).cmdloop()

    def check_result(self):
        pass


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
        self.results['params'] = None
        with open(os.path.join(self.result_path, "testdef.yaml"), "r") as f:
           self.testdef = yaml.safe_load(f)
           if 'params' in self.testdef.keys():
               self.results['params'] = self.testdef['params']
        if 'parameters' in test.keys():
            self.results['params'].update(test['parameters'])
        if 'params' in test.keys():
            self.results['params'].update(test['params'])

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
        # Save test results to output/test_id/result.json
        with open('%s/result.json' % self.result_path, 'w') as f:
            json.dump([self.results], f, indent=4)

        # Collect test results of all tests in output/result.json
        feeds = []
        if os.path.isfile('%s/result.json' % self.output):
            with open('%s/result.json' % self.output, 'r') as f:
                feeds = json.load(f)

        feeds.append(self.results)
        with open('%s/result.json' % self.output, 'w') as f:
            json.dump(feeds, f, indent=4)

    def dict_to_csv(self):
        # Convert dict self.results['params'] to a string.
        test_params = ''
        if self.results['params']:
            params_dict = self.results['params']
            test_params = ';'.join(['%s=%s' % (k, v) for k, v in params_dict.iteritems()])

        for metric in self.results['metrics']:
            metric['test'] = self.results['test']
            metric['test_params'] = test_params

        # Save test results to output/test_id/result.csv
        fieldnames = ['test', 'test_case_id', 'result', 'measurement', 'units', 'test_params']
        with open('%s/result.csv' % self.result_path, 'w') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for metric in self.results['metrics']:
                writer.writerow(metric)

        # Collect test results of all tests in output/result.csv
        if not os.path.isfile('%s/result.csv' % self.output):
            with open('%s/result.csv' % self.output, 'w') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()

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
    parser.add_argument('-k', '--kind', default="automated", dest='kind',
                        choices=['automated', 'manual'],
                        help='''
                        Selects type of tests to be executed from the test plan.
                        Possible options: automated, manual
                        '''),
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

    args = get_args()
    if args.kind != "manual":
        if os.geteuid() != 0:
            logger.error("Sorry, you need to run this as root")
            sys.exit(1)

    # Generate test plan.
    test_plan = TestPlan(args)
    test_list = test_plan.test_list(args.kind)
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
        if test_def.exists:
            test_def.definition()
            test_def.metadata()
            test_def.run()

            # Run test.
            test_run = test_def.get_test_run()
            test_run.run()
            test_run.check_result()

            # Parse test output, save results in json and csv format.
            result_parser = ResultParser(test, args)
            result_parser.run()
        else:
            logger.warning("Requested test definition %s doesn't exist" % test['path'])

if __name__ == "__main__":
    main()
