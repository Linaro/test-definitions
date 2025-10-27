#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.
set -x
. ./lib.sh

ostree_setup

LATEST=$(ostree_remote_refs "$OSTREE_REMOTE_NAME" "$OSTREE_REF" "$OSTREE_TARGET_VERSION")

if [ "$IS_CHECK" = "True" ]; then
    DEPLOYED_VERSION=$(ostree_current_ref)
    if [ "$DEPLOYED_VERSION" == "$LATEST" ]
    then
      lava-test-case ostree-rollback --result fail
    else
      lava-test-case ostree-rollback --result pass
    fi

    fw_printenv bootcount
    if [ "$(fw_printenv bootcount)" == "bootcount=4" ]
    then
      lava-test-case ostree-bootcount --result pass
    else
      lava-test-case ostree-bootcount --result fail
    fi

    fw_printenv rollback
    if [ "$(fw_printenv rollback)" == "rollback=1" ]
    then
      lava-test-case ostree-rollback-var --result pass
    else
      lava-test-case ostree-rollback-var --result fail
    fi
else
    # set up force rollback script
    echo """
#!/bin/bash
exit 1
""" >> /etc/greenboot/check/required.d/rollback.sh
    chmod +x /etc/greenboot/check/required.d/rollback.sh

    ostree_upgrade "$OSTREE_REMOTE_NAME:$OSTREE_REF/$LATEST"
fi

exit 0
