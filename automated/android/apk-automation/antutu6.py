import time
from common import ApkTestRunner


class ApkRunnerImpl(ApkTestRunner):
    def __init__(self, config):
        self.config = config
        self.apk_3d_name = "antutu_benchmark_v6_3d_f1.apk"
        self.apk_3d_pkg = "com.antutu.benchmark.full"
        self.config['apk_file_name'] = "AnTuTu6.0.4.apk"
        self.config['apk_package'] = "com.antutu.ABenchMark"
        self.config['activity'] = "com.antutu.ABenchMark/.ABenchMarkStart"
        super(ApkRunnerImpl, self).__init__(self.config)

    def setUp(self):
        self.download_apk(self.apk_3d_name)
        self.uninstall_apk(self.apk_3d_pkg)
        self.install_apk(self.apk_3d_name)
        super(ApkRunnerImpl, self).setUp()

    def tearDown(self):
        super(ApkRunnerImpl, self).tearDown()
        self.uninstall_apk(self.apk_3d_pkg)

    def parseResult(self):
        test_items = [u'3D', u'UX', u'CPU', u'RAM']
        test_subitems = {
            u'3D': [u'3D [Garden]', u'3D [Marooned]'],
            u'UX': [u'UX Data Secure', u'UX Data process', u'UX Strategy games', u'UX Image process', u'UX I/O performance'],
            u'CPU': [u'CPU Mathematics', u'CPU Common Use', u'CPU Multi-Core'],
            u'RAM': []
        }
        antutu_sum = 0
        for item in test_items:
            self.logger.info("Trying to find result id_root for test suite: %s" % item)
            found_view = False
            while not found_view:
                self.dump_always()
                id_root = self.vc.findViewWithText(item)
                if id_root:
                    self.logger.info("Found result id_root for test suite: %s" % item)
                    found_view = True
                else:
                    self.dump_always()
                    self.logger.info("Press DPAD_DOWN to find %s item" % item)
                    self.device.press('DPAD_DOWN')
                    time.sleep(2)

            self.logger.info("Trying to find the score value for test suite: %s" % item)
            found_view = False
            while not found_view:
                self.dump_always()
                id_root = self.vc.findViewWithText(item)
                score_view = self.vc.findViewById("com.antutu.ABenchMark:id/tv_score_value",
                                                  id_root.getParent())
                if score_view:
                    score = score_view.getText().strip()
                    self.logger.info("Found %s score: %s" % (item, score))
                    try:
                        score = int(score)
                        self.report_result('antutu6-%s' % item.lower(), 'pass', score, 'points')
                        antutu_sum = antutu_sum + int(score)
                    except ValueError:
                        self.report_result('antutu6-%s' % item.lower(), 'fail')

                    found_view = True
                    arrow_icon = self.vc.findViewById("com.antutu.ABenchMark:id/iv_arrow", id_root.getParent())
                    if arrow_icon:
                        arrow_icon.touch()
                else:
                    self.logger.info("Press DPAD_DOWN to find %s item value" % item.lower())
                    self.device.press('DPAD_DOWN')
                    time.sleep(2)

            for sub_item in test_subitems[item]:
                self.logger.info("Trying to find score value for sub item: %s" % sub_item)
                found_view = False
                while not found_view:
                    self.dump_always()
                    subitem_obj = self.vc.findViewWithText(sub_item)
                    if subitem_obj:
                        subitem_value_obj = self.vc.findViewByIdOrRaise("com.antutu.ABenchMark:id/tv_value", subitem_obj.getParent())
                        subitem_key = sub_item.replace("[", '').replace("]", '')
                        subitem_key = subitem_key.replace("/", '')
                        subitem_key = subitem_key.replace(' ', '-')
                        subitem_score = subitem_value_obj.getText().strip()
                        self.logger.info("Found %s score: %s" % (subitem_key, subitem_score))
                        try:
                            subitem_score = int(subitem_score)
                            self.report_result('antutu6-%s' % subitem_key.lower(), 'pass', subitem_score, 'points')
                        except ValueError:
                            self.report_result('antutu6-%s' % subitem_key.lower(), 'fail')
                        found_view = True
                    else:
                        self.logger.info("Press DPAD_DOWN to find sub item: %s" % sub_item)
                        self.device.press('DPAD_DOWN')
                        time.sleep(2)
        self.report_result('antutu6-sum', 'pass', antutu_sum, 'points')

    def execute(self):
        # Enable 64-bit
        time.sleep(10)

        finished = False
        while not finished:
            self.dump_always()
            test_region = self.vc.findViewById("com.antutu.ABenchMark:"
                                               "id/start_test_region")
            if test_region:
                test_region.touch()

            time.sleep(30)
            self.dump_always()
            text_qr_code = self.vc.findViewWithText(u'QRCode of result')
            if text_qr_code:
                finished = True
                self.logger.info("Benchmark test finished!")

            stop_msg = 'Unfortunately, AnTuTu 3DBench has stopped.'
            msg_stopped = self.vc.findViewWithText(stop_msg)
            if msg_stopped:
                btn_ok = self.vc.findViewWithTextOrRaise(u'OK')  # nopep8
                btn_ok.touch()

            # cancel the update
            update_msg = "New update available"
            update_window = self.vc.findViewWithText(update_msg)
            if update_window:
                btn_cancel = self.vc.findViewWithTextOrRaise(u'Cancel')
                btn_cancel.touch()

            msg = "Please allow the permissions we need for test"
            need_permission_msg = self.vc.findViewWithText(msg)
            if need_permission_msg:
                btn_ok = self.vc.findViewWithTextOrRaise(u'OK')
                btn_ok.touch()

            allow_permission_btn = self.vc.findViewById('com.android.packageinstaller'
                                                        ':id/permission_allow_button')
            if allow_permission_btn:
                allow_permission_btn.touch()
