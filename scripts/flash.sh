#!/bin/sh
# ==============================================================================
# DC VOLTAGE - Jio AirFiber 6J11 Series Router OpenWrt Flasher
# Target Models : JIDU 6111, 6411, 6611, 6811, 6911 (Qualcomm IPQ50xx / IPQ95xx)
# Author        : DC VOLTAGE (https://github.com/dc-voltage)
# Description   : Router-side POSIX shell script to detect active/idle NAND slot,
#                 format idle slot with factory.ubi, and configure U-Boot env.
# ==============================================================================

set -e

echo "=========================================================="
echo "    DC VOLTAGE - JIO 6J11 OPENWRT AUTO-FLASHER"
echo "=========================================================="
echo ""

# 1. Search for factory image in /tmp
FACTORY=$(ls /tmp/*factory.ubi 2>/dev/null | head -n 1)

if [ -z "$FACTORY" ] || [ ! -f "$FACTORY" ]; then
    echo "[-] [ERROR] No *factory.ubi found in /tmp!"
    echo "[-] Please upload your OpenWrt factory UBI image to /tmp first."
    exit 1
fi
echo "[+] Detected Factory UBI Image: $FACTORY"

# 2. Inspect active boot slot from /proc/cmdline
CMDLINE=$(cat /proc/cmdline)
echo "[+] Kernel command line: $CMDLINE"

ACT=$(echo "$CMDLINE" | grep -oE 'ubi\.mtd=[^ ]+' | cut -d= -f2)

if [ -z "$ACT" ]; then
    # Fallback check
    if echo "$CMDLINE" | grep -q "rootfs_1"; then
        ACT="rootfs_1"
    else
        ACT="rootfs"
    fi
fi
echo "[+] Current Active NAND Slot : $ACT"

# 3. Determine idle slot (dual-boot target)
if [ "$ACT" = "rootfs" ]; then
    IDLE="rootfs_1"
else
    IDLE="rootfs"
fi
echo "[+] Target Idle NAND Slot   : $IDLE (Safe to flash)"

# 4. Locate target MTD device node in /proc/mtd
DEV=$(grep "\"$IDLE\"" /proc/mtd | cut -d: -f1)
if [ -z "$DEV" ]; then
    echo "[-] [ERROR] Could not resolve MTD device for $IDLE in /proc/mtd!"
    exit 1
fi

NUM=$(echo "$DEV" | tr -dc '0-9')
echo "[+] Target MTD Partition     : /dev/$DEV (MTD #$NUM)"

# 5. Retrieve physical offset and size from sysfs
if [ ! -d "/sys/class/mtd/$DEV" ]; then
    echo "[-] [ERROR] sysfs path /sys/class/mtd/$DEV does not exist!"
    exit 1
fi

OFF=$(printf "0x%x" $(cat /sys/class/mtd/$DEV/offset))
SIZ=$(printf "0x%x" $(cat /sys/class/mtd/$DEV/size))
echo "[+] Partition Geometry       : Offset=$OFF, Size=$SIZ"

# 6. Detach existing UBI bindings if mapped
echo "[*] Detaching MTD #$NUM from UBI layer if active..."
ubidetach -m "$NUM" 2>/dev/null || true

# 7. Format and write the OpenWrt Factory UBI image
echo "[*] Writing OpenWrt Factory UBI image to /dev/$DEV..."
echo "[*] PLEASE DO NOT DISCONNECT POWER OR REBOOT NOW!"
ubiformat "/dev/$DEV" -y -f "$FACTORY"
echo "[+] Factory UBI written successfully!"

# 8. Update U-Boot environment variables
echo "[*] Configuring U-Boot bootargs and bootcmd..."
fw_setenv mtdids 'nand0=nand0'
fw_setenv mtdparts "mtdparts=nand0:${SIZ}@${OFF}(${IDLE})"
fw_setenv bootcmd "ubi detach; ubi part ${IDLE}; ubi read 0x46000000 kernel; bootm 0x46000000"

echo ""
echo "=========================================================="
echo "    FLASH COMPLETE! SYSTEM REBOOTING..."
echo "=========================================================="
echo "[+] The router will now reboot into temporary OpenWrt."
echo "[+] Once booted, connect to: http://192.168.1.1"
echo "[+] Remember to perform permanent sysupgrade next."
echo "=========================================================="
echo ""

sleep 3
reboot
