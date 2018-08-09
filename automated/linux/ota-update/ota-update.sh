#!/bin/bash

DUT_IPADDRESS=$(lava-target-ip)
DUT=$(case ${DUT_IPADDRESS} in
	("10.7.0.68") echo "hikey-r2-01";;
	("10.7.0.69") echo "hikey-r2-02";;
	("10.7.0.66") echo "hikey-r2-03";;
	("10.7.0.73") echo "hikey-r2-04";;
	(*) echo "invalid";;
	esac)

wget http://testdata.linaro.org/apks/osf/linaro-credentials.zip http://testdata.linaro.org/apks/osf/${DUT}-client.pem http://testdata.linaro.org/apks/osf/${DUT}-pkey.pem http://testdata.linaro.org/apks/osf/sota.toml
mv ${DUT}-client.pem client.pem
mv ${DUT}-pkey.pem pkey.pem
unzip linaro-credentials.zip; cp server_ca.pem root.crt
sshpass -p 'osf' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no *.pem *.crt *.toml osf@${DUT_IPADDRESS}:~/
sshpass -p 'osf' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no osf@${DUT_IPADDRESS} "echo osf | sudo -S cp sota.toml root.crt client.pem pkey.pem /var/sota/"
sshpass -p 'osf' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no osf@${DUT_IPADDRESS} "echo osf | sudo -S systemctl restart aktualizr"

pyhton ota-update.py -d ${DUT} -is ${BASELINE_SHA} -us ${UPDATE_SHA}
