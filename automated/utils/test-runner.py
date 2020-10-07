#!/usr/bin/env python3
import argparse
import csv
import cmd
import copy
import json
import logging
import netrc
import os
import re
import shlex
import shutil
import subprocess
import sys
import textwrap
import time
from uuid import uuid4
from distutils.spawn import find_executable


try:
    from squad_client.core.api import SquadApi
    from squad_client.shortcuts import submit_results
    from squad_client.core.models import Squad
    from urllib.parse import urlparse
except ImportError as e:
    logger = logging.getLogger('RUNNER')
    logger.warning('squad_client is needed if you want to upload to qa-reports')


try:
    import pexpect
    import yaml
except ImportError as e:
    print(e)
    print('Please run the below command to install modules required')
    print('pip3 install -r ${REPO_PATH}/automated/utils/requirements.txt')
    sys.exit(1)


class StoreDictKeyPair(argparse.Action):
    def __init__(self, option_strings, dest, nargs=None, **kwargs):
        self._nargs = nargs
        super(StoreDictKeyPair, self).__init__(option_strings, dest, nargs=nargs, **kwargs)

    def __call__(self, parser, namespace, values, option_string=None):
        my_dict = {}
        for kv in values:
            if "=" in kv:
                k, v = kv.split("=", 1)
                my_dict[k] = v
            else:
                print("Invalid parameter: %s" % kv)
        setattr(namespace, self.dest, my_dict)


# quit gracefully if the connection is closed by remote host
SSH_PARAMS = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=5"


