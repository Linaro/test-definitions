#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.
set -x

ostree remote add $OSTREE_REMOTE_NAME $OSTREE_URL || lava-test-case ostree-upgrade-remote-add --result fail

SORTED_VERSIONS=$(ostree remote refs $OSTREE_REMOTE_NAME | grep $OSTREE_REF/ | awk -F'/' '{
  version = $NF;
  base_version = version;
  sub(/\.dev[0-9]+.*/, "", base_version);
  sub(/-[^-]+$/, "", base_version);
  if (version ~ /\.dev/) print "1 " base_version " " $0;
  else print "0 " base_version " " $0;
}' | sort -k2,2V -k1,1n -k3V | cut -d' ' -f3-)

if [ "$OSTREE_TARGET_VERSION" = "latest" ]; then
    LATEST=$(echo "$SORTED_VERSIONS" | grep dev | tail -n 1 | awk -F'/' '{print $NF}')
else  ##  means that the value is 'latest_tag'
    LATEST=$(echo "$SORTED_VERSIONS" | grep -v dev | tail -n 1 | awk -F'/' '{print $NF}')
fi

if [ "$IS_CHECK" = "True" ]; then
    ostree admin status | grep $LATEST && lava-test-case ostree-upgrade --result pass || lava-test-case ostree-upgrade --result fail
else
    ostree admin status
    ostree pull $OSTREE_REMOTE_NAME:$OSTREE_REF/$LATEST
    ostree admin deploy --os=laa $OSTREE_REMOTE_NAME:$OSTREE_REF/$LATEST
fi

exit 0
