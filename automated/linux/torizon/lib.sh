#!/bin/sh

. ../../lib/sh-test-lib

LANG=C
export LANG

ostree_setup() {
    info_msg "Setup ostree remotes"
    ostree remote delete "$OSTREE_REMOTE_NAME" || true
    ostree remote add "$OSTREE_REMOTE_NAME" "$OSTREE_URL" || lava-test-case ostree-upgrade-remote-add --result fail
}

ostree_remote_refs() {
    REMOTE_NAME="$1"
    REF="$2"
    TARGET="$3"

    SORTED_VERSIONS=$(ostree remote refs "$REMOTE_NAME" | grep "$REF/" | awk -F'/' '{
      version = $NF;
      base_version = version;
      sub(/\.dev[0-9]+.*/, "", base_version);
      sub(/-[^-]+$/, "", base_version);
      if (version ~ /\.dev/) print "1 " base_version " " $0;
      else print "0 " base_version " " $0;
    }' | sort -k2,2V -k1,1n -k3V | cut -d' ' -f3-)

    if [ "$TARGET" = "latest" ]; then
        echo "$SORTED_VERSIONS" | grep dev | tail -n 1 | awk -F'/' '{print $NF}'
    else  ##  means that the value is 'latest_tag'
        echo "$SORTED_VERSIONS" | grep -v dev | tail -n 1 | awk -F'/' '{print $NF}'
    fi
}

ostree_current_ref() {
    ostree admin status | grep '^\*' -A 1 | grep 'Version:' | awk '{ print $2}'
}

ostree_upgrade() {
    TARGET="$1"
    info_msg "ostree upgrade to $TARGET"

    ostree pull "$TARGET"
    ostree admin deploy --os=laa "$TARGET"
    fw_setenv upgrade_available 1
    fw_setenv bootcount 0
    fw_setenv rollback 0
}
