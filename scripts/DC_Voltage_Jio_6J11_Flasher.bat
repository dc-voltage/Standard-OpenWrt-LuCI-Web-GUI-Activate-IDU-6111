@echo off
setlocal enabledelayedexpansion
title DC VOLTAGE - Jio AirFiber 6J11 1-Click OpenWrt Flasher
color 0B

echo ==============================================================================
echo           DC VOLTAGE - JIO AIRFIBER 6J11 1-CLICK OPENWRT FLASHER
echo   Supported Models: JIDU 6111 / JIDU 6411 / JIDU 6611 / JIDU 6811 / JIDU 6911
echo                 Author: DC VOLTAGE (github.com/dc-voltage)
echo ==============================================================================
echo.

REM 1. Verify required files in current folder
set "FACTORY="
for %%f in (*factory.ubi) do set "FACTORY=%%f"

set "SYSUPGRADE="
for %%f in (*sysupgrade.bin) do set "SYSUPGRADE=%%f"

if "%FACTORY%"=="" (
    echo [ERROR] No OpenWrt '*factory.ubi' found in current folder!
    echo Please place the factory UBI image into this folder and retry.
    echo.
    pause
    exit /b 1
)

if "%SYSUPGRADE%"=="" (
    echo [ERROR] No OpenWrt '*sysupgrade.bin' found in current folder!
    echo Please place the sysupgrade BIN image into this folder and retry.
    echo.
    pause
    exit /b 1
)

if not exist "flash.sh" (
    echo [ERROR] 'flash.sh' script missing from current directory!
    echo.
    pause
    exit /b 1
)

echo [✓] Found Factory Image    : %FACTORY%
echo [✓] Found Sysupgrade Image : %SYSUPGRADE%
echo [✓] Found Flasher Script   : flash.sh
echo.

REM 2. Router IP Address configuration
set "ROUTER_STOCK_IP=192.168.31.1"
echo [?] Enter Stock Router IP address [Press ENTER for default %ROUTER_STOCK_IP%]:
set /p USER_INPUT_IP=
if not "%USER_INPUT_IP%"=="" set "ROUTER_STOCK_IP=%USER_INPUT_IP%"

echo.
echo [*] Checking connectivity to Stock Router at %ROUTER_STOCK_IP%...
:WAIT_STOCK
ping -n 1 -w 1000 %ROUTER_STOCK_IP% >nul 2>&1
if errorlevel 1 (
    echo [*] Waiting for stock router to respond at %ROUTER_STOCK_IP%...
    timeout /t 3 >nul
    goto WAIT_STOCK
)
echo [✓] Connected to Stock Router (%ROUTER_STOCK_IP%)!
echo.

REM 3. Uploading factory image and flash script to router
echo [*] [STEP 1/4] Uploading %FACTORY% and flash.sh to router /tmp/...
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "%FACTORY%" flash.sh root@%ROUTER_STOCK_IP%:/tmp/
if errorlevel 1 (
    echo.
    echo [ERROR] SCP transfer failed!
    echo Please ensure:
    echo  1. Password injection exploit was executed (dropbear SSH is running).
    echo  2. PC Ethernet is connected to LAN port of the Jio Router.
    echo.
    pause
    exit /b 1
)
echo [✓] Firmware and script transferred successfully!
echo.

REM 4. Executing flash.sh on the router
echo [*] [STEP 2/4] Triggering automated NAND slot detection and flash...
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@%ROUTER_STOCK_IP% "sed -i 's/\r$//' /tmp/flash.sh 2>/dev/null; sh /tmp/flash.sh"

echo.
echo [*] Factory image flashed into idle NAND slot!
echo [*] Waiting 90 seconds for router to reboot into temporary OpenWrt...
timeout /t 90 /nobreak
echo.

REM 5. Probing for temporary OpenWrt
set "OPENWRT_IP=192.168.1.1"
echo [*] [STEP 3/4] Probing for OpenWrt gateway at %OPENWRT_IP%...
:WAIT_OPENWRT
ping -n 1 -w 1000 %OPENWRT_IP% >nul 2>&1
if errorlevel 1 (
    echo [*] Waiting for OpenWrt network stack to initialize...
    timeout /t 3 >nul
    goto WAIT_OPENWRT
)
echo [✓] Temporary OpenWrt is LIVE at %OPENWRT_IP%!
echo.

REM 6. Uploading and executing permanent sysupgrade
echo [*] [STEP 4/4] Uploading permanent sysupgrade image: %SYSUPGRADE%...
timeout /t 5 >nul
scp -O -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL "%SYSUPGRADE%" root@%OPENWRT_IP%:/tmp/sysupgrade.bin
if errorlevel 1 (
    echo [ERROR] Failed to transfer sysupgrade.bin to %OPENWRT_IP%!
    pause
    exit /b 1
)

echo [*] Applying permanent sysupgrade (merging partitions into unified OpenWrt)...
echo [*] WARNING: DO NOT UNPLUG POWER UNDER ANY CIRCUMSTANCES!
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=NUL root@%OPENWRT_IP% "sysupgrade -v -n /tmp/sysupgrade.bin"

echo.
echo [*] Sysupgrade in progress. Waiting 90 seconds for final boot...
timeout /t 90 /nobreak
echo.

echo ==============================================================================
echo                 CONGRATULATIONS! OPENWRT INSTALLATION COMPLETE!
echo ==============================================================================
echo.
echo Your Jio AirFiber 6J11 router is now running full OpenWrt!
echo.
echo  - OpenWrt LuCI Web Interface : http://192.168.1.1
echo  - Default SSH Access         : ssh root@192.168.1.1 (no password)
echo.
echo Branded and engineered with precision by DC VOLTAGE.
echo ==============================================================================
echo.
pause
