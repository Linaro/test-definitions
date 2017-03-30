import re
import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'JavaBenchmark/pure-java-benchmarks/03-JBench.apk'
        self.config['apk_package'] = 'it.JBench.bench'
        self.config['activity'] = 'it.JBench.bench/it.JBench.jbench.MainActivity'
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        self.dump_always()
        btn_jbench = self.vc.findViewByIdOrRaise("it.JBench.bench:id/button1")
        btn_jbench.touch()
        time.sleep(2)

        finished = False
        while (not finished):
            try:
                time.sleep(5)
                self.dump_always()
                results = self.vc.findViewByIdOrRaise("it.JBench.bench:id/textViewResult")
                if re.search('^\d+$', results.getText()):
                    finished = True
                    print("benchmark finished")
                    print("%s=%s" % ("JBench", results.getText().strip()))
                    self.report_result("jbench", 'pass', results.getText().strip(), 'points')
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass

    def parseResult(self):
        pass
