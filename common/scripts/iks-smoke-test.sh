# "CONFIG_BL_SWITCHER=y" is required in kernel config.
# Enable and disable big.LITTLE switcher can be done in run time by using
# userspace entry  "/sys/kernel/bL_switcher/active"
# This test is to enable and disable big.LITTLE IKS switcher 100 times.

check_kernel_oops()
{
        KERNEL_ERR=`dmesg | grep "Unable to handle kernel"`
        if [ -n "$KERNEL_ERR" ]; then
                echo "Kernel OOPS. Abort!!"
                echo "IKS-smoke-test: FAIL"
                exit 1
        fi
}

ERR_CODE=0
switcher_disable ()
{
        echo 0 > /sys/kernel/bL_switcher/active
        ERR_CODE=$?
        if [ $ERR_CODE -ne 0 ]; then
                echo "not able to disable switcher"
                echo "IKS-switcher-disable: FAIL"
                exit 1
        fi
        check_kernel_oops
}

switcher_enable ()
{
        echo 1 > /sys/kernel/bL_switcher/active
        ERR_CODE=$?
        if [ $ERR_CODE -ne 0 ]; then
                echo "not able to enable switcher"
                echo "IKS-switcher-enable: FAIL"
                exit 1
        fi
        check_kernel_oops
}

check_iks()
{
        if [ -e /sys/kernel/bL_switcher/active ]; then
                echo "******************************"
                echo "IKS Implemented on this device"
                echo "******************************"
        else
                echo "IKS-not-implemented-on-this-device: SKIP"
                echo "skipping IKS tests"
                exit 1
        fi
}

enable_and_disable_switcher_100_times()
{
        i=0
        while [ $i -lt 100 ]; do
                switcher_enable
                sleep 1
                switcher_disable
                i=$(($i + 1))
        done
}

check_iks
enable_and_disable_switcher_100_times
echo "enable-and-disable-switcher-100-times: PASS"
check_kernel_oops
echo "IKS-smoke-test: PASS"