def run_command(command, target=None):
    """ Run a shell command. If target is specified, ssh to the given target first. """

    run = command
    if target:
        run = 'ssh {} {} "{}"'.format(SSH_PARAMS, target, command)

    logger = logging.getLogger('RUNNER.run_command')
    logger.debug(run)
    if sys.version_info[0] < 3:
        return subprocess.check_output(shlex.split(run)).strip()
    else:
        return subprocess.check_output(shlex.split(run)).strip().decode('utf-8')


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
        self.overlay = args.overlay

    def apply_overlay(self, test_list):
        fixed_test_list = copy.deepcopy(test_list)
        logger = logging.getLogger('RUNNER.TestPlan.Overlay')
        with open(self.overlay) as f:
            data = yaml.load(f)

        if data.get('skip'):
            skip_tests = data['skip']
            for test in test_list:
                for skip_test in skip_tests:
                    if test['path'] == skip_test['path'] and test['repository'] == skip_test['repository']:
                        fixed_test_list.remove(test)
                        logger.info("Skipped: {}".format(test))
                    else:
                        continue

        if data.get('amend'):
            amend_tests = data['amend']
            for test in fixed_test_list:
                for amend_test in amend_tests:
                    if test['path'] == amend_test['path'] and test['repository'] == skip_test['repository']:
                        if amend_test.get('parameters'):
                            if test.get('parameters'):
                                test['parameters'].update(amend_test['parameters'])
                            else:
                                test['parameters'] = amend_test['parameters']
                            logger.info('Updated: {}'.format(test))
                        else:
                            logger.warning("'parameters' not found in {}, nothing to amend.".format(amend_test))

        if data.get('add'):
            add_tests = data['add']
            unique_add_tests = []
            for test in add_tests:
                if test not in unique_add_tests:
                    unique_add_tests.append(test)
                else:
                    logger.warning("Skipping duplicate test {}".format(test))

            for test in test_list:
                del test['uuid']

            for add_test in unique_add_tests:
                if add_test in test_list:
                    logger.warning("{} already included in test plan, do nothing.".format(add_test))
                else:
                    add_test['uuid'] = str(uuid4())
                    fixed_test_list.append(add_test)
                    logger.info("Added: {}".format(add_test))

        return fixed_test_list

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
                plan_version = test_plan['metadata'].get('format')
                self.logger.info('Test plan version: {}'.format(plan_version))
                tests = []
                if plan_version == "Linaro Test Plan v2":
                    tests = test_plan['tests'][kind]
                elif plan_version == "Linaro Test Plan v1" or plan_version is None:
                    for requirement in test_plan['requirements']:
                        if 'tests' in requirement.keys():
                            if requirement['tests'] and \
                                    kind in requirement['tests'].keys() and \
                                    requirement['tests'][kind]:
                                for test in requirement['tests'][kind]:
                                    tests.append(test)

                test_list = []
                unique_tests = []  # List of test hashes
                for test in tests:
                    test_hash = hash(json.dumps(test, sort_keys=True))
                    if test_hash in unique_tests:
                        # Test is already in the test_list; don't add it again.
                        self.logger.warning("Skipping duplicate test {}".format(test))
                        continue
                    unique_tests.append(test_hash)
                    test_list.append(test)
                for test in test_list:
                    test['uuid'] = str(uuid4())
            except KeyError as e:
                self.logger.error("%s is missing from test plan" % str(e))
                sys.exit(1)
        else:
            self.logger.error('Plese specify a test or test plan.')
            sys.exit(1)

        if self.overlay is None:
            return test_list
        else:
            return self.apply_overlay(test_list)


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
        if self.is_manual:
            self.runner = ManualTestRun(test, args)
        elif self.args.target is not None:
            self.runner = RemoteTestRun(test, args)
        else:
            self.runner = AutomatedTestRun(test, args)

    def definition(self):
        with open('%s/testdef.yaml' % self.test['test_path'], 'wb') as f:
            f.write(yaml.dump(self.testdef, encoding='utf-8', allow_unicode=True))

    def metadata(self):
        with open('%s/testdef_metadata' % self.test['test_path'], 'wb') as f:
            f.write(yaml.dump(self.testdef['metadata'], encoding='utf-8', allow_unicode=True))

    def mkrun(self):
        if not self.is_manual:
            with open('%s/run.sh' % self.test['test_path'], 'a') as f:
                f.write('#!/bin/sh\n')

                self.parameters = self.handle_parameters()
                if self.parameters:
                    for line in self.parameters:
                        f.write(line)

                f.write('set -e\n')
                f.write('set -x\n')
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
                    for step in steps:
                        command = step
                        if '--cmd' in step or '--shell' in step:
                            command = re.sub(r'\$(\d+)\b', r'\\$\1', step)
                        f.write('%s\n' % command)
                f.write('echo "<ENDRUN $TESTRUN_ID $UUID>"\n')

            os.chmod('%s/run.sh' % self.test['test_path'], 0o755)

    def run(self):
        self.runner.run()

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

        ret_val.append('###custom parameters from command line###\n')
        if self.args.test_def_params:
            for param_name, param_value in self.args.test_def_params.items():
                ret_val.append('%s=\'%s\'\n' % (param_name, param_value))
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
        self.child = pexpect.spawnu('/bin/sh', ['-c', shell_cmd])
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

        self.logger.info("Archiving test files")
        run_command(
            'tar -caf %s run.sh uuid automated/lib automated/bin automated/utils %s' %
            (tarball_name, self.test['tc_relative_dir']))

        self.logger.info("Creating test path")
        run_command("mkdir -p %s" % (self.test['target_test_path']), self.args.target)

        self.logger.info("Copying test archive to target host")
        run_command('scp %s ./%s %s:%s' % (SSH_PARAMS, tarball_name, self.args.target,
                                           self.test['target_test_path']))

        self.logger.info("Unarchiving test files on target")
        run_command("cd %s && tar -xf %s" % (self.test['target_test_path'],
                                             tarball_name), self.args.target)

        self.logger.info("Removing test file archive from target")
        run_command("rm %s/%s" % (self.test['target_test_path'],
                                  tarball_name), self.args.target)

    def run(self):
        self.copy_to_target()
        self.logger.info('Executing %s/run.sh remotely on %s' % (self.test['target_test_path'], self.args.target))
        shell_cmd = 'ssh %s %s "%s/run.sh 2>&1"' % (SSH_PARAMS, self.args.target, self.test['target_test_path'])
        self.logger.debug('shell_cmd: %s' % shell_cmd)
        output = open("%s/stdout.log" % self.test['test_path'], "w")
        self.child = pexpect.spawnu(shell_cmd)
        self.child.logfile = output
        self.check_result()


