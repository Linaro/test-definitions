#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Linaro Ltd.
set -ex

. ./lib.sh

ostree_setup

LATEST=$(ostree_remote_refs "$OSTREE_REMOTE_NAME" "$OSTREE_REF" "$OSTREE_TARGET_VERSION")

DEPLOYED_VERSION=$(ostree_current_ref)
if [ "$DEPLOYED_VERSION" == "$LATEST" ]
then
  lava-test-case ostree-version --result pass
else
  lava-test-case ostree-version --result fail
fi

exit 0
