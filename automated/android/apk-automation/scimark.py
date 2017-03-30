import time
from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'JavaBenchmark/non-pure-java-benchmarks/03-SciMark.apk'
        self.config['apk_package'] = 'net.danielroggen.scimark'
        self.config['activity'] = 'net.danielroggen.scimark/.ActivityMain'
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        time.sleep(5)
        self.dump_always()
        btn_java_bench = self.vc.findViewWithTextOrRaise(u'Java bench')
        btn_java_bench.touch()

        finished = False
        while not finished:
            try:
                time.sleep(60)
                self.dump_always()
                self.sci_results = self.vc.findViewByIdOrRaise("net.danielroggen.scimark:id/textViewResult")
                if self.sci_results.getText().find("Done") > 0:
                    finished = True
                    self.logger.info("benchmark finished")
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass

    def parseResult(self):
        keys = ["FFT (1024)", "SOR (100x100)", "Monte Carlo",
                "Sparse matmult (N=1000, nz=5000)", "LU (100x100)", "Composite Score"]

        for line in self.sci_results.getText().replace(": \n", ":").split("\n"):
            line = str(line.strip())
            key_val = line.split(":")
            if len(key_val) == 2:
                if key_val[0].strip() in keys:
                    key = key_val[0].strip().replace(' ', '-').replace('(', '').replace(')', '').replace(',', '')
                    self.report_result("scimark-" + key, 'pass', key_val[1].strip(), 'Mflops')
