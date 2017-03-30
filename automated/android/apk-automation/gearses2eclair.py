import sys
import time
from common import ApkTestRunner


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.config['apk_file_name'] = "GearsES2eclair-20141021.apk"
        self.config['apk_package'] = "com.jeffboody.GearsES2eclair"
        self.config['activity'] = "com.jeffboody.GearsES2eclair/.GearsES2eclair"
        super(ApkRunnerImpl, self).__init__(self.config)

    def execute(self):
        self.logger.info('Running GearsES2eclair for 60 seconds...')
        time.sleep(60)

    def parseResult(self):
        raw_output_file = "%s/logcat-gearses2eclair-itr%s.log" % (self.config['output'], self.config['itr'])
        self.call_adb('logcat -d > %s' % raw_output_file)

        flagwordA = "a3d_GLES_dump"
        flagwordB = "fps"
        result_collector = []

        logfile = open(raw_output_file, "r")
        for line in logfile:
            linelist = line.strip("\n").strip("\r").split(" ")
            linelist = filter(None, linelist)
            for itemA in linelist:
                if itemA.find(flagwordA) != -1:
                    for itemB in linelist:
                        if itemB.find(flagwordB) != -1:
                            self.logger.info('linelist: %s' % linelist)
                            for i in range(0, len(linelist)):
                                grouplist = linelist[i].split("=")
                                if len(grouplist) == 2 and grouplist[0] == flagwordB:
                                    result_collector.append(grouplist[1])
        logfile.close()

        self.logger.info('result_collector: %s' % result_collector)
        if len(result_collector) > 0:
            average_fps = sum(float(element) for element in result_collector) / len(result_collector)
            score_number = average_fps
            run_result = "pass"
            score_unit = flagwordB
            self.logger.info("The average FPS in this test run is %s" % str(score_number))
        else:
            self.logger.error("The collector is empty, no actual result received!")
            sys.exit(1)

        self.report_result('gearses2eclair', run_result, score_number, score_unit)
