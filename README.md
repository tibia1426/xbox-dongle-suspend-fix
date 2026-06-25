# xbox-dongle-suspend-fix
Fix for Xbox Wireless Dongle/Adapter standby/suspend issues on Linux/Bazzite.

## Problem Description
In BazziteOS (and other Fedora Silverblue-based systems), especially on AMD hardware, you might encounter an issue where the Xbox Wireless Dongle/Adapter (using the `xone` driver) fails to work correctly after waking up from sleep/standby (S3). The controller appears to connect to the dongle, but the operating system and Steam do not recognize it as an input device.

## Solution
The most reliable fix is to physically remove the dongle from the kernel before going to sleep, unload the drivers, and force a rescan of the USB port upon waking up before reloading the drivers. An additional `udevadm` command at the end eliminates the input delay in Steam after waking up.

---

## Installation

Clone or download this repository to your local machine, open a terminal in the downloaded folder, and follow these steps:

### 1. Install the Reset Script
Copy the script to your local binaries directory and make it executable:

```bash
sudo cp reset-xbox-dongle.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/reset-xbox-dongle.sh
```

### 2. Set up the Systemd Service
Copy the service file to the systemd directory to robustly intercept the suspend trigger (this works perfectly with Gamescope):

```bash
sudo cp reset-xbox-dongle.service /etc/systemd/system/
```

### 3. Enable the Service
Reload the systemd daemon and enable the service so it runs automatically:

```bash
sudo systemctl daemon-reload
sudo systemctl enable reset-xbox-dongle.service
```

### 4. Disable USB Autosuspend

To prevent the kernel from suspending the dongle between standby cycles (which can cause internal firmware timeouts), USB autosuspend should be disabled for this device.

Create the file `/etc/udev/rules.d/99-xbox-dongle-nosuspend.rules` — the file is included in this repository as `99-xbox-dongle-nosuspend.rules`.

Copy it to the correct location:

```bash
sudo cp 99-xbox-dongle-nosuspend.rules /etc/udev/rules.d/
```

Apply the rule immediately without rebooting:

```bash
sudo udevadm control --reload-rules
sudo udevadm trigger
```
## Known Issues

Despite this fix, occasional connection failures between the controller and the dongle may still occur after waking from standby. This is a hardware-level limitation caused by a timing bug in certain AMD USB controllers (`init radio failed: -110`), which prevents the dongle's radio firmware from initializing correctly — even after driver reloads or re-authorization.

If the controller does not reconnect after resume (indicated by a slow blinking light on the controller), the only reliable recovery is to **physically unplug and replug the dongle**. This issue occurs less frequently with this fix in place, but cannot be fully eliminated through software alone.

### Reducing the frequency

If you experience this issue regularly, try increasing the stabilization delay in `reset-xbox-dongle.sh`:

```bash
# Increase from 5 to 8 if "init radio failed: -110" persists after resume
sleep 8
```

Additionally, make sure the dongle is connected to a USB port driven by the **AMD Matisse USB controller** (if available on your board), rather than a secondary controller such as ASMedia ASM1142, which is more prone to resume failures.

## Usage
* The system now works fully automatically in the background, regardless of which USB port the dongle is connected to.
* When the system goes to sleep, the dongle is deactivated.
* Upon waking up, the service reinitializes the dongle. Once the process is complete, the controller will connect and be immediately ready to use in Steam without any input lag.

## Acknowledgments
Please note that an AI (Large Language Model) was used to assist in troubleshooting the hardware issue, finding the solution, and writing the code for this repository.
