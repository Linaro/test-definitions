from common import ApkTestRunner
from com.dtmilano.android.viewclient import ViewNotFoundException


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = 'com.aurorasoftworks.quadrant.ui.professional-1.apk'
        self.config['apk_package'] = 'com.aurorasoftworks.quadrant.ui.professional'
        self.config['activity'] = 'com.aurorasoftworks.quadrant.ui.professional/.QuadrantProfessionalLauncherActivity'
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        self.dump_always()
        view_license_btn = self.vc.findViewWithText("View license")
        if view_license_btn:
            ok_button = self.vc.findViewWithTextOrRaise("OK")
            ok_button.touch()

        self.dump_always()
        run_full_item = self.vc.findViewWithTextOrRaise(u'Run full benchmark')
        run_full_item.touch()

        finished = False
        while not finished:
            try:
                self.dump_always()
                self.vc.findViewByIdOrRaise("com.aurorasoftworks.quadrant.ui.professional:id/chart")
                finished = True
                self.logger.info('Benchmark finished')
            except ViewNotFoundException:
                pass
            except RuntimeError:
                pass
            except ValueError:
                pass

    def parseResult(self):
        raw_output_file = "%s/logcat-quadrandpro-itr%s.log" % (self.config['output'], self.config['itr'])
        self.call_adb('logcat -d -v brief > %s' % raw_output_file)

        with open(raw_output_file) as logfile:
            for line in logfile:
                if 'aggregate score is' in line:
                    tc_id = line.split()[3].replace('_', '-')
                    measurement = line.split()[-1]
                    self.report_result('quadrandpro-%s' % tc_id, 'pass', measurement, 'points')
