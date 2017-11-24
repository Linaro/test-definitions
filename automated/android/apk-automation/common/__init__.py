import csv
import datetime
import json
import logging
import math
import os
import requests
import shutil
import subprocess
import sys
import time
import urlparse
from com.dtmilano.android.viewclient import ViewClient


class ApkTestRunner(object):
    def __init__(self, config):
        self.config = config

        self.logger = logging.getLogger(self.config['name'])
        self.logger.setLevel(logging.INFO)
        if self.config.get('verbose') and self.config['verbose']:
            self.logger.setLevel(logging.DEBUG)
        ch = logging.StreamHandler()
        ch.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        ch.setFormatter(formatter)
        self.logger.addHandler(ch)

        self.config['output'] = os.getenv("OUTPUT", "./output/%s" % config['name'])
        if os.path.exists(self.config['output']):
            suffix = datetime.datetime.now().strftime('%Y%m%d%H%M%S')
            shutil.move(self.config['output'], '%s-%s' % (self.config['output'], suffix))
        os.makedirs(self.config['output'])
        self.results = []

        serialno = os.getenv('ANDROID_SERIAL')
        if serialno is None:
            serialno = '.*'
        kwargs1 = {
            'serialno': serialno,
            'verbose': True,
            'ignoresecuredevice': False}
        self.logger.debug('VC kwargs1: %s' % kwargs1)
        self.device, self.serialno = ViewClient.connectToDeviceOrExit(**kwargs1)
        kwargs2 = {
            'startviewserver': True,
            'forceviewserveruse': False,
            'autodump': False,
            'ignoreuiautomatorkilled': True,
            'compresseddump': False}
        self.logger.debug('VC kwargs2: %s' % kwargs2)
        self.vc = ViewClient(self.device, self.serialno, **kwargs2)

    def run(self):
        self.validate()

        for i in range(1, self.config['loops'] + 1):
            try:
                self.logger.info('Running iteration [%s/%s]' % (i, self.config['loops']))
                self.config['itr'] = i
                self.logger.info('Test config: %s' % self.config)
                self.setUp()
                self.execute()
                self.parseResult()
                self.take_screencap()
                self.tearDown()
            except Exception as e:
                self.take_screencap()
                self.report_result(self.config['name'], 'fail')
                self.logger.error(e, exc_info=True)
                sys.exit(1)

        self.collect_log()
        self.result_post_processing()

    def report_result(self, name, result, score=None, units=None):
        if score is not None:
            score = float(score)
        if units is not None:
            units = str(units)

        tc_name = str(name)
        if self.config['loops'] > 1 and self.config['itr'] != 'stats':
            tc_name = '%s-itr%s' % (name, self.config['itr'])

        result_string = '%s %s %s %s' % (tc_name, result, score, units)
        if score is None:
            result_string = '%s %s' % (tc_name, result)
        if score is not None and units is None:
            result_string = '%s %s %s' % (tc_name, result, score)

        self.logger.info('TestResult: %s' % result_string)
        with open('%s/result.txt' % self.config['output'], 'a') as f:
            f.write('%s\n' % result_string)

        # Save result to results for post processing.
        result = {'itr': self.config['itr'],
                  'test_case_id': str(name),
                  'result': str(result),
                  'measurement': score,
                  'units': units}
        self.results.append(result)

    def statistics_result(self):
        if self.config['loops'] == 1:
            return

        self.config['itr'] = 'stats'

        tc_list = []
        for result in self.results:
            if result['measurement'] is not None:
                tc_list.append(result['test_case_id'])
        tc_list = set(tc_list)

        for tc in tc_list:
            ms_list = []
            for result in self.results:
                if result['test_case_id'] == tc:
                    ms_list.append(result['measurement'])

            units = ''
            for result in self.results:
                if result['test_case_id'] == tc:
                    units = result['units']
                    break

            # Calculate and report population standard deviation and standard error.
            mean = sum(ms_list) / len(ms_list)
            variance = sum([(e - mean) ** 2 for e in ms_list]) / len(ms_list)
            pstdev = math.sqrt(variance)
            pstderr = pstdev / math.sqrt(len(ms_list))
            self.report_result('%s-min' % tc, 'pass', min(ms_list), units)
            self.report_result('%s-max' % tc, 'pass', max(ms_list), units)
            self.report_result('%s-mean' % tc, 'pass', mean, units)
            self.report_result('%s-sigma' % tc, 'pass', pstdev, units)
            self.report_result('%s-stderr' % tc, 'pass', pstderr, units)

    def result_post_processing(self):
        self.statistics_result()

        # Save results to output/name/name-result.csv.
        fieldnames = ['itr', 'test_case_id', 'result', 'measurement', 'units']
        with open('%s/result.csv' % self.config['output'], 'w') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()
            for result in self.results:
                writer.writerow(result)
        self.logger.info('Result saved to %s/result.csv' % self.config['output'])

        # Save results to output/name/name-result.json
        with open('%s/result.json' % self.config['output'], 'w') as f:
            json.dump([self.results], f, indent=4)
        self.logger.info('Result saved to %s/result.json' % self.config['output'])

    def dump_always(self):
        success = False
        while not success:
            try:
                time.sleep(5)
                self.vc.dump()
                success = True
            except RuntimeError:
                print("Got RuntimeError when call vc.dump()")
                time.sleep(5)
            except ValueError:
                print("Got ValueError when call vc.dump()")
                time.sleep(5)

    def call_adb(self, args):
        self.logger.debug("calling")
        self.logger.debug("adb %s" % args)
        try:
            # Need to set shell=True to save output to host directly.
            subprocess.check_call("adb %s" % args, shell=True)
        except (OSError, subprocess.CalledProcessError) as e:
            print(e)
            sys.exit(1)

    def validate(self):
        if self.config['apk_file_name'] is None:
            self.logger.error("APK file name not set")
            sys.exit(1)

        if self.config['apk_package'] is None:
            self.logger.error("APK package name not set")
            sys.exit(1)

        if self.config['activity'] is None:
            self.logger.error("Activity name not set")
            sys.exit(1)

    def download_apk(self, apk_name):
        # download APK if not already downloaded
        apk_path = os.path.join(os.path.abspath(self.config['apk_dir']),
                                apk_name)
        if not os.path.isfile(apk_path):
            # create directory for downloaded files
            if not os.path.exists(os.path.dirname(apk_path)):
                os.makedirs(os.path.dirname(apk_path))

            if self.config['base_url'].startswith("scp://"):
                # like scp://user@host:/abs_path
                base_url = self.config['base_url']

                remote_dir = base_url.split(":")[2]
                user_host = base_url.split(":")[1].replace("/", "")
                host = user_host.split("@")[1]
                user = user_host.split("@")[0]

                remote_path = "%s/%s" % (remote_dir, apk_name)
                scp_cmdline = "scp %s@%s:%s %s" % (user, host,
                                                   remote_path, apk_path)
                ret = os.system(scp_cmdline)
                if ret != 0:
                    self.logger.info('Failed to run command: %s' % scp_cmdline)
                    sys.exit(1)
            else:
                apk_url = urlparse.urljoin(self.config['base_url'], apk_name)
                self.logger.info('Start downloading file: %s' % apk_url)
                r = requests.get(apk_url, stream=True)
                if r.status_code == 200:
                    with open(apk_path, 'wb') as f:
                        r.raw.decode_content = True
                        shutil.copyfileobj(r.raw, f)
                else:
                    self.logger.info('Failed to download file: %s' % apk_url)
                    sys.exit(1)
        else:
            self.logger.info('APK file already exists: %s' % apk_name)

    def install_apk(self, apk_name):
        apk_path = os.path.join(os.path.abspath(self.config['apk_dir']), apk_name)
        self.logger.info('Installing %s' % os.path.basename(apk_path))
        self.call_adb("install %s" % apk_path)

    def uninstall_apk(self, package):
        install_packages = subprocess.check_output(['adb', 'shell', 'pm', 'list', 'packages'])
        if package in install_packages:
            self.logger.info('Stopping %s' % package)
            self.call_adb("shell am force-stop %s" % package)

            self.logger.info('Uninstalling %s' % package)
            self.call_adb("shell pm uninstall %s" % package)

    def take_screencap(self):
        screencap_file = '/data/local/tmp/%s-itr%s.png' % (self.config['name'], self.config['itr'])
        self.call_adb('shell screencap %s' % screencap_file)
        self.logger.info('Pulling %s to output directory...' % screencap_file)
        self.call_adb('pull %s %s' % (screencap_file, self.config['output']))

    def collect_log(self):
        self.logger.info("Saving logcat.log, logcat-events.log and dmesg.log to output directory...")
        self.call_adb('logcat -d -v time > %s/logcat.log' % self.config['output'])
        self.call_adb('logcat -d -b events -v time > %s/logcat-events.log' % self.config['output'])
        self.call_adb('shell dmesg > %s/dmesg.log' % self.config['output'])

    def set_performance_governor(self, target_governor="performance"):
        f_scaling_governor = ('/sys/devices/system/cpu/'
                              'cpu0/cpufreq/scaling_governor')
        f_governor_backup = '/data/local/tmp/scaling_governor'
        dir_sys_cpu = '/sys/devices/system/cpu/'
        self.call_adb('shell "cat %s>%s"' % (f_scaling_governor,
                                             f_governor_backup))

        f_cpus_remote = '/data/local/tmp/cpus.txt'
        self.call_adb('shell "ls -d %s/cpu[0-9]* >%s"' % (dir_sys_cpu,
                                                          f_cpus_remote))
        f_cpus_local = os.path.join(os.path.abspath(self.config['output']),
                                    'cpus.txt')
        self.call_adb('pull %s %s' % (f_cpus_remote, f_cpus_local))
        with open(f_cpus_local, 'r') as f:
            for cpu in f.readlines():
                self.call_adb('shell "echo %s>%s/cpufreq/'
                              'scaling_governor"' % (target_governor,
                                                     cpu.strip()))

    def set_back_governor(self):
        dir_sys_cpu = '/sys/devices/system/cpu/'
        f_governor_backup = '/data/local/tmp/scaling_governor'
        f_governor_local = os.path.join(os.path.abspath(self.config['output']),
                                        'scaling_governor')
        self.call_adb('pull %s %s' % (f_governor_backup, f_governor_local))
        with open(f_governor_local, 'r') as f:
            contents = f.readlines()
            if len(contents) > 0:
                gov_policy = contents[0].strip()
                self.set_performance_governor(target_governor=gov_policy)

    def setUp(self):
        # set to peformance governor policay
        self.set_performance_governor()
        # Install APK.
        self.download_apk(self.config['apk_file_name'])
        self.uninstall_apk(self.config['apk_package'])
        self.install_apk(self.config['apk_file_name'])

        # Clear logcat buffer.
        self.call_adb("logcat -c")
        self.call_adb("logcat -b events -c")
        time.sleep(3)

        # Start intent.
        self.logger.info('Starting %s' % self.config['apk_package'])
        self.call_adb("shell am start -W -S %s" % self.config['activity'])
        time.sleep(5)

    def execute(self):
        raise NotImplementedError

    def parseResult(self):
        raise NotImplementedError

    def tearDown(self):
        self.uninstall_apk(self.config['apk_package'])
        self.set_back_governor()
