import requests
import json
import yaml
import time
from argparse import ArgumentParser

parser=ArgumentParser()
parser.add_argument("-d", "--device", dest="devicename", default="hikey-r2-01",
                    help="Device Name to be updated")
parser.add_argument("-is", "--installed-sha", dest="installed_sha", default="",
                    help="OTA update sha")
parser.add_argument("-us", "--update-sha", dest="update_sha", default="",
                    help="OTA update sha")
args=parser.parse_args()
url="http://api.ota-prototype.linaro.org/devices/%s/" % args.devicename
headers={
        "OTA-TOKEN": "BadT0ken5",
        "Content-type": "application/json"
        }
data=json.dumps({"image":  {"hash": args.update_sha}})

def match_sha_on_server(sha):
  loop = 0
  while loop < 10:
    r = requests.get(url,headers=headers)
    resp = yaml.load(r.text)
    currentsha_on_server=resp.get("deviceImage").get("image").get("hash").get("sha256")
    if currentsha_on_server == sha:
      return 0
    loop = loop+1
    time.sleep(60)
    if loop == 10:
      print "FAIL: Installed sha on device did not match"
      return -1

if match_sha_on_server(args.installed_sha) == 0:
  r=requests.put(url, data=data, headers=headers)
  if match_sha_on_server(args.update_sha) == 0:
    print "PASS: %s updated to %s successfully" % (args.devicename, args.update_sha)
  else:
    print "FAIL: %s update to %s failed" % (args.devicename, args.update_sha)
else:
  print "FAIL: %s update to %s failed" % (args.devicename, args.update_sha)
