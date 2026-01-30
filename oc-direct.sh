#!/bin/sh

# ================= CONFIG =================
DOMAINS="ava.game.naver.com df.game.naver.com"
STATE_FILE="/tmp/oc_state"
LOG="/tmp/oc.log"

INTERVAL=30
FAST_INTERVAL=5
MAX_FAIL=2

HUAWEI_SCRIPT="/usr/bin/huawei_x.py"
HUAWEI_ACTIVE="/tmp/huawei_active"

YACD="http://127.0.0.1:9090"
UA="Mozilla/5.0"

echo "[BOOT] oc-direct started $(date)" >> "$LOG"

# ================= UTIL =================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

get_state() {
    [ -f "$STATE_FILE" ] && cat "$STATE_FILE" || echo "RULE"
}

set_state() {
    echo "$1" > "$STATE_FILE"
}

# ================= CLASH API =================
clash_alive() {
    curl -s --max-time 2 "$YACD/version" | grep -q version
}

clash_mode() {
    curl -s "$YACD/configs" | sed -n 's/.*"mode":"\([^"]*\)".*/\1/p'
}

set_mode() {
    CUR="$(clash_mode)"
    [ "$CUR" = "$1" ] && return
    log "Switch MODE → $1"
    curl -s -X PATCH "$YACD/configs" \
        -H "Content-Type: application/json" \
        -d "{\"mode\":\"$1\"}" >/dev/null
}

proxy_ready() {
    curl -s "$YACD/proxies" | grep -q '"type"'
}

# ================= DOMAIN CHECK =================
domain_invalid() {
    RES="$(curl -I -L \
        -A "$UA" \
        --connect-timeout 5 \
        --max-time 8 \
        "https://$1" 2>/dev/null)"

    [ -z "$RES" ] && return 0
    echo "$RES" | grep -qi "123.xl.co.id" && return 0
    return 1
}

any_domain_valid() {
    for d in $DOMAINS; do
        if ! domain_invalid "$d"; then
            log "$d VALID"
            return 0
        fi
        log "$d INVALID"
    done
    return 1
}

# ================= FSM =================
FAIL=0

while true; do
    STATE="$(get_state)"

    # --- Clash API DOWN ---
    if ! clash_alive; then
        log "Clash API DOWN → restart OpenClash"
        /etc/init.d/openclash restart
        sleep 10
        continue
    fi

    # --- Proxy not ready ---
    if ! proxy_ready; then
        log "Proxy NOT READY → DIRECT"
        set_mode direct
        set_state DIRECT
        sleep "$FAST_INTERVAL"
        continue
    fi

    # --- DOMAIN OK ---
    if any_domain_valid; then
        FAIL=0
        rm -f "$HUAWEI_ACTIVE"

        if [ "$STATE" != "RULE" ]; then
            log "DOMAIN RECOVERED → RULE"
            set_mode rule
            set_state RULE
        fi

        sleep "$INTERVAL"
        continue
    fi

    # --- DOMAIN FAIL ---
    FAIL=$((FAIL + 1))
    log "ALL DOMAIN INVALID, FAIL COUNT = $FAIL"

    if [ "$STATE" != "DIRECT" ]; then
        set_mode direct
        set_state DIRECT
    fi

    # --- HUAWEI RECOVERY LOOP ---
    if [ "$FAIL" -ge "$MAX_FAIL" ] && [ "$STATE" != "RULE" ]; then
        touch "$HUAWEI_ACTIVE"

        if [ -f "$HUAWEI_SCRIPT" ]; then
            log "RECOVERY ACTIVE → running huawei.py"
            python3 "$HUAWEI_SCRIPT" >> "$LOG" 2>&1
        else
            log "ERROR: $HUAWEI_SCRIPT not found"
        fi
    fi

    sleep "$FAST_INTERVAL"
done