class ManualTestShell(cmd.Cmd):
    def __init__(self, test_dict, result_path, test_case_id):
        cmd.Cmd.__init__(self)
        self.test_dict = test_dict
        self.test_case_id = test_case_id
        self.result_path = result_path
        self.current_step_index = 0
        self.steps = self.test_dict['run']['steps']
        self.expected = self.test_dict['run']['expected']
        self.prompt = "%s[%s] > " % (self.test_dict['metadata']['name'], self.test_case_id)
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
        print("Test result not recorded. Use -f to force. Forced quit records result as 'skip'")

    do_EOF = do_quit

    def do_description(self, line):
        """
        Prints current test overall description
        """
        print(self.test_dict['metadata']['description'])

    def do_steps(self, line):
        """
        Prints all steps of the current test case
        """
        for index, step in enumerate(self.steps):
            print("%s. %s" % (index, step))

    def do_expected(self, line):
        """
        Prints all expected results of the current test case
        """
        for index, expected in enumerate(self.expected):
            print("%s. %s" % (index, expected))

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
        print("%s. %s" % (self.current_step_index, self.steps[self.current_step_index]))

    def _record_result(self, result):
        print("Recording %s in %s/stdout.log" % (result, self.result_path))
        with open("%s/stdout.log" % self.result_path, "a") as f:
            f.write("<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=%s RESULT=%s>" %
                    (self.test_case_id, result))

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
        print(self.test['test_name'])
        with open('%s/testdef.yaml' % self.test['test_path'], 'r') as f:
            self.testdef = yaml.safe_load(f)

        if 'name' in self.test:
            test_case_id = self.test['name']
        else:
            test_case_id = self.testdef['metadata']['name']

        ManualTestShell(self.testdef, self.test['test_path'], test_case_id).cmdloop()

    def check_result(self):
        pass


def get_packages(linux_distribution, target=None):
    """ Return a list of installed packages with versions

        linux_distribution is a string that may be 'debian',
            'ubuntu', 'centos', or 'fedora'.

        For example (ubuntu):
        'packages': ['acl-2.2.52-2',
                     'adduser-3.113+nmu3',
                     ...
                     'zlib1g:amd64-1:1.2.8.dfsg-2+b1',
                     'zlib1g-dev:amd64-1:1.2.8.dfsg-2+b1']

        (centos):
        "packages": ["acl-2.2.51-12.el7",
                     "apr-1.4.8-3.el7",
                     ...
                     "zlib-1.2.7-17.el7",
                     "zlib-devel-1.2.7-17.el7"
        ]
    """

    logger = logging.getLogger('RUNNER.get_packages')
    packages = []
    if linux_distribution in ['debian', 'ubuntu']:
        # Debian (apt) based system
        packages = run_command("dpkg-query -W -f '${package}-${version}\n'", target).splitlines()

    elif linux_distribution in ['centos', 'fedora']:
        # RedHat (rpm) based system
        packages = run_command("rpm -qa --qf '%{NAME}-%{VERSION}-%{RELEASE}\n'", target).splitlines()
    else:
        logger.warning("Unknown linux distribution '{}'; package list not populated.".format(linux_distribution))

    packages.sort()
    return packages


def get_environment(target=None, skip_collection=False):
    """ Return a dictionary with environmental information

        target: optional ssh host string to gather environment remotely.
        skip_collection: Skip data collection and return an empty dictionary.

        For example (on a HiSilicon D03):
        {
            "bios_version": "Hisilicon D03 UEFI 16.12 Release",
            "board_name": "D03",
            "board_vendor": "Huawei",
            "kernel": "4.9.0-20.gitedc2a1c.linaro.aarch64",
            "linux_distribution": "centos",
            "packages": [
                "GeoIP-1.5.0-11.el7",
                "NetworkManager-1.4.0-20.el7_3",
                ...
                "yum-plugin-fastestmirror-1.1.31-40.el7",
                "zlib-1.2.7-17.el7"
            ],
            "uname": "Linux localhost.localdomain 4.9.0-20.gitedc2a1c.linaro.aarch64 #1 SMP Wed Dec 14 17:50:15 UTC 2016 aarch64 aarch64 aarch64 GNU/Linux"
        }
    """

    environment = {}
    if skip_collection:
        return environment
    try:
        environment['linux_distribution'] = run_command(
            "grep ^ID= /etc/os-release", target).split('=')[-1].strip('"').lower()
    except subprocess.CalledProcessError:
        environment['linux_distribution'] = ""

    try:
        environment['kernel'] = run_command("uname -r", target)
    except subprocess.CalledProcessError:
        environment['kernel'] = ""

    try:
        environment['uname'] = run_command("uname -a", target)
    except subprocess.CalledProcessError:
        environment['uname'] = ""

    try:
        environment['bios_version'] = run_command(
            "cat /sys/devices/virtual/dmi/id/bios_version", target)
    except subprocess.CalledProcessError:
        environment['bios_version'] = ""

    try:
        environment['board_vendor'] = run_command(
            "cat /sys/devices/virtual/dmi/id/board_vendor", target)
    except subprocess.CalledProcessError:
        environment['board_vendor'] = ""

    try:
        environment['board_name'] = run_command(
            "cat /sys/devices/virtual/dmi/id/board_name", target)
    except subprocess.CalledProcessError:
        environment['board_name'] = ""

    try:
        environment['packages'] = get_packages(environment['linux_distribution'], target)
    except subprocess.CalledProcessError:
        environment['packages'] = []
    return environment


