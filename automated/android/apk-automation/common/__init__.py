import datetime
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
            shutil.move(self.config['output'], '%s_%s' % (self.config['output'], suffix))
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

        for i in range(0, self.config['loops']):
            self.logger.info('--- Running iteration [%s/%s] ---' % (i, self.config['loops']))
            self.config['itr'] = i
            self.logger.info('Test config: %s' % self.config)
            self.setUp()
            self.execute()
            self.parseResult()
            self.tearDown()

        self.result_post_processing()

    def report_result(self, name, result, score=None, units=None):
        if self.config['loops'] > 1:
            name = '%s-itr%s' % (name, self.config['itr'])
        result_string = '%s %s %s %s' % (name, result, score, units)
        print('TestResult: %s' % result_string)
        with open('%s/result.txt' % self.config['output'], 'a') as f:
            f.write('%s\n' % result_string)

        # Save result of each iteration to results for post processing.
        self.result = {'itr': self.config['itr'],
                       'test_case_id': name,
                       'result': result,
                       'measurement': score,
                       'units': units}
        self.results.append(result)

    def result_post_processing(self):
        # TODO: save self.results to csv, yaml, json.
        # TODO: calculate min, max and avg.
        pass

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

    def setUp(self):
        self.download_apk(self.config['apk_file_name'])
        self.uninstall_apk(self.config['apk_package'])
        self.install_apk(self.config['apk_file_name'])
        # start intent
        self.logger.info('Starting %s' % self.config['apk_package'])
        self.call_adb("shell am start %s" % self.config['activity'])

    def execute(self):
        raise NotImplementedError

    def parseResult(self):
        raise NotImplementedError

    def tearDown(self):
        self.uninstall_apk(self.config['apk_package'])
