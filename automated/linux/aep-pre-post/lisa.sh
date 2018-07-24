#!/bin/bash -ex
# shellcheck disable=SC1090

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
SKIP_INSTALL="false"
LISA_REPOSITORY="https://github.com/ARM-software/lisa"
LISA_REF="master"
LISA_SCRIPT="ipynb/wltests/sched-evaluation-full.py"

usage() {
    echo "Usage: $0 [-t <lisa_repository_ref>] [-r <lisa_repository>] [-s <lisa_script>] [-S <skip_install>]" 1>&2
    exit 1
}

while getopts ":t:r:s:S:" opt; do
    case "${opt}" in
        t) LISA_REF="${OPTARG}" ;;
        r) LISA_REPOSITORY="${OPTARG}" ;;
        s) LISA_SCRIPT="${OPTARG}" ;;
        S) SKIP_INSTALL="${OPTARG}" ;;
        *) usage ;;
    esac
done

. "${TEST_DIR}/../../lib/sh-test-lib"

! check_root && error_msg "Please run this test as root."
cd "${TEST_DIR}"
create_out_dir "${OUTPUT}"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE

if [ "${SKIP_INSTALL}" = "true" ] || [ "${SKIP_INSTALL}" = "True" ]; then
    info_msg "Dependency and python2 venv installation skipped"
    test -d .venv || error_msg "python2 venv for LISA is required, but not found!"
    . .venv/bin/activate
else
    PKGS="virtualenv build-essential autoconf automake libtool pkg-config trace-cmd sshpass kernelshark nmap net-tools tree libfreetype6-dev libpng12-dev python-pip python-dev python-tk"
    install_deps "${PKGS}"
    virtualenv --python=python2 .venv
    . .venv/bin/activate
    pip install --quiet matplotlib numpy nose Cython trappy bart-py devlib psutil wrapt scipy IPython
    git clone "${LISA_REPOSITORY}" lisa
    (
    cd lisa
    git checkout "${LISA_REF}"
    )
fi
# TODO: check if lisa directory exists
cd lisa
. init_env
lisa-update submodules
python "${LISA_SCRIPT}"
ls
for FILE in *.csv
do
    python "${TEST_DIR}/postprocess_lisa_results.py" -f "${FILE}" -o "${RESULT_FILE}"
done
