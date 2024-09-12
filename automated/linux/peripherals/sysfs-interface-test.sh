#!/bin/sh

OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
mkdir $OUTPUT
export RESULT_FILE

# ----------------------
# Peripheral Validation
# ----------------------

# Function to validate USB devices
validate_usb_devices() {
    echo "=== Validating USB Devices ==="
    USB_PATH="/sys/bus/usb/devices/"
    if [ -d "$USB_PATH" ]; then
        echo "usb-sysfs-test pass" >> $RESULT_FILE
        usb_devices=$(ls -1 $USB_PATH | grep -E '^[0-9]+-[0-9]+$')
        if [ -z "$usb_devices" ]; then
            echo "usb-device-test fail" >> $RESULT_FILE
            echo "No USB devices found."
        else
            echo "usb-device-test pass" >> $RESULT_FILE
            echo "USB devices found:"
            echo "$usb_devices"
        fi
    else
        echo "USB sysfs directory not found."
        echo "usb-sysfs-test fail" >> $RESULT_FILE
    fi
    echo ""
}

# Function to validate network interfaces
validate_network_interfaces() {
    echo "=== Validating Network Interfaces ==="
    NETWORK_PATH="/sys/class/net/"
    if [ -d "$NETWORK_PATH" ]; then
        echo "network-sysfs-test pass" >> $RESULT_FILE
        interfaces=$(ls -1 $NETWORK_PATH)
        if [ -z "$interfaces" ]; then
            echo "network-interface-test fail" >> $RESULT_FILE
            echo "No network interfaces found."
        else
            echo "network-interface-test pass" >> $RESULT_FILE
            echo "Network interfaces found:"
            echo "$interfaces"
        fi
    else
        echo "network-sysfs-test fail" >> $RESULT_FILE
        echo "Network interface sysfs directory not found."
    fi
    echo ""
}

# Function to validate block devices
validate_block_devices() {
    echo "=== Validating Block Devices (Storage) ==="
    BLOCK_PATH="/sys/class/block/"
    if [ -d "$BLOCK_PATH" ]; then
        echo "block-sysfs-test pass" >> $RESULT_FILE
        block_devices=$(ls -1 $BLOCK_PATH)
        if [ -z "$block_devices" ]; then
            echo "block-device-test fail" >> $RESULT_FILE
            echo "No block devices found."
        else
            echo "block-device-test pass" >> $RESULT_FILE
            echo "Block devices found:"
            echo "$block_devices"
        fi
    else
        echo "block-sysfs-test fail" >> $RESULT_FILE
        echo "Block device sysfs directory not found."
    fi
    echo ""
}

# Function to validate Wi-Fi status
validate_wifi() {
    echo "=== Validating Wi-Fi Status ==="
    WIFI_INTERFACE=$(ls /sys/class/net | grep -E 'wl.*[0-9]+')
    if [ -n "$WIFI_INTERFACE" ]; then
        echo "wifi-sysfs-test pass" >> $RESULT_FILE
        echo "Wi-Fi interface detected: $WIFI_INTERFACE"
        echo "Checking if Wi-Fi is up..."
        state=$(cat /sys/class/net/$WIFI_INTERFACE/operstate)
        if [ "$state" = "up" ]; then
            echo "wifi-up-test pass" >> $RESULT_FILE
            echo "Wi-Fi is up and running."
        else
            echo "wifi-up-test fail" >> $RESULT_FILE
            echo "Wi-Fi is down."
        fi
    else
        echo "wifi-sysfs-test fail" >> $RESULT_FILE
        echo "No Wi-Fi interface found."
    fi
    echo ""
}

# Function to validate Bluetooth status
validate_bluetooth() {
    echo "=== Validating Bluetooth Status ==="
    BT_PATH="/sys/class/bluetooth/"
    if [ -d "$BT_PATH" ]; then
        echo "bt-sysfs-test pass" >> $RESULT_FILE
        bluetooth_devices=$(ls -1 $BT_PATH)
        if [ -z "$bluetooth_devices" ]; then
            echo "bt-device-test fail" >> $RESULT_FILE
            echo "No Bluetooth devices found."
        else
            echo "Bluetooth devices found:"
            echo "bt-device-test pass" >> $RESULT_FILE
            echo "$bluetooth_devices"
            hciconfig_output=$(hciconfig)
            if [[ $hciconfig_output == *"UP RUNNING"* ]]; then
                echo "Bluetooth is active."
            else
                echo "Bluetooth is not active."
            fi
        fi
    else
        echo "bt-sysfs-test fail" >> $RESULT_FILE
        echo "Bluetooth sysfs directory not found."
    fi
    echo ""
}

# Function to validate sound devices
validate_sound() {
    echo "=== Validating Sound Devices ==="
    SOUND_PATH="/sys/class/sound/"
    if [ -d "$SOUND_PATH" ]; then
        echo "snd-sysfs-test pass" >> $RESULT_FILE
        sound_devices=$(ls -1 $SOUND_PATH)
        if [ -z "$sound_devices" ]; then
            echo "snd-device-test fail" >> $RESULT_FILE
            echo "No sound devices found."
        else
            echo "snd-device-test pass" >> $RESULT_FILE
            echo "Sound devices found:"
            echo "$sound_devices"
        fi
        echo "Checking default audio output..."
        default_audio=$(aplay -l | grep -i 'card' | head -n 1)
        if [ -z "$default_audio" ]; then
            echo "No sound card detected."
        else
            echo "Default audio output detected: $default_audio"
        fi
    else
        echo "snd-sysfs-test fail" >> $RESULT_FILE
        echo "Sound sysfs directory not found."
    fi
    echo ""
}

# Function to validate display devices
validate_display() {
    echo "=== Validating Display Devices ==="
    DISPLAY_PATH="/sys/class/drm/"
    if [ -d "$DISPLAY_PATH" ]; then
        echo "drm-sysfs-test pass" >> $RESULT_FILE
        display_devices=$(ls -1 $DISPLAY_PATH | grep -E 'card[0-9]-')
        if [ -z "$display_devices" ]; then
            echo "drm-interface-test fail" >> $RESULT_FILE
            echo "No display devices found."
        else
            echo "drm-interface-test pass" >> $RESULT_FILE
            echo "Display devices found:"
            echo "$display_devices"
        fi
        echo "Checking connected displays..."
        xrandr_output=$(xrandr --listmonitors | grep 'Monitors')
        if [ -n "$xrandr_output" ]; then
            echo "Connected displays:"
            xrandr --listmonitors | grep -v 'Monitors'
        else
            echo "No displays connected."
        fi
    else
        echo "drm-sysfs-test fail" >> $RESULT_FILE
        echo "Display sysfs directory not found."
    fi
    echo ""
}

# Main test suite runner
run_tests() {
    echo "Starting Peripheral Validation Test Suite..."

    validate_usb_devices
    validate_network_interfaces
    validate_block_devices
    validate_wifi
    validate_bluetooth
    validate_sound
    validate_display

    echo "Peripheral validation test suite complete."
}

# Run the test suite
run_tests
