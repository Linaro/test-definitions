#!/bin/sh -e

# The purpose of UnixBench is to provide a basic indicator of the
# performance of a Unix-like system

# shellcheck disable=SC1091
. ../../lib/sh-test-lib

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"

while getopts 's:h' opt; do
    case "${opt}" in
        s) SKIP_INSTALL="${OPTARG}" ;;
        h|*) echo "Usage: $0 [-s <true|false>]" && exit 1 ;;
    esac
done

! check_root && error_msg "Please run this script as root."
create_out_dir "${OUTPUT}"
cd "${OUTPUT}"

install_deps "git gcc perl" "${SKIP_INSTALL}"
# We need the recent fixes in master branch. Once they are included in the next
# release, we can switch to release version.
git clone https://github.com/kdlucas/byte-unixbench
cd "byte-unixbench/UnixBench/"
# -march=native and -mtune=native are not included in Linaro ARM toolchian
# that older than v6. Comment they out here.
cp Makefile Makefile.bak
sed -i 's/OPTON += -march=native -mtune=native/#OPTON += -march=native -mtune=native/' Makefile

log_parser() {
    prefix="$1"
    logfile="$2"

    # Test Result.
    egrep "[0-9.]+ [a-zA-Z]+ +\([0-9.]+ s," "${logfile}" \
        | awk -v prefix="${prefix}" '{printf(prefix)};{for (i=1;i<=(NF-6);i++) printf("-%s",$i)};{printf(" pass %s %s\n"),$(NF-5),$(NF-4)}' \
        | tee -a "${RESULT_FILE}"

    # Index Values.
    egrep "[0-9]+\.[0-9] +[0-9]+\.[0-9] +[0-9]+\.[0-9]" "${logfile}" \
        | awk -v prefix="${prefix}" '{printf(prefix)};{for (i=1;i<=(NF-3);i++) printf("-%s",$i)};{printf(" pass %s index\n"),$NF}' \
        | tee -a "${RESULT_FILE}"

    ms=$(grep "System Benchmarks Index Score" "${logfile}" | awk '{print $NF}')
    add_metric "${prefix}-System-Benchmarks-Index-Score" "pass" "${ms}" "index"
}

# Run a single copy.
./Run -c "1" | tee "${OUTPUT}/unixbench-single.txt"
log_parser "single" "${OUTPUT}/unixbench-single.txt"

# Run the number of CPUs copies.
if [ "$(nproc)" -gt 1 ]; then
    ./Run -c "$(nproc)" | tee "${OUTPUT}/unixbench-multiple.txt"
    log_parser "multiple" "${OUTPUT}/unixbench-multiple.txt"
fi
