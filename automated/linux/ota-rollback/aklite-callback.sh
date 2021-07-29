#!/bin/bash -e

echo "${MESSAGE}" > /var/sota/ota.signal
echo "${RESULT}" > /var/sota/ota.result
