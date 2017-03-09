#!/usr/bin/env python
import argparse
import csv
import cmd
import json
import logging
import os
import re
import shlex
import shutil
import subprocess
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


SSH_PARAMS = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"


def call_ssh(args):
    ssh_cmd = "ssh %s %s" % (SSH_PARAMS, args)
    ssh_output = subprocess.check_output(shlex.split(ssh_cmd)).strip()
    return ssh_output


class TestPlan(object):
    """
    Analysis args specified, then generate test plan.
    """

    def __init__(self, args):
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
        self.test = test
        self.args = args
        self.logger = logging.getLogger('RUNNER.TestSetup')
        self.test_kind = args.kind
        self.test_version = test.get('version', None)

    def validate_env(self):
        # Inspect if environment set properly.
        try:
            self.repo_path = os.environ['REPO_PATH']
        except KeyError:
            self.logger.error('KeyError: REPO_PATH')
            self.logger.error("Please run '. ./bin/setenv.sh' to setup test environment")
            sys.exit(1)

    def create_dir(self):
        if not os.path.exists(self.test['output']):
            os.makedirs(self.test['output'])
            self.logger.info('Output directory created: %s' % self.test['output'])

    def copy_test_repo(self):
        self.validate_env()
        shutil.rmtree(self.test['test_path'], ignore_errors=True)
        if self.repo_path in self.test['test_path']:
            self.logger.error("Cannot copy repository into itself. Please choose output directory outside repository path")
            sys.exit(1)
        shutil.copytree(self.repo_path, self.test['test_path'], symlinks=True)
        self.logger.info('Test repo copied to: %s' % self.test['test_path'])

    def checkout_version(self):
        if self.test_version:
            path = os.getcwd()
            os.chdir(self.test['test_path'])
            subprocess.call("git checkout %s" % self.test_version, shell=True)
            os.chdir(path)

    def create_uuid_file(self):
        with open('%s/uuid' % self.test['test_path'], 'w') as f:
            f.write(self.test['uuid'])


class TestDefinition(object):
    """
    Convert test definition to testdef.yaml, testdef_metadata and run.sh.
    """

    def __init__(self, test, args):
        self.test = test
        self.args = args
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
        if os.path.isfile(self.test['path']):
            self.exists = True
            with open(self.test['path'], 'r') as f:
                self.testdef = yaml.safe_load(f)
                if self.testdef['metadata']['format'].startswith("Manual Test Definition"):
                    self.is_manual = True

    def definition(self):
        with open('%s/testdef.yaml' % self.test['test_path'], 'w') as f:
            f.write(yaml.dump(self.testdef, encoding='utf-8', allow_unicode=True))

    def metadata(self):
        with open('%s/testdef_metadata' % self.test['test_path'], 'w') as f:
            f.write(yaml.dump(self.testdef['metadata'], encoding='utf-8', allow_unicode=True))

    def run(self):
        if not self.is_manual:
            with open('%s/run.sh' % self.test['test_path'], 'a') as f:
                f.write('#!/bin/sh\n')

                self.parameters = self.handle_parameters()
                if self.parameters:
                    for line in self.parameters:
                        f.write(line)

                f.write('set -e\n')
                f.write('export TESTRUN_ID=%s\n' % self.testdef['metadata']['name'])
                if self.args.target is None:
                    f.write('cd %s\n' % (self.test['test_path']))
                else:
                    f.write('cd %s\n' % (self.test['target_test_path']))
                f.write('UUID=`cat uuid`\n')
                f.write('echo "<STARTRUN $TESTRUN_ID $UUID>"\n')
                f.write('export PATH=/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin\n')
                steps = self.testdef['run'].get('steps', [])
                if steps:
                    for cmd in steps:
                        if '--cmd' in cmd or '--shell' in cmd:
                            cmd = re.sub(r'\$(\d+)\b', r'\\$\1', cmd)
                        f.write('%s\n' % cmd)
                f.write('echo "<ENDRUN $TESTRUN_ID $UUID>"\n')

            os.chmod('%s/run.sh' % self.test['test_path'], 0755)

    def get_test_run(self):
        if self.is_manual:
            return ManualTestRun(self.test, self.args)
        if self.args.target is None:
            return AutomatedTestRun(self.test, self.args)
        return RemoteTestRun(self.test, self.args)

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
        self.test = test
        self.args = args
        self.logger = logging.getLogger('RUNNER.TestRun')
        self.test_timeout = self.args.timeout
        if 'timeout' in test:
            self.test_timeout = test['timeout']

    def run(self):
        raise NotImplementedError

    def check_result(self):
        raise NotImplementedError


