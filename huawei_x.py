#!/usr/bin/env python3
# Huawei LTE – PLMN Trigger
# Telegram sent AFTER IP change AND internet recovered
# OpenWrt + OpenClash SAFE

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
# INTERNET CHECK (TELEGRAM-AWARE)
# ===============================

def internet_available(timeout=5):
    try:
        r = requests.get(
            "https://api.telegram.org",
            timeout=timeout
        )
        return r.status_code in (200, 401)
    except Exception:
        return False

def wait_for_internet(max_wait=180, interval=5):
    info(f"Menunggu koneksi internet hingga {max_wait} detik...")
    start = time.time()

    # Delay awal agar routing & OpenClash settle
    time.sleep(15)

    while time.time() - start < max_wait:
        if internet_available():
            success("Internet sudah pulih.")
            return True
        info("Internet belum siap, retry...")
        time.sleep(interval)

    warn("Timeout menunggu internet.")
    return False

# ===============================
# TELEGRAM
# ===============================

def send_telegram(token, chat_id, message, thread_id=None):
    if not token or not chat_id:
        warn("Token atau Chat ID kosong, Telegram dilewati.")
        return

    if not wait_for_internet():
        warn("Internet belum pulih, Telegram dibatalkan.")
        return

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = {
        "chat_id": chat_id,
        "text": message,
        "disable_web_page_preview": True
    }

    if thread_id:
        data["message_thread_id"] = int(thread_id)

    try:
        r = requests.post(url, data=data, timeout=10)
        if r.status_code == 200:
            success("Telegram terkirim.")
        else:
            warn(f"Telegram gagal, HTTP {r.status_code}")
    except Exception as e:
        warn(f"Telegram error: {e}")

# ===============================
# OPENWRT CONFIG (UCI-NATIVE)
# ===============================

def load_config():
    cfg = {}
    try:
        import subprocess
        out = subprocess.check_output(
            ["uci", "show", "huawei.main"],
            text=True
        )
        for line in out.splitlines():
            if "=" in line:
                k, v = line.split("=", 1)
                cfg[k.split(".")[-1]] = v.strip("'")
    except Exception as e:
        warn(f"Gagal load config UCI: {e}")
    return cfg

# ===============================
# HUAWEI LTE CORE
# ===============================

def get_wan_info(client):
    info_dev = client.device.information()
    wan_ip = (
        info_dev.get("WanIPAddress")
        or info_dev.get("IPAddress")
        or info_dev.get("CurrentIPAddress")
    )
    device = info_dev.get("DeviceName", "Huawei LTE")
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

# 🔥 IDENTIK SCRIPT LAMA
def initiate_ip_change(client):
    info("Trigger PLMN refresh...")
    client.net.plmn_list()

# ===============================
# MAIN
# ===============================

def main():
    cfg = load_config()

    router_ip = cfg.get("router_ip", "192.168.8.1")
    username  = cfg.get("username", "admin")
    password  = cfg.get("password", "admin")
    tg_token  = cfg.get("telegram_token", "")
    chat_id   = cfg.get("chat_id", "")
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
            time.sleep(8)

            new_ip, _ = fetch_wan_info(client)
            info(f"New IP : {new_ip}")

            # ✅ HANYA lanjut jika IP benar-benar berubah
            if new_ip == old_ip:
                warn("IP tidak berubah, Telegram dilewati.")
                return

            msg = (
                f"⚙️ Change IP - {hostname}\n"
                f"====================\n"
                f"🔰 Modem : {modem}\n"
                f"🔰 Old IP: {old_ip}\n"
                f"🔰 New IP: {new_ip}\n\n"
                f"✅ Internet recovered & ready"
            )

            send_telegram(tg_token, chat_id, msg, thread_id)
            success("Proses selesai.")

    except Exception as e:
        err = f"Huawei script error: {e}"
        error(err)
        send_telegram(tg_token, chat_id, err, thread_id)

# ===============================
# ENTRY
# ===============================

if __name__ == "__main__":
    main()