class ResultParser(object):
    def __init__(self, test, args):
        self.test = test
        self.args = args
        self.metrics = []
        self.results = {}
        self.results['test'] = test['test_name']
        self.results['id'] = test['test_uuid']
        self.results['test_plan'] = args.test_plan
        self.results['environment'] = get_environment(
            target=self.args.target, skip_collection=self.args.skip_environment)
        self.logger = logging.getLogger('RUNNER.ResultParser')
        self.results['params'] = {}
        self.pattern = None
        self.fixup = None
        self.qa_reports_server = args.qa_reports_server
        if args.qa_reports_token is not None:
            self.qa_reports_token = args.qa_reports_token
        else:
            self.qa_reports_token = os.environ.get("QA_REPORTS_TOKEN", get_token_from_netrc(self.qa_reports_server))
        self.qa_reports_project = args.qa_reports_project
        self.qa_reports_group = args.qa_reports_group
        self.qa_reports_env = args.qa_reports_env
        self.qa_reports_build_version = args.qa_reports_build_version
        self.qa_reports_disable_metadata = args.qa_reports_disable_metadata
        self.qa_reports_metadata = args.qa_reports_metadata
        self.qa_reports_metadata_file = args.qa_reports_metadata_file

        with open(os.path.join(self.test['test_path'], "testdef.yaml"), "r") as f:
            self.testdef = yaml.safe_load(f)
            self.results['name'] = ""
            if 'metadata' in self.testdef.keys() and \
                    'name' in self.testdef['metadata'].keys():
                self.results['name'] = self.testdef['metadata']['name']
            if 'params' in self.testdef.keys():
                self.results['params'] = self.testdef['params']
            if self.args.test_def_params:
                for param_name, param_value in self.args.test_def_params.items():
                    self.results['params'][param_name] = param_value
            if 'parse' in self.testdef.keys() and 'pattern' in self.testdef['parse'].keys():
                self.pattern = self.testdef['parse']['pattern']
                self.logger.info("Enabling log parse pattern: %s" % self.pattern)
                if 'fixupdict' in self.testdef['parse'].keys():
                    self.fixup = self.testdef['parse']['fixupdict']
                    self.logger.info("Enabling log parse pattern fixup: %s" % self.fixup)
        if 'parameters' in test.keys():
            self.results['params'].update(test['parameters'])
        if 'params' in test.keys():
            self.results['params'].update(test['params'])
        if 'version' in test.keys():
            self.results['version'] = test['version']
        else:
            path = os.getcwd()
            os.chdir(self.test['test_path'])
            if sys.version_info[0] < 3:
                test_version = subprocess.check_output("git rev-parse HEAD", shell=True)
            else:
                test_version = subprocess.check_output("git rev-parse HEAD", shell=True).decode('utf-8')
            self.results['version'] = test_version.rstrip()
            os.chdir(path)
        self.lava_run = args.lava_run
        if self.lava_run and not find_executable('lava-test-case'):
            self.logger.info("lava-test-case not found, '-l' or '--lava_run' option ignored'")
            self.lava_run = False

    def run(self):
        self.parse_stdout()
        if self.pattern:
            self.parse_pattern()
        # If 'metrics' is empty, add 'no-result-found fail'.
        if not self.metrics:
            self.metrics = [{'test_case_id': 'no-result-found', 'result': 'fail', 'measurement': '', 'units': ''}]
        self.results['metrics'] = self.metrics
        self.dict_to_json()
        self.dict_to_csv()
        self.send_to_qa_reports()
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
                            try:
                                data['measurement'] = float(measurement_match.group(1))
                            except ValueError as e:
                                pass
                        if units_match:
                            data['units'] = units_match.group(1)

                    self.metrics.append(data.copy())

                    if self.lava_run:
                        self.send_to_lava(data)

    def parse_pattern(self):
        with open('%s/stdout.log' % self.test['test_path'], 'r') as f:
            rex_pattern = re.compile(r'%s' % self.pattern)
            for line in f:
                data = {}
                m = rex_pattern.search(line)
                if m:
                    data = m.groupdict()
                    for x in ['measurement', 'units']:
                        if x not in data:
                            data[x] = ''
                    if self.fixup and data['result'] in self.fixup:
                        data['result'] = self.fixup[data['result']]

                    self.metrics.append(data.copy())

                    if self.lava_run:
                        self.send_to_lava(data)

    def send_to_lava(self, data):
        cmd = 'lava-test-case {} --result {}'.format(data['test_case_id'], data['result'])
        if data['measurement']:
            cmd = '{} --measurement {} --units {}'.format(cmd, data['measurement'], data['units'])
        self.logger.debug('lava-run: cmd: {}'.format(cmd))
        subprocess.call(shlex.split(cmd))

    def send_to_qa_reports(self):
        if None in (self.qa_reports_server, self.qa_reports_token, self.qa_reports_group, self.qa_reports_project, self.qa_reports_build_version, self.qa_reports_env):
            self.logger.warning("All parameters for qa reports are not set, results will not be pushed to qa reports")
            return

        SquadApi.configure(
            url=self.qa_reports_server, token=self.qa_reports_token
        )
        tests = {}
        metrics = {}
        for metric in self.metrics:
            if metric['measurement'] != "":
                metrics["{}/{}".format(self.test['test_name'], metric['test_case_id'])] = metric['measurement']
            else:
                tests["{}/{}".format(self.test['test_name'], metric['test_case_id'])] = metric['result']

        with open("{}/stdout.log".format(self.test['test_path']), "r") as logfile:
            log = logfile.read()

        metadata = {}
        if not self.qa_reports_disable_metadata:
            if self.qa_reports_metadata:
                metadata.update(self.qa_reports_metadata)
            if self.qa_reports_metadata_file:
                try:
                    with open(self.qa_reports_metadata_file, "r") as metadata_file:
                        loaded_metadata = yaml.load(metadata_file, Loader=yaml.SafeLoader)
                        # check if loaded metadata is key=value and both are strings
                        for key, value in loaded_metadata.items():
                            if type(key) == str and type(value) == str:
                                # only update metadata with simple keys
                                # ignore all other items in the dictionary
                                metadata.update({key: value})
                            else:
                                self.logger.warning("Ignoring key: %s" % key)
                except FileNotFoundError:
                    self.logger.warning("Metadata file not found")
                except PermissionError:
                    self.logger.warning("Insufficient permissions to open metadata file")
        if submit_results(
                group_project_slug="{}/{}".format(self.qa_reports_group, self.qa_reports_project),
                build_version=self.qa_reports_build_version,
                env_slug=self.qa_reports_env,
                tests=tests,
                metrics=metrics,
                log=log,
                metadata=metadata,
                attachments=None):
            self.logger.info("Results pushed to QA Reports")
        else:
            self.logger.warning("Results upload to QA Reports failed!")

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
            test_params = ';'.join(['%s=%s' % (k, v) for k, v in params_dict.items()])

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


