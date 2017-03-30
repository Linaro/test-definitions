import logging
import os
import requests
import shutil
import shlex
import subprocess
import sys
import time

from com.dtmilano.android.viewclient import ViewClient

APK_DIR = "apks"


class ApkTestRunner(object):
    def __init__(self, name):
        # name represents the apk to test, i.e. vellamo3
        self.name = name
        self.logger = logging.getLogger(self.name)
        self.logger.setLevel(logging.INFO)
        ch = logging.StreamHandler()
        ch.setLevel(logging.DEBUG)
        formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        ch.setFormatter(formatter)
        self.logger.addHandler(ch)

        self.activity = os.environ.get("activity", None)
        self.apk_file_name = os.environ.get("apk_file_name", None)
        self.apk_package = os.environ.get("apk_package", None)

        self.result_file_name = os.environ.get("RESULT_FILE", None)
        self.verbose_output = False
        if os.environ.get('VERBOSE_OUTPUT', 'FALSE').lower() == 'true':
            self.verbose_output = True
            self.logger.setLevel(logging.DEBUG)
        self.record_local_csv = False
        if os.environ.get('RECORD_CSV', 'FALSE').lower() == 'true':
            self.record_local_csv = True

        kwargs1 = {
            'verbose': False,
            'ignoresecuredevice': False}
        self.device, self.serialno = ViewClient.connectToDeviceOrExit(**kwargs1)
        kwargs2 = {
            'startviewserver': True,
            'forceviewserveruse': False,
            'autodump': False,
            'ignoreuiautomatorkilled': True,
            'compresseddump': False}
        self.vc = ViewClient(self.device, self.serialno, **kwargs2)

    def run(self):
        self.loops = os.environ.get("LOOP_COUNT", 1)
        self.loop = 0
        for loop in range(self.loops):
            self.loop = loop
            self.setUp()
            self.execute()
            self.parseResult()
            self.tearDown()

    def reportResult(self, name, result, score=None, units=None):
        if self.loop == 0:
            # we're in the new test run
            # remove all previous results first
            if self.result_file_name is not None:
                # ToDo implement this feature
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

    def download_apk(self, apk_name):
        # create directory for downloaded files
        if not os.path.isdir(os.path.abspath(APK_DIR)):
            os.makedirs(os.path.abspath(APK_DIR))
        # download APK if not already downloaded
        if self.apk_file_name is None:
            self.logger.error("APK file name not set")
            sys.exit(1)
        base_path = os.path.join(os.path.abspath(APK_DIR), self.apk_file_name)
        if not os.path.isfile(base_path):
            base_url = "https://testdata.validation.linaro.org/apks/%s" % self.apk_file_name
            r = requests.get(base_url, stream=True)
            if r.status_code == 200:
                with open(base_path, 'wb') as f:
                    r.raw.decode_content = True
                    shutil.copyfileobj(r.raw, f)

    def setUp(self):
        self.download_apk(self.apk_file_name)
        base_path = os.path.join(os.path.abspath(APK_DIR), self.apk_file_name)
        # uninstall APK
        if self.apk_package is None:
            self.logger.error("APK package name not set")
            sys.exit(1)
        self.call_adb("shell pm uninstall %s" % self.apk_package)
        # install APK
        self.call_adb("install %s" % base_path)
        # start intent
        if self.activity is None:
            self.logger.error("Activity name not set")
            sys.exit(1)
        self.call_adb("shell am start %s" % self.activity)

    def execute(self):
        raise NotImplementedError

    def parseResult(self):
        raise NotImplementedError

    def tearDown(self):
        # stop intent
        if self.apk_package is None:
            self.logger.error("APK package name not set")
            sys.exit(1)
        self.call_adb("shell am force-stop %s" % self.apk_package)
        # uninstall APK
        if self.apk_package is None:
            self.logger.error("APK package name not set")
            sys.exit(1)
        self.call_adb("shell pm uninstall %s" % self.apk_package)

