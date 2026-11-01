#!/usr/bin/env bash
# ==============================================================================
# DC VOLTAGE - Jio AirFiber 6J11 1-Click OpenWrt Flasher (Linux / macOS)
# Target Models : JIDU 6111, 6411, 6611, 6811, 6911 (Qualcomm IPQ50xx / IPQ95xx)
# Author        : DC VOLTAGE (https://github.com/dc-voltage)
# ==============================================================================

set -euo pipefail

# ANSI Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${GREEN}          DC VOLTAGE - JIO AIRFIBER 6J11 1-CLICK OPENWRT FLASHER             ${NC}"
echo -e "${YELLOW}  Supported: JIDU 6111 / JIDU 6411 / JIDU 6611 / JIDU 6811 / JIDU 6911      ${NC}"
echo -e "${CYAN}                  Author: DC VOLTAGE (github.com/dc-voltage)                  ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo ""

# 1. Locate files in current directory or prompt
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

FACTORY_IMG=$(ls ./*factory.ubi 2>/dev/null | head -n 1 || true)
SYSUPGRADE_IMG=$(ls ./*sysupgrade.bin 2>/dev/null | head -n 1 || true)

if [[ -z "$FACTORY_IMG" || ! -f "$FACTORY_IMG" ]]; then
    echo -e "${RED}[ERROR] No '*factory.ubi' found in directory: $SCRIPT_DIR${NC}"
    echo "Please download the factory UBI image and place it here."
    exit 1
fi

if [[ -z "$SYSUPGRADE_IMG" || ! -f "$SYSUPGRADE_IMG" ]]; then
    echo -e "${RED}[ERROR] No '*sysupgrade.bin' found in directory: $SCRIPT_DIR${NC}"
    echo "Please download the sysupgrade BIN image and place it here."
    exit 1
fi

if [[ ! -f "flash.sh" ]]; then
    echo -e "${RED}[ERROR] flash.sh script is missing!${NC}"
    exit 1
fi

echo -e "${GREEN}[✓] Detected Factory UBI  : ${FACTORY_IMG}${NC}"
echo -e "${GREEN}[✓] Detected Sysupgrade   : ${SYSUPGRADE_IMG}${NC}"
echo -e "${GREEN}[✓] Detected Shell Script : flash.sh${NC}"
echo ""

# 2. Router IP configuration
read -rp "Enter Stock Router IP [Press ENTER for default 192.168.31.1]: " USER_IP
STOCK_IP="${USER_IP:-192.168.31.1}"

echo -e "${BLUE}[*] Testing connection to Stock Router at ${STOCK_IP}...${NC}"
until ping -c 1 -W 1 "$STOCK_IP" &>/dev/null; do
    echo -e "${YELLOW}[*] Waiting for stock router to respond at ${STOCK_IP}...${NC}"
    sleep 3
done
echo -e "${GREEN}[✓] Connected to Stock Router (${STOCK_IP})!${NC}"
echo ""

# Clean stale host keys
ssh-keygen -R "$STOCK_IP" 2>/dev/null || true

# 3. Upload Factory UBI and flash.sh
echo -e "${BLUE}[*] [STEP 1/4] Uploading ${FACTORY_IMG} and flash.sh to /tmp/...${NC}"
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$FACTORY_IMG" flash.sh "root@${STOCK_IP}:/tmp/"
echo -e "${GREEN}[✓] Files uploaded successfully!${NC}"
echo ""

# 4. Trigger remote flash
echo -e "${BLUE}[*] [STEP 2/4] Triggering automated NAND slot detection and flash...${NC}"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${STOCK_IP}" \
    "sed -i 's/\r$//' /tmp/flash.sh 2>/dev/null; sh /tmp/flash.sh"

echo ""
echo -e "${YELLOW}[*] Factory UBI flashed into idle slot. Waiting 90 seconds for temporary OpenWrt reboot...${NC}"
sleep 90

# 5. Connect to OpenWrt at 192.168.1.1
OPENWRT_IP="192.168.1.1"
ssh-keygen -R "$OPENWRT_IP" 2>/dev/null || true

echo -e "${BLUE}[*] [STEP 3/4] Probing for OpenWrt at ${OPENWRT_IP}...${NC}"
until ping -c 1 -W 1 "$OPENWRT_IP" &>/dev/null; do
    echo -e "${YELLOW}[*] Waiting for OpenWrt gateway (${OPENWRT_IP})...${NC}"
    sleep 3
done
echo -e "${GREEN}[✓] Temporary OpenWrt is online at ${OPENWRT_IP}!${NC}"
echo ""

# 6. Upload and trigger sysupgrade
echo -e "${BLUE}[*] [STEP 4/4] Uploading permanent sysupgrade image: ${SYSUPGRADE_IMG}...${NC}"
sleep 5
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "$SYSUPGRADE_IMG" "root@${OPENWRT_IP}:/tmp/sysupgrade.bin"

echo -e "${YELLOW}[*] Applying permanent sysupgrade (merging partitions)...${NC}"
echo -e "${RED}[!] CRITICAL: DO NOT POWER OFF OR DISCONNECT CABLES!${NC}"
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@${OPENWRT_IP}" "sysupgrade -v -n /tmp/sysupgrade.bin"

echo ""
echo -e "${YELLOW}[*] Sysupgrade initiated. Waiting 90 seconds for final boot...${NC}"
sleep 90

echo -e "${CYAN}==============================================================================${NC}"
echo -e "${GREEN}            CONGRATULATIONS! OPENWRT INSTALLATION COMPLETE!                   ${NC}"
echo -e "${CYAN}==============================================================================${NC}"
echo ""
echo -e "Access your unlocked router:"
echo -e " - ${GREEN}LuCI WebUI :${NC} http://192.168.1.1"
echo -e " - ${GREEN}SSH Access :${NC} ssh root@192.168.1.1 (no password required)"
echo ""
echo -e "${CYAN}Engineering & Automation by DC VOLTAGE (github.com/dc-voltage)${NC}"