def get_token_from_netrc(qa_reports_server):
    if qa_reports_server is None:
        return
    parse = urlparse(qa_reports_server)
    netrc_local = netrc.netrc()
    authTokens = netrc_local.authenticators("{}".format(parse.netloc))
    if authTokens is not None:
        hostname, username, authToken = authTokens
        return authToken
    # Unable to find Token hence returning None
    return


def get_args():
    parser = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter)
    parser.add_argument('-o', '--output', default=os.getenv("HOME", "") + '/output', dest='output',
                        help=textwrap.dedent('''\
                        specify a directory to store test and result files.
                        Default: $HOME/output
                        '''))
    parser.add_argument('-p', '--test_plan', default=None, dest='test_plan',
                        help=textwrap.dedent('''\
                        specify an test plan file which has tests and related
                        params listed in yaml format.
                        '''))
    parser.add_argument('-d', '--test_def', default=None, dest='test_def',
                        help=textwrap.dedent('''\
                        base on test definition repo location, specify relative
                        path to the test definition to run.
                        Format example: "ubuntu/smoke-tests-basic.yaml"
                        '''))
    parser.add_argument('-r', '--test_def_params', default={}, dest='test_def_params',
                        action=StoreDictKeyPair, nargs="+", metavar="KEY=VALUE",
                        help=textwrap.dedent('''\
                        Set additional parameters when using test definition without
                        a test plan. The name values are set similarily to environment
                        variables:
                        --test_def_params KEY1=VALUE1 KEY2=VALUE2 ...
                        '''))
    parser.add_argument('-k', '--kind', default="automated", dest='kind',
                        choices=['automated', 'manual'],
                        help=textwrap.dedent('''\
                        Selects type of tests to be executed from the test plan.
                        Possible options: automated, manual
                        '''))
    parser.add_argument('-t', '--timeout', type=int, default=None,
                        dest='timeout', help='Specify test timeout')
    parser.add_argument('-g', '--target', default=None,
                        dest='target', help=textwrap.dedent('''\
                        Specify SSH target to execute tests.
                        Format: user@host
                        Note: ssh authentication must be paswordless
                        '''))
    parser.add_argument('-s', '--skip_install', dest='skip_install',
                        default=False, action='store_true',
                        help='skip install section defined in test definition.')
    parser.add_argument('-e', '--skip_environment', dest='skip_environment',
                        default=False, action='store_true',
                        help='skip environmental data collection (board name, distro, etc)')
    parser.add_argument('-l', '--lava_run', dest='lava_run',
                        default=False, action='store_true',
                        help='send test result to LAVA with lava-test-case.')
    parser.add_argument('-O', '--overlay', default=None,
                        dest='overlay', help=textwrap.dedent('''\
                        Specify test plan ovelay file to:
                        * skip tests
                        * amend test parameters
                        * add new tests
                        '''))
    parser.add_argument('-v', '--verbose', action='store_true', dest='verbose',
                        default=False, help='Set log level to DEBUG.')
    parser.add_argument(
        "--qa-reports-server",
        dest="qa_reports_server",
        default=None,
        help="qa reports server where the results have to be sent",
    )
    parser.add_argument(
        "--qa-reports-token",
        dest="qa_reports_token",
        default=None,
        help="qa reports token to upload the results to qa_reports_server",
    )
    parser.add_argument(
        "--qa-reports-project",
        dest="qa_reports_project",
        default=None,
        help="qa reports projects to which the results have to be uploaded",
    )
    parser.add_argument(
        "--qa-reports-group",
        dest="qa_reports_group",
        default=None,
        help="qa reports group in which the results have to be stored",
    )
    parser.add_argument(
        "--qa-reports-env",
        dest="qa_reports_env",
        default=None,
        help="qa reports environment for the results that have to be stored",
    )
    parser.add_argument(
        "--qa-reports-build-version",
        dest="qa_reports_build_version",
        default=None,
        help="qa reports build id for the result set",
    )
    parser.add_argument(
        "--qa-reports-disable-metadata",
        dest="qa_reports_disable_metadata",
        default=False,
        action='store_true',
        help="Disable sending metadata to SQUAD. Default: false",
    )
    parser.add_argument(
        "--qa-reports-metadata",
        dest="qa_reports_metadata",
        default={},
        action=StoreDictKeyPair,
        nargs="+",
        metavar="KEY=VALUE",
        help="List of metadata key=value pairs to be sent to SQUAD",
    )
    parser.add_argument(
        "--qa-reports-metadata-file",
        dest="qa_reports_metadata_file",
        default=None,
        help="YAML file that defines metadata to be reported to SQUAD",
    )

    args = parser.parse_args()
    return args


def main():
    args = get_args()

    # Setup logger.
    logger = logging.getLogger('RUNNER')
    logger.setLevel(logging.INFO)
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)
    formatter = logging.Formatter('%(asctime)s - %(name)s: %(levelname)s: %(message)s')
    ch.setFormatter(formatter)
    logger.addHandler(ch)

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
            run_command("exit", args.target)
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
        if args.target is not None:
            # Get relative directory path of yaml file for partial file copy.
            # '-d' takes any relative paths to the yaml file, so get the realpath first.
            tc_realpath = os.path.realpath(test['path'])
            tc_dirname = os.path.dirname(tc_realpath)
            test['tc_relative_dir'] = '%s%s' % (args.kind, tc_dirname.split(args.kind)[1])
            target_user_home = run_command("echo $HOME", args.target)
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
            test_def.mkrun()

            # Run test.
            test_def.run()

            # Parse test output, save results in json and csv format.
            result_parser = ResultParser(test, args)
            result_parser.run()
        else:
            logger.warning("Requested test definition %s doesn't exist" % test['path'])


if __name__ == "__main__":
    main()
