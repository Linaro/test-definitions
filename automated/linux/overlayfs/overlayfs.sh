#!/bin/sh -ex

TEST_DIR=$(dirname "$(realpath "$0")")
OUTPUT="${TEST_DIR}/output"
export RESULT_FILE="${OUTPUT}/result.txt"

# shellcheck disable=SC1090
. "${TEST_DIR}/../../lib/sh-test-lib"
create_out_dir "${OUTPUT}"
cd "${OUTPUT}"
# PKG install will be skipped on unsupported distro.
install_deps "git"
git clone http://git.linaro.org/qa/unionmount-testsuite.git
cd unionmount-testsuite

tests="open-plain open-trunc open-creat open-creat-trunc open-creat-excl
       open-creat-excl-trunc noent-plain noent-trunc noent-creat
       noent-creat-trunc noent-creat-excl noent-creat-excl-trunc sym1-plain
       sym1-trunc sym1-creat sym1-creat-excl sym2-plain sym2-trunc sym2-creat
       sym2-creat-excl symx-plain symx-trunc symx-creat symx-creat-excl
       symx-creat-trunc truncate dir-open dir-weird-open dir-open-dir
       dir-weird-open-dir dir-sym1-open dir-sym1-weird-open dir-sym2-open
       dir-sym2-weird-open readlink mkdir rmdir hard-link hard-link-dir
       hard-link-sym unlink rename-file rename-empty-dir rename-new-dir
       rename-pop-dir rename-new-pop-dir rename-move-dir rename-mass
       rename-mass-2 rename-mass-3 rename-mass-4 rename-mass-5 rename-mass-dir
       rename-mass-sym impermissible"

if which python3; then
    py_cmd="python3"
else
    py_cmd="python2"
fi

for test in ${tests}; do
    for term_slash in 0 1; do
        if [ "${term_slash}" -eq 1 ]; then
            suffix="-termslash"
        else
            suffix=""
        fi

        test_cmd="${py_cmd} ./run --ov --ts=${term_slash} ${test}"
        info_msg "Running $test with command: ${test_cmd}"
        # run_test_case() usage: run_test_case test_cmd test_case_id
        run_test_case "${test_cmd}" "${test}${suffix}"
    done
done
