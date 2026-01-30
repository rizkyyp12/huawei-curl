#!/bin/sh

echo "========================================"
echo " OpenClash Auto DIRECT + Huawei Recovery"
echo "========================================"

REPO_RAW="https://raw.githubusercontent.com/rizkyyp12/ip-hunter/main"

# --- PATH ---
BIN_DIR="/usr/bin"
INIT_DIR="/etc/init.d"

OC_SCRIPT="$BIN_DIR/oc-direct.sh"
HUAWEI_SCRIPT="$BIN_DIR/huawei.py"
INIT_SCRIPT="$INIT_DIR/oc-direct"

# --- CHECK ROOT ---
[ "$(id -u)" != "0" ] && {
    echo "[ERROR] Run as root"
    exit 1
}

echo "[1/6] Download oc-direct.sh"
wget -q -O "$OC_SCRIPT" "$REPO_RAW/oc-direct.sh" || {
    echo "[ERROR] Failed download oc-direct.sh"
    exit 1
}

echo "[2/6] Download huawei.py"
wget -q -O "$HUAWEI_SCRIPT" "$REPO_RAW/huawei.py" || {
    echo "[WARN] huawei.py not found (skip)"
}

echo "[3/6] Set permissions"
chmod +x "$OC_SCRIPT"
chmod +x "$HUAWEI_SCRIPT" 2>/dev/null

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

echo "[5/6] Enable autostart"
"$INIT_SCRIPT" enable

echo "[6/6] Done"
echo "========================================"
echo " Installed successfully"
echo " Log file : /tmp/oc.log"
echo " Service  : /etc/init.d/oc-direct"
echo "========================================"
