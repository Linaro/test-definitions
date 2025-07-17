#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.
set -x

if [ "$IS_CHECK" = "True" ]; then
    LATEST=$(ostree remote refs $OSTREE_REMOTE_NAME | grep $OSTREE_REF | grep -v dev | tail -n 1 | awk -F'/' '{print $NF}')
    ostree admin status | grep $LATEST && lava-test-case ostree-upgrade --result pass || lava-test-case ostree-upgrade --result fail
else
    ostree admin status
    ostree remote add $OSTREE_REMOTE_NAME https://ostree.lavacloud.io/
    LATEST=$(ostree remote refs $OSTREE_REMOTE_NAME | grep laa-qemu | grep -v dev | tail -n 1)
    ostree pull $LATEST
    ostree admin deploy --os=laa $LATEST
#    reboot
fi

exit 0
