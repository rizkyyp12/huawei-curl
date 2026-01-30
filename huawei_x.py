#!/usr/bin/env python3
# Huawei LTE – PLMN Trigger Version (Identik Script Lama)
# OpenWrt Safe + Telegram Internet-Aware

import time
import socket
import requests
import re
import os
from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection

# ===============================
# OUTPUT
# ===============================

def info(msg):
    print(msg)

def warn(msg):
    print("\033[93m" + msg + "\033[0m")

def error(msg):
    print("\033[91m" + msg + "\033[0m")

def success(msg):
    print("\033[92m" + msg + "\033[0m")

# ===============================
# INTERNET CHECK (HTTP)
# ===============================

def internet_available(timeout=5):
    urls = [
        "https://www.google.com/generate_204",
        "https://www.gstatic.com/generate_204",
        "https://www.cloudflare.com/cdn-cgi/trace"
    ]
    for url in urls:
        try:
            r = requests.get(url, timeout=timeout)
            if r.status_code in (200, 204):
                return True
        except Exception:
            pass
    return False

def wait_for_internet(max_wait=30):
    start = time.time()
    while time.time() - start < max_wait:
        if internet_available():
            return True
        time.sleep(2)
    return False

# ===============================
# TELEGRAM (SAFE)
# ===============================

def send_telegram(token, chat_id, message, thread_id=None):
    if not token or not chat_id:
        return

    if not wait_for_internet():
        warn("Internet belum tersedia, Telegram dibatalkan.")
        return

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = {"chat_id": chat_id, "text": message}

    if thread_id:
        data["message_thread_id"] = thread_id

    try:
        requests.post(url, data=data, timeout=10)
        success("Telegram terkirim.")
    except Exception as e:
        warn(f"Gagal kirim Telegram: {e}")

# ===============================
# OPENWRT CONFIG (FAIL-SAFE)
# ===============================

def load_config(path="/etc/config/huawei"):
    cfg = {}
    if not os.path.exists(path):
        warn(f"Config {path} tidak ada, pakai default.")
        return cfg

    with open(path, "r") as f:
        for line in f:
            m = re.match(r"\s*option\s+(\w+)\s+'([^']+)'", line)
            if m:
                k, v = m.groups()
                cfg[k] = v
    return cfg

# ===============================
# HUAWEI LTE CORE (SCRIPT LAMA)
# ===============================

def get_wan_info(client):
    info = client.device.information()
    wan_ip = (
        info.get("WanIPAddress")
        or info.get("IPAddress")
        or info.get("CurrentIPAddress")
    )
    device = info.get("DeviceName", "Huawei LTE")
    return wan_ip, device

def fetch_wan_info(client, timeout=30):
    start = time.time()
    while True:
        ip, dev = get_wan_info(client)
        if ip:
            return ip, dev
        if time.time() - start > timeout:
            raise Exception("Timeout mendapatkan WAN IP")
        time.sleep(1)

# 🔥 MEKANISME IDENTIK SCRIPT LAMA
def initiate_ip_change(client):
    info("Trigger PLMN refresh...")
    client.net.plmn_list()

# ===============================
# MAIN
# ===============================

def main():
    cfg = load_config()

    router_ip = cfg.get("router_ip", "192.168.8.1")
    username = cfg.get("username", "admin")
    password = cfg.get("password", "admin")
    tg_token = cfg.get("telegram_token", "")
    chat_id = cfg.get("chat_id", "")
    thread_id = cfg.get("message_thread_id")

    hostname = socket.gethostname()
    conn_url = f"http://{username}:{password}@{router_ip}/"

    try:
        with Connection(conn_url) as conn:
            client = Client(conn)

            old_ip, modem = fetch_wan_info(client)
            info(f"Modem  : {modem}")
            info(f"Old IP : {old_ip}")

            initiate_ip_change(client)
            time.sleep(5)

            new_ip, _ = fetch_wan_info(client)
            info(f"New IP : {new_ip}")

            msg = (
                f"⚙️ Change IP - {hostname}\n"
                f"====================\n"
                f"🔰 Modem : {modem}\n"
                f"🔰 Old IP: {old_ip}\n"
                f"🔰 New IP: {new_ip}\n\n"
                f"✅ PLMN refresh success"
            )

            send_telegram(tg_token, chat_id, msg, thread_id)
            success("Selesai.")

    except Exception as e:
        err = f"Huawei script error: {e}"
        error(err)
        send_telegram(tg_token, chat_id, err, thread_id)

# ===============================
# ENTRY
# ===============================

if __name__ == "__main__":
    main()
