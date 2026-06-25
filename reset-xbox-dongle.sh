#!/bin/sh

# Automatically search for the Xbox dongle (V1: 02e6, V2: 02fe)
get_dongle_path() {
    local path_file=$(grep -l -E "02fe|02e6" /sys/bus/usb/devices/*/idProduct 2>/dev/null | head -n 1)
    if [ -n "$path_file" ]; then
        basename $(dirname "$path_file")
    fi
}

if [ "$1" = "pre" ]; then
    # Unload drivers first so the dongle is released cleanly
    /usr/sbin/modprobe -r xone_gip_gamepad 2>/dev/null || true
    /usr/sbin/modprobe -r xone_gip_chatpad 2>/dev/null || true
    /usr/sbin/modprobe -r xone_gip         2>/dev/null || true
    /usr/sbin/modprobe -r xone_dongle      2>/dev/null || true
    sleep 1

    # Remove dongle from USB bus so it re-enumerates cleanly after resume
    DONGLE_PATH=$(get_dongle_path)
    if [ -n "$DONGLE_PATH" ]; then
        echo 1 > "/sys/bus/usb/devices/${DONGLE_PATH}/remove" 2>/dev/null || true
    fi

elif [ "$1" = "post" ]; then
    # Wait actively for the kernel to re-enumerate the dongle (max 30s)
    for i in $(seq 1 30); do
        DONGLE_PATH=$(get_dongle_path)
        if [ -n "$DONGLE_PATH" ]; then
            AUTH=$(cat "/sys/bus/usb/devices/${DONGLE_PATH}/authorized" 2>/dev/null)
            if [ "$AUTH" = "1" ]; then
                break
            fi
        fi
        sleep 1
        DONGLE_PATH=""
    done

    if [ -z "$DONGLE_PATH" ]; then
        exit 1
    fi

    # Extra buffer for the radio firmware to stabilize before cycling
    # Increase if "init radio failed: -110" persists
    sleep 5

    # Cycle authorization to force a clean radio firmware re-init
    echo 0 > "/sys/bus/usb/devices/${DONGLE_PATH}/authorized" 2>/dev/null || true
    sleep 1
    echo 1 > "/sys/bus/usb/devices/${DONGLE_PATH}/authorized" 2>/dev/null || true
    sleep 2

    # Reload drivers
    /usr/sbin/modprobe xone_dongle
    /usr/sbin/modprobe xone_gip
    /usr/sbin/modprobe xone_gip_gamepad
    /usr/sbin/modprobe xone_gip_chatpad
    sleep 1

    # Force Steam/udev to immediately recognize the controller as input device
    /usr/bin/udevadm trigger --subsystem-match=input --action=add
fi
