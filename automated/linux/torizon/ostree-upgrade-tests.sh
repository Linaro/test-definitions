#!/bin/bash

if [ $IS_CHECK != "True" ]; then
    ostree admin status
    ostree remote add $OSTREE_REMOTE_NAME https://ostree.lavacloud.io/
    LATEST=$(ostree remote refs $OSTREE_REMOTE_NAME | grep laa-qemu | tail -n 1)
    ostree pull $LATEST
    ostree admin deploy --os=laa $LATEST
    reboot
else
    LATEST=$(ostree remote refs $OSTREE_REMOTE_NAME | grep laa-qemu | tail -n 1 | awk -F'/' '{print $NF}')
    ostree admin status | grep $LATEST && lava-test-case ostree-upgrade --result pass || lava-test-case ostree-upgrade --result fail
fi
