import os
import time
from subprocess import call

from com.dtmilano.android.viewclient import ViewClient

parent_dir = os.path.realpath(os.path.dirname(__file__))
f_output_result = "%s/../common/output-test-result.sh" % parent_dir

kwargs1 = {'verbose': False, 'ignoresecuredevice': False}
device, serialno = ViewClient.connectToDeviceOrExit(**kwargs1)
kwargs2 = {'startviewserver': True, 'forceviewserveruse': False, 'autodump': False, 'ignoreuiautomatorkilled': True, 'compresseddump': False}
vc = ViewClient(device, serialno, **kwargs2)

time.sleep(2)
vc.dump(window='-1')
start_single_button = vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/btnsingle")
start_single_button.touch()
time.sleep(2)
vc.dump(window='-1')
start_single_button = vc.findViewById("com.greenecomputing.linpack:id/btnsingle")
while not start_single_button:
    time.sleep(2)
    vc.dump(window='-1')
    start_single_button = vc.findViewById("com.greenecomputing.linpack:id/btnsingle")

mflops_single_score = vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txtmflops_result")
time_single_score = vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txttime_result")

call([f_output_result, 'Linpack_MFLOPSSingleScore', 'pass', mflops_single_score.getText(), 'MFLOPS'])
call([f_output_result, 'Linpack_TimeSingleScore', 'pass', time_single_score.getText(), 'seconds'])

start_multi_button = vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/btncalculate")
start_multi_button.touch()
time.sleep(2)
vc.dump(window='-1')
start_single_button = vc.findViewById("com.greenecomputing.linpack:id/btnsingle")
while not start_single_button:
    time.sleep(2)
    vc.dump(window='-1')
    start_single_button = vc.findViewById("com.greenecomputing.linpack:id/btnsingle")

mflops_multi_score = vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txtmflops_result")
time_multi_score = vc.findViewByIdOrRaise("com.greenecomputing.linpack:id/txttime_result")

call([f_output_result, 'Linpack_MFLOPSMultiScore', 'pass', mflops_multi_score.getText(), 'MFLOPS'])
call([f_output_result, 'Linpack_TimeMultiScore', 'pass', time_multi_score.getText(), 'seconds'])
