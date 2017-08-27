import re
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'JavaBenchmark/pure-java-benchmarks/01-Java_Whetstone.apk'
        self.config['apk_package'] = 'com.roywhet'
        self.config['activity'] = 'com.roywhet/.JavaWhetstoneActivity'
        super(ApkRunnerImpl, self).__init__(self.config)

    def setUp(self):
        self.call_adb('shell setenforce 0')
        super(ApkRunnerImpl, self).setUp()

    def tearDown(self):
        self.call_adb('shell setenforce 1')
        super(ApkRunnerImpl, self).tearDown()

    def execute(self):
        self.dump_always()
        btn_run = self.vc.findViewByIdOrRaise("com.roywhet:id/startButton")
        btn_run.touch()
        time.sleep(2)

        finished = False
        while not finished:
            try:
                time.sleep(30)
                self.dump_always()
                self.jws_results = self.vc.findViewByIdOrRaise("com.roywhet:id/displayDetails")
                if re.search('Total Elapsed Time', self.jws_results.getText()):
                    finished = True
                    self.logger.info('benchmark finished')
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass

    def parseResult(self):
        key_unit_hash = {
            "N1": "MFLOPS",
            "N2": "MFLOPS",
            "N3": "MOPS",
            "N4": "MOPS",
            "N5": "MOPS",
            "N6": "MFLOPS",
            "N7": "MOPS",
            "N8": "MOPS",
            "MWIPS": "MFLOPS"
        }

        for line in self.jws_results.getText().split('\n'):
            line = str(line.strip())
            elements = re.split(r'\s+', line)
            if line.startswith('MWIPS'):
                units = key_unit_hash['MWIPS']
                key = "MWIPS"
                value = elements[1]
            elif line.startswith('N'):
                units = key_unit_hash[elements[0]]
                key = "%s-%s" % (elements[0], elements[1])
                value = elements[2]
            else:
                continue
            self.report_result('javawhetstone-%s' % key, 'pass', value, units)
