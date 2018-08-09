#!/bin/bash
RESULT_FILE="$(pwd)/output/result.txt"
export RESULT_FILE
mkdir output

DUT_IPADDRESS=$(lava-target-ip)
DUT=$(case "${DUT_IPADDRESS}" in
    ("10.7.0.68") echo "hikey-r2-01";;
    ("10.7.0.69") echo "hikey-r2-02";;
    ("10.7.0.66") echo "hikey-r2-03";;
    ("10.7.0.73") echo "hikey-r2-04";;
    (*) echo "invalid";;
    esac)

wget http://testdata.linaro.org/apks/osf/"${DUT}"-sota.tar -O sota.tar
sshpass -p 'osf' scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no sota.tar osf@"${DUT_IPADDRESS}":~/
sshpass -p 'osf' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no osf@"${DUT_IPADDRESS}" "echo osf | sudo -S tar -xvf sota.tar -C /var/"
sshpass -p 'osf' ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no osf@"${DUT_IPADDRESS}" "echo osf | sudo -S systemctl restart aktualizr"

python ota-update.py -d "${DUT}" -is "${BASELINE_SHA}" -us "${UPDATE_SHA}"

# Restore device image back to baseline for future testing. The server information
# about images on device should match the actual image on the device.
python ota-update.py -d "${DUT}" -us "${BASELINE_SHA}" -is "${UPDATE_SHA}"
