#!/bin/bash -e

case "${MESSAGE}" in
    "check-for-update-pre")
        echo "Check for update PRE";
        ;;
    "check-for-update-post")
        echo "Check for update POST";
        ;;
    "download-pre")
        echo "Download PRE";
        ;;
    "download-post")
        echo "Download POST";
        ;;
    "install-pre")
        echo "Install PRE";
        ;;
    "install-post")
        echo "Install POST";
        ;;
esac

echo "${MESSAGE}" > /var/sota/ota.signal
echo "${RESULT}" > /var/sota/ota.result

echo "MESSAGE: ${MESSAGE}"
echo "CURRENT_TARGET: ${CURRENT_TARGET}"
echo "CURRENT_TARGET_NAME: ${CURRENT_TARGET_NAME}"
echo "INSTALL_TARGET_NAME: ${INSTALL_TARGET_NAME}"
echo "RESULT: ${RESULT}"

