#!/bin/sh

# ================= CONFIG =================
DOMAINS="ava.game.naver.com df.game.naver.com"
STATE_FILE="/tmp/oc_state"
LOG="/tmp/oc.log"

INTERVAL=30
FAST_INTERVAL=5
MAX_FAIL=2        # tetap untuk force direct, optional

COOLDOWN_AFTER_IP=6   # ⬅️ COOLDOWN 6 DETIK SETELAH GANTI IP

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
        --connect-timeout 10 \
        --max-time 8 \
        "https://$1" 2>/dev/null)"

    [ -z "$RES" ] && return 0
    echo "$RES" | grep -qi "123.xl.co.id" && return 0
    return 1
}

# ================= FSM =================
# inisialisasi fail count per domain
declare -A FAIL_COUNT
for d in $DOMAINS; do
    FAIL_COUNT["$d"]=0
done

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

    # --- DOMAIN CHECK ---
    ALL_VALID=true
    for d in $DOMAINS; do
        if domain_invalid "$d"; then
            FAIL_COUNT["$d"]=$((FAIL_COUNT["$d"] + 1))
            log "$d INVALID (${FAIL_COUNT["$d"]}/5)"
            ALL_VALID=false
        else
            if [ "${FAIL_COUNT["$d"]}" -ne 0 ]; then
                log "$d VALID → reset FAIL"
                FAIL_COUNT["$d"]=0
            fi
        fi
    done

    # --- ALL DOMAIN VALID ---
    if $ALL_VALID; then
        if [ "$STATE" != "RULE" ]; then
            log "ALL DOMAIN VALID → switch RULE"
            set_mode rule
            set_state RULE
        fi
        sleep "$INTERVAL"
        continue
    fi

    # --- CHECK IF ALL DOMAINS FAIL >= 5 ---
    TRIGGER_HUAWEI=true
    for d in $DOMAINS; do
        if [ "${FAIL_COUNT["$d"]}" -lt 5 ]; then
            TRIGGER_HUAWEI=false
        fi
    done

    if $TRIGGER_HUAWEI; then
        log "ALL DOMAINS FAILED >=5 → switch DIRECT + trigger huawei.py"
        if [ "$STATE" != "DIRECT" ]; then
            set_mode direct
            set_state DIRECT
        fi
        python3 /usr/bin/huawei.py >> "$LOG" 2>&1
        log "[COOLDOWN] wait ${COOLDOWN_AFTER_IP}s after IP change"
        sleep "$COOLDOWN_AFTER_IP"
        # reset per-domain FAIL setelah trigger
        for d in $DOMAINS; do
            FAIL_COUNT["$d"]=0
        done
    fi

    sleep "$FAST_INTERVAL"
done
