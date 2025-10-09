#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.
set -x

# Verify variables are not empty
[[ -z "$OSTREE_REMOTE_NAME" ]] || [[ -z "$OSTREE_URL" ]] || [[ -z "$OSTREE_REF" ]]  && lava-test-case ostree-rollback-verify-vars --result fail

# Add remote with specified name if it's not added already
ostree remote list | grep $OSTREE_REMOTE_NAME || ostree remote add $OSTREE_REMOTE_NAME $OSTREE_URL || lava-test-case ostree-rollback-remote-add --result fail

# Find latest version
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

[[ -z "$LATEST" ]]  && lava-test-case ostree-rollback-verify-latest --result fail

if [ "$IS_CHECK" = "True" ]; then
    ostree admin status
    # check that the current version is not the new one
    ostree admin status | grep -A 1 "*" | sed -n '2p' | grep $LATEST && lava-test-case ostree-rollback --result fail || lava-test-case ostree-rollback --result pass
else
    ostree admin status
    # set up force rollback script
    echo """
#!/bin/bash
exit 1
""" >> /etc/greenboot/check/required.d/rollback.sh
    chmod +x /etc/greenboot/check/required.d/rollback.sh
    ostree pull $OSTREE_REMOTE_NAME:$OSTREE_REF/$LATEST
    ostree admin deploy --os=laa $OSTREE_REMOTE_NAME:$OSTREE_REF/$LATEST
    fw_setenv upgrade_available 1 && lava-test-case ostree-rollback-uefi-var --result fail
    fw_setenv bootcount 0 && lava-test-case ostree-rollback-uefi-var --result fail
    fw_setenv rollback 0 && lava-test-case ostree-rollback-uefi-var --result fail
fi

exit 0
