#!/bin/sh
 
# Automatically search for the Xbox dongle (V1: 02e6, V2: 02fe)
get_dongle_path() {
    local path_file=$(grep -l -E "02fe|02e6" /sys/bus/usb/devices/*/idProduct 2>/dev/null | head -n 1)
    if [ -n "$path_file" ]; then
        basename $(dirname "$path_file")
    fi
}
 
if [ "$1" = "pre" ]; then
    # BEFORE standby: Find path and remove dongle
    DONGLE_PATH=$(get_dongle_path)
    if [ -n "$DONGLE_PATH" ]; then
        echo 1 > "/sys/bus/usb/devices/${DONGLE_PATH}/remove" 2>/dev/null || true
    fi
 
    # Unload drivers cleanly
    /usr/sbin/modprobe -r xone_gip_gamepad 2>/dev/null || true
    /usr/sbin/modprobe -r xone_gip_chatpad 2>/dev/null || true
    /usr/sbin/modprobe -r xone_gip         2>/dev/null || true
    /usr/sbin/modprobe -r xone_dongle      2>/dev/null || true
 
elif [ "$1" = "post" ]; then
    # AFTER standby: Wait for the kernel to wake up the USB bus
    sleep 3
 
    # Find path again and enumerate port
    DONGLE_PATH=$(get_dongle_path)
    if [ -n "$DONGLE_PATH" ]; then
        echo 0 > "/sys/bus/usb/devices/${DONGLE_PATH}/authorized" 2>/dev/null || true
        sleep 1
        echo 1 > "/sys/bus/usb/devices/${DONGLE_PATH}/authorized" 2>/dev/null || true
        sleep 2
    fi
 
    # Load drivers
    /usr/sbin/modprobe xone_dongle
    /usr/sbin/modprobe xone_gip
    /usr/sbin/modprobe xone_gip_gamepad
    /usr/sbin/modprobe xone_gip_chatpad
    sleep 1
 
    # Forces the system (and Steam) to process new input devices IMMEDIATELY
    /usr/bin/udevadm trigger --subsystem-match=input --action=add
fi
