#!/system/bin/sh

ITERATION="$1"
PARTITION="$2"
OUTPUT="/data/dd-wr-speed"

if [ "$#" -ne 2 ]; then
    echo "ERROR: Usage: $0 ITERATION PARTITION"
    exit 1
fi

[ -d "${OUTPUT}" ] && mv "${OUTPUT}" "${OUTPUT}-$(date +%Y%m%d%H%M%S)"
mkdir -p "${OUTPUT}" && cd "${OUTPUT}"

# If partition specified, format it to vfat, and mount it to /mnt/dd_test.
# Then enter the mount point to do dd test.
if [ -n "${PARTITION}" ]; then
    partition_name="$(basename "${PARTITION}")"
    partition_numbers="$(grep "${partition_name}" /proc/partitions \
        | awk '{print $1","$2}')"

    if [ -z "${partition_numbers}" ]; then
        echo "ERROR: ${PARTITION} NOT found" && exit 1
    else
        # Attemp to umount it in case it is mounted by Android vold.
        umount "/dev/block/vold/public:${partition_numbers}" > /dev/null 2>&1
        umount "${PARTITION}" > /dev/null 2>&1

        echo "INFO: formatting ${PARTITION} to vfat..."
        busybox mkfs.vfat "${PARTITION}"
        sync && sleep 10

        mkdir -p /mnt/dd_test
        mount -t vfat "/dev/block/vold/public:${partition_numbers}" \
            /mnt/dd_test/
        if [ $? -eq 0 ]; then
            echo "INFO: Mounted ${PARTITION} to /mnt/dd_test"
        else
            echo "ERROR: failed to mount ${PARTITION}" && exit 1
        fi

        cd /mnt/dd_test
        echo "INFO: dd test directory: $(pwd)"
    fi
fi

# Run dd write/read test.
for i in $(seq "${ITERATION}"); do
    echo
    echo "INFO: Running dd wrtie test [$i/${ITERATION}]"
    echo 3 > /proc/sys/vm/drop_caches
    busybox dd if=/dev/zero of=dd.img bs=1048576 count=1024 conv=fsync 2>&1 \
        | tee  -a "${OUTPUT}"/dd-write-output.txt

    echo
    echo "INFO: Running dd read test [$i/${ITERATION}]"
    echo 3 > /proc/sys/vm/drop_caches
    busybox dd if=dd.img of=/dev/null bs=1048576 count=1024 2>&1 \
        | tee -a "${OUTPUT}"/dd-read-output.txt

    rm dd.img
done
