#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.
set -x

ostree remote delete "$OSTREE_REMOTE_NAME"
ostree remote add "$OSTREE_REMOTE_NAME" "$OSTREE_URL" || lava-test-case ostree-upgrade-remote-add --result fail

SORTED_VERSIONS=$(ostree remote refs "$OSTREE_REMOTE_NAME" | grep "$OSTREE_REF/" | awk -F'/' '{
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

DEPLOYED_VERSION=$(ostree admin status | grep '^\*' -A 1 | grep 'Version:' | awk '{ print $2}')
if [ "$DEPLOYED_VERSION" == "$LATEST" ]
then
  lava-test-case ostree-version --result pass
else
  lava-test-case ostree-version --result fail
fi

exit 0
