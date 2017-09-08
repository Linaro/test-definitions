import re
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "andebench-pro_2015.apk"
        self.config['apk_package'] = "com.eembc.andebench"
        self.config['activity'] = "com.eembc.andebench/.splash"
        super(ApkRunnerImpl, self).__init__(self.config)

    def setUp(self):
        self.call_adb('shell setenforce 0')
        super(ApkRunnerImpl, self).setUp()

    def tearDown(self):
        self.call_adb('shell setenforce 1')
        super(ApkRunnerImpl, self).tearDown()

    def parseResult(self):
        local_result_csv = "%s/andebench.log.csv" % self.config['output']
        remote_result_csv = "/mnt/sdcard/Download/andebench.log.csv"
        self.call_adb("pull %s %s" % (remote_result_csv, local_result_csv))

        test_items = ["CoreMark-PRO (Base)",
                      "CoreMark-PRO (Peak)",
                      "Memory Bandwidth",
                      "Memory Latency",
                      "Storage",
                      "Platform",
                      "3D",
                      "Overall Score",
                      "Verify"]

        pat_score = re.compile("^(?P<measurement>[\d\.]+)$")
        pat_score_unit_str = "^(?P<measurement>[\d\.]+)(?P<units>[^\d\.]+)$"
        pat_score_unit = re.compile(pat_score_unit_str)

        with open(local_result_csv, 'r') as f:
            for line in f.readlines():
                fields = line.split(",")
                if fields[0] not in test_items:
                    continue

                if len(fields) == 2:
                    test_name = fields[0].strip()
                    measurement = fields[1].strip()
                elif len(fields) == 3:
                    test_name = "_".join([fields[0].strip(),
                                          fields[1].strip()])
                    measurement = fields[2].strip()
                else:
                    # not possible here
                    measurement = ""
                    pass

                test_name = test_name.replace(" ", "_")
                test_name = test_name.replace('(', '').replace(")", "")
                match = pat_score.match(measurement)
                if not match:
                    match = pat_score_unit.match(measurement)

                if not match:
                    self.report_result("andebenchpro2015-%s" % test_name,
                                       "fail")
                else:
                    data = match.groupdict()
                    measurement = data.get('measurement')
                    units = data.get("units")
                    if units is None:
                        units = "points"

                    self.report_result("andebenchpro2015-%s" % test_name,
                                       "pass", measurement, units)

    def execute(self):
        # Enable 64-bit
        time.sleep(10)

        self.dump_always()
        btn_license = self.vc.findViewWithText(u'I Agree')
        if btn_license:
            btn_license.touch()

        # disable memory test
        # which will cause test application crash
        time.sleep(3)
        self.dump_always()
        item = self.vc.findViewById("com.eembc.andebench:id/ab_icon")
        if item:
            item.touch()
            time.sleep(3)
            self.dump_always()
            item = self.vc.findViewWithText(u'Options')
            if item:
                item.touch()
                time.sleep(3)
                self.dump_always()
                opt_str = "com.eembc.andebench:id/opt_expandableListView1"
                opt_expandableListView1 = self.vc.findViewByIdOrRaise(opt_str)
                if opt_expandableListView1:
                    for sub in opt_expandableListView1.children:
                        if not self.vc.findViewWithText(u'Memory', sub):
                            cbx1_str = "com.eembc.andebench:id/cbx1"
                            self.vc.findViewByIdOrRaise(cbx1_str, sub).touch()
                            time.sleep(3)
                            self.dump_always()

                    self.vc.findViewByIdOrRaise(
                        "com.eembc.andebench:id/ab_icon").touch()
                    time.sleep(3)
                    self.dump_always()
                    self.vc.findViewWithTextOrRaise(u'Home').touch()

        while True:
            try:
                self.dump_always()
                s1_runall_str = "com.eembc.andebench:id/s1_runall"
                btn_start_on = self.vc.findViewByIdOrRaise(s1_runall_str)
                btn_start_on.touch()
                break
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass

        find_result = False
        while not find_result:
            try:
                time.sleep(30)
                self.dump_always()
                self.vc.findViewWithTextOrRaise("DEVICE SCORE")

                self.vc.findViewWithTextOrRaise(u'3D').touch()
                self.vc.findViewWithTextOrRaise(u'Platform').touch()
                self.vc.findViewWithTextOrRaise(u'Storage').touch()
                self.vc.findViewWithTextOrRaise(u'Memory Latency').touch()
                self.vc.findViewWithTextOrRaise(u'Memory Bandwidth').touch()
                self.vc.findViewWithTextOrRaise(u'CoreMark-PRO (Peak)').touch()
                self.vc.findViewWithTextOrRaise(u'CoreMark-PRO (Base)').touch()
                find_result = True
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass
