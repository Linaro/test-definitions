#!/bin/sh -e

usage() {
    echo "Usage: $0 <-c cpus> <-s [true|false]>" 1>&2
    echo " -c CPU's to isolate and verify"
    echo " -s Skip dependenciy installs"
    echo " -t Git tag to use"
    echo " example:"
    echo " $0 -c 1,2 -s false -t v0.2"
    exit 1
}

while getopts "c:s:t:" o; do
    case "$o" in
	c) CPUS="${OPTARG}" ;;
	s) SKIP_INSTALL="${OPTARG}" ;;
	t) GIT_TAG="${OPTARG}" ;;
	*) usage ;;
    esac
done

[ -z "${CPUS}" ] && usage
[ -z "${SKIP_INSTALL}" ] && usage
[ -z "${GIT_TAG}" ] && usage

. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
TEST_LOG="${OUTPUT}/isolation-test-output.txt"

create_out_dir "${OUTPUT}"

if [ "${SKIP_INSTALL}" = "false" ] || [ "${SKIP_INSTALL}" = "False" ]; then
    install_deps "git stress cpuset gzip"
    git clone git://git.linaro.org/lng/task-isolation.git
fi

cd task-isolation
git checkout tags/"${GIT_TAG}" -b "${GIT_TAG}"
./isolate-task.sh -v -c "${CPUS}" sleep "10" 2>&1 | tee "${TEST_LOG}"

grep TEST_ISOLATION_CORE_ "${TEST_LOG}" > "${RESULT_FILE}"
