#!/bin/sh

echo "========================================"
echo " OpenClash Auto DIRECT + Huawei Recovery"
echo " INSTALLER"
echo "========================================"

REPO_RAW="https://raw.githubusercontent.com/rizkyyp12/huawei-curl-auto-ava/main"

BIN_DIR="/usr/bin"
INIT_DIR="/etc/init.d"

OC_SCRIPT="$BIN_DIR/oc-direct.sh"
HUAWEI_SCRIPT="$BIN_DIR/huawei_x.py"
INIT_SCRIPT="$INIT_DIR/oc-direct"

# --- ROOT CHECK ---
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Please run as root"
    exit 1
fi

echo "[1/6] Download oc-direct.sh"
wget -q -O "$OC_SCRIPT" "$REPO_RAW/oc-direct.sh" || {
    echo "[ERROR] Failed to download oc-direct.sh"
    exit 1
}

echo "[2/6] Download huawei.py"
wget -q -O "$HUAWEI_SCRIPT" "$REPO_RAW/huawei_x.py" || {
    echo "[WARN] huawei_x.py not found (skip)"
}

echo "[3/6] Set permissions"
chmod +x "$OC_SCRIPT"
[ -f "$HUAWEI_SCRIPT" ] && chmod +x "$HUAWEI_SCRIPT"

echo "[4/6] Create init.d service"
cat > "$INIT_SCRIPT" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10

start() {
    echo "Starting oc-direct..."
    /usr/bin/oc-direct.sh &
}

stop() {
    echo "Stopping oc-direct..."
    killall oc-direct.sh 2>/dev/null
}
EOF

chmod +x "$INIT_SCRIPT"

echo "[5/6] Enable & start service"
/etc/init.d/oc-direct enable
/etc/init.d/oc-direct start

echo "[6/6] DONE"
echo "----------------------------------------"
echo " Service : /etc/init.d/oc-direct"
echo " Log     : /tmp/oc.log"
echo " Status  : RUNNING"
echo "----------------------------------------"