class AutomatedTestRun(TestRun):
    def run(self):
        self.logger.info('Executing %s/run.sh' % self.test['test_path'])
        shell_cmd = '%s/run.sh 2>&1 | tee %s/stdout.log' % (self.test['test_path'], self.test['test_path'])
        self.child = pexpect.spawn('/bin/sh', ['-c', shell_cmd])
        self.check_result()

    def check_result(self):
        if self.test_timeout:
            self.logger.info('Test timeout: %s' % self.test_timeout)
            test_end = time.time() + self.test_timeout

        while self.child.isalive():
            if self.test_timeout and time.time() > test_end:
                self.logger.warning('%s test timed out, killing test process...' % self.test['test_uuid'])
                self.child.terminate(force=True)
                break
            try:
                self.child.expect('\r\n')
                print(self.child.before)
            except pexpect.TIMEOUT:
                continue
            except pexpect.EOF:
                self.logger.info('%s test finished.\n' % self.test['test_uuid'])
                break


class RemoteTestRun(AutomatedTestRun):
    def copy_to_target(self):
        os.chdir(self.test['test_path'])
        tarball_name = "target-test-files.tar"
        tar_cmd = 'tar -caf %s run.sh uuid automated/lib automated/bin automated/utils %s' % (tarball_name, self.test['tc_relative_dir'])
        subprocess.call(shlex.split(tar_cmd))
        create_target_test_path_cmd = '%s "mkdir -p %s"' % (self.args.target, self.test['target_test_path'])
        call_ssh(create_target_test_path_cmd)
        scp_cmd = 'scp %s ./%s %s:%s' % (SSH_PARAMS, tarball_name, self.args.target, self.test['target_test_path'])
        self.logger.info('Pushing test files to target with command: %s' % scp_cmd)
        subprocess.call(shlex.split(scp_cmd))
        uncompress_cmd = '%s "cd %s && tar -xf %s"' % (self.args.target, self.test['target_test_path'], tarball_name)
        self.logger.info('Uncompressing test files on target with command: %s' % uncompress_cmd)
        call_ssh(uncompress_cmd)
        delete_tarball_cmd = "%s rm %s/%s" % (self.args.target, self.test['target_test_path'], tarball_name)
        self.logger.info("Deleting remote tarball: %s" % delete_tarball_cmd)
        call_ssh(delete_tarball_cmd)

    def run(self):
        self.copy_to_target()
        self.logger.info('Executing %s/run.sh remotely on %s' % (self.test['target_test_path'], self.args.target))
        shell_cmd = 'ssh %s %s "%s/run.sh 2>&1"' % (SSH_PARAMS, self.args.target, self.test['target_test_path'])
        self.logger.debug('shell_cmd: %s' % shell_cmd)
        output = open("%s/stdout.log" % self.test['test_path'], "w")
        self.child = pexpect.spawn(shell_cmd)
        self.child.logfile = output
        self.check_result()


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
        print self.test['test_name']
        with open('%s/testdef.yaml' % self.test['test_path'], 'r') as f:
            self.testdef = yaml.safe_load(f)

        ManualTestShell(self.testdef, self.test['test_path']).cmdloop()

    def check_result(self):
        pass


class ResultParser(object):
    def __init__(self, test, args):
        self.test = test
        self.args = args
        self.metrics = []
        self.results = {}
        self.results['test'] = test['test_name']
        self.results['id'] = test['test_uuid']
        self.logger = logging.getLogger('RUNNER.ResultParser')
        self.results['params'] = {}
        with open(os.path.join(self.test['test_path'], "testdef.yaml"), "r") as f:
            self.testdef = yaml.safe_load(f)
            self.results['name'] = ""
            if 'metadata' in self.testdef.keys() and \
                    'name' in self.testdef['metadata'].keys():
                self.results['name'] = self.testdef['metadata']['name']
            if 'params' in self.testdef.keys():
                self.results['params'] = self.testdef['params']
        if 'parameters' in test.keys():
            self.results['params'].update(test['parameters'])
        if 'params' in test.keys():
            self.results['params'].update(test['params'])
        if 'version' in test.keys():
            self.results['version'] = test['version']
        else:
            path = os.getcwd()
            os.chdir(self.test['test_path'])
            test_version = subprocess.check_output("git rev-parse HEAD", shell=True)
            self.results['version'] = test_version.rstrip()
            os.chdir(path)

    def run(self):
        self.parse_stdout()
        self.dict_to_json()
        self.dict_to_csv()
        self.logger.info('Result files saved to: %s' % self.test['test_path'])
        print('--- Printing result.csv ---')
        with open('%s/result.csv' % self.test['test_path']) as f:
            print(f.read())

    def parse_stdout(self):
        with open('%s/stdout.log' % self.test['test_path'], 'r') as f:
            test_case_re = re.compile("TEST_CASE_ID=(.*)")
            result_re = re.compile("RESULT=(.*)")
            measurement_re = re.compile("MEASUREMENT=(.*)")
            units_re = re.compile("UNITS=(.*)")
            for line in f:
                if re.match(r'\<(|LAVA_SIGNAL_TESTCASE )TEST_CASE_ID=.*', line):
                    line = line.strip('\n').strip('\r').strip('<>').split(' ')
                    data = {'test_case_id': '',
                            'result': '',
                            'measurement': '',
                            'units': ''}

                    for string in line:
                        test_case_match = test_case_re.match(string)
                        result_match = result_re.match(string)
                        measurement_match = measurement_re.match(string)
                        units_match = units_re.match(string)
                        if test_case_match:
                            data['test_case_id'] = test_case_match.group(1)
                        if result_match:
                            data['result'] = result_match.group(1)
                        if measurement_match:
                            data['measurement'] = measurement_match.group(1)
                        if units_match:
                            data['units'] = units_match.group(1)

                    self.metrics.append(data.copy())

        # Mark test run as fail when no result found.
        if not self.metrics:
            self.metrics = [{'test_case_id': 'test-run', 'result': 'fail', 'measurement': '', 'units': ''}]

        self.results['metrics'] = self.metrics

    def dict_to_json(self):
        # Save test results to output/test_id/result.json
        with open('%s/result.json' % self.test['test_path'], 'w') as f:
            json.dump([self.results], f, indent=4)

        # Collect test results of all tests in output/result.json
        feeds = []
        if os.path.isfile('%s/result.json' % self.test['output']):
            with open('%s/result.json' % self.test['output'], 'r') as f:
                feeds = json.load(f)

        feeds.append(self.results)
        with open('%s/result.json' % self.test['output'], 'w') as f:
            json.dump(feeds, f, indent=4)

    def dict_to_csv(self):
        # Convert dict self.results['params'] to a string.
        test_params = ''
        if self.results['params']:
            params_dict = self.results['params']
            test_params = ';'.join(['%s=%s' % (k, v) for k, v in params_dict.iteritems()])

        for metric in self.results['metrics']:
            metric['name'] = self.results['name']
            metric['test_params'] = test_params

        # Save test results to output/test_id/result.csv
        fieldnames = ['name', 'test_case_id', 'result', 'measurement', 'units', 'test_params']
        with open('%s/result.csv' % self.test['test_path'], 'w') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for metric in self.results['metrics']:
                writer.writerow(metric)

        # Collect test results of all tests in output/result.csv
        if not os.path.isfile('%s/result.csv' % self.test['output']):
            with open('%s/result.csv' % self.test['output'], 'w') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)
                writer.writeheader()

        with open('%s/result.csv' % self.test['output'], 'a') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            for metric in self.results['metrics']:
                writer.writerow(metric)


