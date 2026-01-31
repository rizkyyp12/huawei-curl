#!/bin/sh

echo "========================================"
echo " OpenClash Auto DIRECT + Huawei Recovery"
echo " INSTALLER (REVISED)"
echo "========================================"

REPO_RAW="https://raw.githubusercontent.com/rizkyyp12/huawei-curl/main.py"

BIN_DIR="/usr/bin"
INIT_DIR="/etc/init.d"
CONFIG_DIR="/etc/config"

OC_SCRIPT="$BIN_DIR/oc-direct.sh"
HUAWEI_SCRIPT="$BIN_DIR/huawei_x.py"
INIT_SCRIPT="$INIT_DIR/oc-direct"
HUAWEI_CONFIG="$CONFIG_DIR/huawei"

# --- ROOT CHECK ---
if [ "$(id -u)" != "0" ]; then
    echo "[ERROR] Please run as root"
    exit 1
fi

# -----------------------
# [0] INSTALL DEPENDENCY
# -----------------------
echo "[0/7] Install dependency (python3, pip, ca-bundle)"
opkg update
opkg install python3 python3-pip ca-bundle

echo "[0/7] Install Python libraries"
pip3 install --no-cache-dir --upgrade pip
pip3 install --no-cache-dir requests huawei-lte-api

# -----------------------
# [1] DOWNLOAD SCRIPTS
# -----------------------
echo "[1/7] Download oc-direct.sh"
wget -q -O "$OC_SCRIPT" "$REPO_RAW/oc-direct.sh" || {
    echo "[ERROR] Failed to download oc-direct.sh"
    exit 1
}

echo "[2/7] Download huawei_x.py"
wget -q -O "$HUAWEI_SCRIPT" "$REPO_RAW/huawei_x.py" || {
    echo "[WARN] huawei_x.py not found (skip)"
}

# -----------------------
# [3] PERMISSION
# -----------------------
echo "[3/7] Set permissions"
chmod +x "$OC_SCRIPT"
[ -f "$HUAWEI_SCRIPT" ] && chmod +x "$HUAWEI_SCRIPT"

# -----------------------
# [4] CREATE CONFIG HUAWEI
# -----------------------
echo "[4/7] Create /etc/config/huawei (if not exist)"
if [ ! -f "$HUAWEI_CONFIG" ]; then
cat << 'EOF' > "$HUAWEI_CONFIG"
config huawei 'main'
    option router_ip '192.168.8.1'
    option username 'admin'
    option password 'admin123'
    # option telegram_token '8381432929:AAHBBSLIZVUO1fbkjxuh8eyblSBKL1juXEo'
    # option chat_id '7848244096'
EOF
    echo "  -> Config created"
else
    echo "  -> Config already exists (skip)"
fi

# -----------------------
# [5] INIT.D SERVICE
# -----------------------
echo "[5/7] Create init.d service"
cat > "$INIT_SCRIPT" <<'EOF'
#!/bin/sh /etc/rc.common
START=99
STOP=10
USE_PROCD=1

start_service() {
    echo "Starting oc-direct..."
    procd_open_instance
    procd_set_param command /usr/bin/oc-direct.sh
    procd_set_param respawn 3600 5 5
    procd_close_instance
}

stop_service() {
    echo "Stopping oc-direct..."
}
EOF

chmod +x "$INIT_SCRIPT"

# -----------------------
# [6] ENABLE & START
# -----------------------
echo "[6/7] Enable & start service"
/etc/init.d/oc-direct enable
/etc/init.d/oc-direct restart

# -----------------------
# DONE
# -----------------------
echo "[7/7] DONE"
echo "----------------------------------------"
echo " Service : /etc/init.d/oc-direct"
echo " Huawei  : /usr/bin/huawei_x.py"
echo " Config  : /etc/config/huawei"
echo " Log     : /tmp/oc.log"
echo " Status  : RUNNING"
echo "----------------------------------------"
