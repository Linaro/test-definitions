import csv
import datetime
import json
import logging
import os
import requests
import shutil
import shlex
import subprocess
import sys
import time
from com.dtmilano.android.viewclient import ViewClient


class ApkTestRunner(object):
    def __init__(self, config):
        self.config = config

        self.logger = logging.getLogger(self.config['name'])
        self.logger.setLevel(logging.INFO)
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

        kwargs1 = {
            'verbose': False,
            'ignoresecuredevice': False}
        self.logger.debug('VC kwargs1: %s' % kwargs1)
        # VC obtain device serial no. from sys.agv when it is not empty.
        # Refer to: /src/com/dtmilano/android/viewclient.py
        # In our case, ANDROID_SERIAL is set by initialize_adb() and sys.argv
        # is parsed in main.py, so clear the args to use ANDROID_SERIAL.
        sys.argv = [sys.argv[0]]
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
            self.logger.info('Running iteration [%s/%s]' % (i, self.config['loops']))
            self.config['itr'] = i
            self.logger.info('Test config: %s' % self.config)
            self.setUp()
            self.execute()
            self.parseResult()
            self.take_screencap()
            self.tearDown()

        self.result_post_processing()
        self.collect_log()

    def report_result(self, name, result, score=None, units=None):
        if score is not None:
            score = float(score)
        if units is not None:
            units = str(units)

        tc_name = str(name)
        if self.config['loops'] > 1 and self.config['itr'] != 'eot':
            tc_name = '%s-itr%s' % (name, self.config['itr'])
        result_string = '%s %s %s %s' % (tc_name, result, score, units)

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

    def min_max_avg(self):
        if self.config['loops'] == 1:
            return

        self.config['itr'] = 'eot'

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

            self.report_result('%s-min' % tc, 'pass', min(ms_list), units)
            self.report_result('%s-max' % tc, 'pass', max(ms_list), units)
            self.report_result('%s-avg' % tc, 'pass', sum(ms_list) / len(ms_list), units)

    def result_post_processing(self):
        self.min_max_avg()

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
                self.vc.dump()
                success = True
            except RuntimeError:
                print("Got RuntimeError when call vc.dump()")
                time.sleep(5)
            except ValueError:
                print("Got ValueError when call vc.dump()")
                time.sleep(5)

    def call_adb(self, args):
        # ToDo: make sure the call is successful
        self.logger.debug("calling")
        self.logger.debug("adb %s" % args)
        subprocess.call(shlex.split("adb %s" % args))

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
        # create directory for downloaded files
        if not os.path.isdir(os.path.abspath(self.config['apk_dir'])):
            os.makedirs(os.path.abspath(self.config['apk_dir']))

        # download APK if not already downloaded
        apk_path = os.path.join(os.path.abspath(self.config['apk_dir']), apk_name)
        if not os.path.isfile(apk_path):
            base_url = "https://testdata.validation.linaro.org/apks/%s" % apk_name
            r = requests.get(base_url, stream=True)
            if r.status_code == 200:
                with open(apk_path, 'wb') as f:
                    r.raw.decode_content = True
                    shutil.copyfileobj(r.raw, f)

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
        self.call_adb('pull %s %s' % (screencap_file, self.config['output']))

    def collect_log(self):
        self.call_adb('shell logcat -d -v time > /data/local/tmp/logcat.log')
        self.call_adb('pull /data/local/tmp/logcat.log %s' % self.config['output'])

        self.call_adb('shell logcat -d -b events -v time > /data/local/tmp/logcat-events.log')
        self.call_adb('pull /data/local/tmp/logcat-events.log %s' % self.config['output'])

        self.call_adb('shell dmesg 2>&1 > /data/local/tmp/dmesg.log')
        self.call_adb('pull /data/local/tmp/dmesg.log %s' % self.config['output'])

    def setUp(self):
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

    def execute(self):
        raise NotImplementedError

    def parseResult(self):
        raise NotImplementedError

    def tearDown(self):
        self.uninstall_apk(self.config['apk_package'])
