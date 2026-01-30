#!/bin/sh

echo "========================================"
echo " OpenClash Auto DIRECT + Huawei Recovery"
echo " UNINSTALLER"
echo "========================================"

BIN_DIR="/usr/bin"
INIT_DIR="/etc/init.d"

OC_SCRIPT="$BIN_DIR/oc-direct.sh"
HUAWEI_SCRIPT="$BIN_DIR/huawei.py"
INIT_SCRIPT="$INIT_DIR/oc-direct"

# --- ROOT CHECK ---
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Please run as root"
    exit 1
fi

echo "[1/6] Stop service"
/etc/init.d/oc-direct stop 2>/dev/null

echo "[2/6] Disable autostart"
/etc/init.d/oc-direct disable 2>/dev/null

echo "[3/6] Remove init.d service"
rm -f "$INIT_SCRIPT"

echo "[4/6] Remove scripts"
rm -f "$OC_SCRIPT"
rm -f "$HUAWEI_SCRIPT"

echo "[5/6] Cleanup temp files"
rm -f /tmp/oc.log
rm -f /tmp/oc_state
rm -f /tmp/huawei_active

echo "[6/6] DONE"
echo "----------------------------------------"
echo " All components removed successfully"
echo "----------------------------------------"
