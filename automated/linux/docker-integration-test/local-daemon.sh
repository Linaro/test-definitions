#!/bin/sh -ex

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
RESULT_FILE="${OUTPUT}/result.txt"

RELEASE="v18.03.0-ce"
SKIP_INSTALL="false"

# SC1090: Can't follow non-constant source. Use a directive to specify location.
# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"
create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

usage() {
    echo "Usage: $0 [-r <release>] [-s <true|false>]" 1>&2
    exit 1
}

while getopts "r:s:h" opt; do
    case "$opt" in
        r) RELEASE="${OPTARG}" ;;
        s) SKIP_INSTALL="${OPTARG}" ;;
        *) usage ;;
    esac
done

if "${SKIP_INSTALL}"; then
    info_msg "Software installation skipped"
    # Check if required software pre-installed.
    pkgs="git make docker"
    for i in ${pkgs}; do
        if ! command -v "$i"; then
            error_msg "$i is required but not installed!"
        fi
    done
else
    install_deps "git make"
    if ! command -v docker; then
        install_deps "curl"
        curl -fsSL get.docker.com -o get-docker.sh
        sh get-docker.sh || error_msg "Failed to install docker-ce!"
    fi
fi

git clone https://github.com/docker/docker-ce
cd docker-ce/components/engine/
git checkout "${RELEASE}" -b "${RELEASE}-test"
# Enable shell xtrace and continue on test failure.
sed -i 's/set -e -o pipefail/set -x -o pipefail/' hack/make/test-integration
sed -i 's/); then exit 1; fi/); then echo "ERROR: non-zero exit"; fi/' hack/make/.integration-test-helpers
git config --global user.email "tester@example.com"
git config --global user.name "tester"
git add -u hack/make/
git commit -m 'test-integration: continue on test failure'
# Skip legacy test integration-cli for the following reasons.
# - buggy, at least on ARM.
# - takes too long on ARM.
# - deprecated in the Moby project.
sed -i "s/run_test_integration_legacy_suites$//" hack/make/.integration-test-helpers
git add -u hack/make/
git commit -m "test-integration: skip integration-cli tests"

# Test run.
if make test-integration; then
    echo "test-integration-run pass" | tee -a "${RESULT_FILE}"
else
    echo "test-integration-run fail" | tee -a "${RESULT_FILE}"
fi

# Parse test log.
LOGFILE="bundles/test-integration/test.log"
grep -Ee '--- (PASS|SKIP/FAIL):' "${LOGFILE}" \
    | sed 's/PASS:/pass/; s/SKIP:/skip/; s/FAIL:/fail/' \
    | awk '{printf("%s %s\n",$3,$2)}' \
    | tee -a "${RESULT_FILE}"

# Cleanup
echo 'y' | docker system prune -a