def get_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('-o', '--output', default=os.getenv("HOME") + '/output', dest='output',
                        help='''
                        specify a directory to store test and result files.
                        Default: $HOME/output
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
    parser.add_argument('-g', '--target', default=None,
                        dest='target', help='''
                        Specify SSH target to execute tests.
                        Format: user@host
                        Note: ssh authentication must be paswordless
                        ''')
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
    logger.debug('Test job arguments: %s' % args)
    if args.kind != "manual" and args.target is None:
        if os.geteuid() != 0:
            logger.error("Sorry, you need to run this as root")
            sys.exit(1)

    # Validate target argument format and connectivity.
    if args.target:
        rex = re.compile('.+@.+')
        if not rex.match(args.target):
            logger.error('Usage: -g username@host')
            sys.exit(1)
        if pexpect.which('ssh') is None:
            logger.error('openssh client must be installed on the host.')
            sys.exit(1)
        try:
            call_ssh("%s exit" % args.target)
        except subprocess.CalledProcessError as e:
            logger.error('ssh login failed.')
            print(e)
            sys.exit(1)

    # Generate test plan.
    test_plan = TestPlan(args)
    test_list = test_plan.test_list(args.kind)
    logger.info('Tests to run:')
    for test in test_list:
        print(test)

    # Run tests.
    for test in test_list:
        # Set and save test params to test dictionary.
        test['test_name'] = os.path.splitext(test['path'].split('/')[-1])[0]
        test['test_uuid'] = '%s_%s' % (test['test_name'], test['uuid'])
        test['output'] = os.path.realpath(args.output)
        if args.target is not None and '-o' not in sys.argv:
            test['output'] = os.path.join(test['output'], args.target)
        test['test_path'] = os.path.join(test['output'], test['test_uuid'])
        # Get relative directory path of yaml file for file copy.
        # '-d' takes any relative paths to the yaml file, so get the realpath first.
        tc_realpath = os.path.realpath(test['path'])
        tc_dirname = os.path.dirname(tc_realpath)
        test['tc_relative_dir'] = '%s%s' % (args.kind, tc_dirname.split(args.kind)[1])
        if args.target is not None:
            target_user_home_cmd = '%s "echo $HOME"' % args.target
            target_user_home = call_ssh(target_user_home_cmd)
            test['target_test_path'] = '%s/output/%s' % (target_user_home, test['test_uuid'])
        logger.debug('Test parameters: %s' % test)

        # Create directories and copy files needed.
        setup = TestSetup(test, args)
        setup.create_dir()
        setup.copy_test_repo()
        setup.checkout_version()
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

            # Parse test output, save results in json and csv format.
            result_parser = ResultParser(test, args)
            result_parser.run()
        else:
            logger.warning("Requested test definition %s doesn't exist" % test['path'])

if __name__ == "__main__":
    main()
