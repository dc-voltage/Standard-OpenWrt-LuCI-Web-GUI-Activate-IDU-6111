#!/bin/sh
# ==============================================================================
# DC VOLTAGE - Jio AirFiber 6J11 Partition & Calibration Backup Utility
# Author: DC VOLTAGE (https://github.com/dc-voltage)
# Run directly on the router via SSH prior to flashing!
# ==============================================================================

set -e

BACKUP_DIR="/tmp/stock_backup"
mkdir -p "$BACKUP_DIR"

echo "=========================================================="
echo "    DC VOLTAGE - JIO 6J11 SYSTEM BACKUP UTILITY"
echo "=========================================================="
echo "[+] Creating backup directory in $BACKUP_DIR..."

# 1. Backup Manufacturing & Calibration Data
echo "[*] Backing up Jio Manufacturing & Board Data..."
if command -v jioMfgData >/dev/null 2>&1; then
    jioMfgData get all > "$BACKUP_DIR/jioMfgData_all.txt" 2>&1 || true
    echo "[+] Saved jioMfgData_all.txt"
fi

# 2. Backup U-Boot Environment and Passwords
echo "[*] Extracting U-Boot environment / partition table..."
cat /proc/mtd > "$BACKUP_DIR/proc_mtd.txt"
cat /proc/cmdline > "$BACKUP_DIR/proc_cmdline.txt"

# 3. Dump Dual Rootfs partitions
echo "[*] Backing up rootfs partitions (this may take a minute)..."
DEV_ROOTFS=$(grep '"rootfs"' /proc/mtd | cut -d: -f1)
DEV_ROOTFS1=$(grep '"rootfs_1"' /proc/mtd | cut -d: -f1)

if [ -n "$DEV_ROOTFS" ]; then
    echo "[*] Dumping /dev/$DEV_ROOTFS (rootfs)..."
    cat "/dev/$DEV_ROOTFS" > "$BACKUP_DIR/stock_rootfs.bin"
fi

if [ -n "$DEV_ROOTFS1" ]; then
    echo "[*] Dumping /dev/$DEV_ROOTFS1 (rootfs_1)..."
    cat "/dev/$DEV_ROOTFS1" > "$BACKUP_DIR/stock_rootfs_1.bin"
fi

# 4. Create archive
echo "[*] Compressing backup archive..."
cd /tmp
tar -czf jio6j11_stock_backup.tar.gz -C "$BACKUP_DIR" .
rm -rf "$BACKUP_DIR"

echo ""
echo "=========================================================="
echo "[✓] BACKUP COMPLETE: /tmp/jio6j11_stock_backup.tar.gz"
echo "=========================================================="
echo "Download this file to your PC immediately via SCP:"
echo "  scp root@<router-ip>:/tmp/jio6j11_stock_backup.tar.gz ."
echo "Keep this safe offline before flashing third-party firmware!"
echo "=========================================================="
