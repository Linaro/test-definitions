import argparse
import sys
from time import ctime
from datetime import datetime

try:
    import ntplib
except ImportError:
    print("ntplib missing")
    sys.exit(1)

parser = argparse.ArgumentParser()
parser.add_argument(
    "-n",
    "--ntp-server",
    dest="ntp_server",
    default="pool.ntp.org",
    help="NTP server to check against",
)
args = parser.parse_args()
c = ntplib.NTPClient()
response = None
try:
    response = c.request(args.ntp_server)
except ntplib.NTPException:
    print(f"Unable to contact {args.ntp_server}")
    sys.exit(2)

ntp_time = datetime.fromtimestamp(response.tx_time)
local_time = datetime.now()
time_diff = local_time - ntp_time
if abs(time_diff.total_seconds()) > 1:
    # test fails
    print(f"NTP Time: {ntp_time}")
    print(f"Local Time: {local_time}")
    print(f"Time difference: {time_diff}")
    sys.exit(1)
sys.exit(0)
