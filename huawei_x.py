#!/usr/bin/env python3
# Script by https://bit.ly/aryochannel (modified for OpenClash)

from huawei_lte_api.Client import Client
from huawei_lte_api.Connection import Connection
import time
import socket
import requests
import re

# ================= CONFIG =================
CONFIG_FILE = "/etc/config/huawey"

# ================= UTIL =================
def get_wan_info(client):
    info = client.device.information()
    return info.get("WanIPAddress"), info.get("DeviceName")


def load_openwrt_config(path):
    cfg = {}
    try:
        with open(path) as f:
            for line in f:
                m = re.match(r"\s*option\s+(\w+)\s+'([^']+)'", line)
                if m:
                    cfg[m.group(1)] = m.group(2)
    except FileNotFoundError:
        pass
    return cfg


def telegram_send(token, chat_id, message):
    if not token or not chat_id:
        return
    try:
        requests.post(
            f"https://api.telegram.org/bot{token}/sendMessage",
            data={"chat_id": chat_id, "text": message},
            timeout=5
        )
    except Exception:
        pass


def initiate_ip_change(client):
    # PLMN refresh → force new public IP
    client.net.plmn_list()


# ================= MAIN =================
def main():
    cfg = load_openwrt_config(CONFIG_FILE)

    router_ip = cfg.get("router_ip", "192.168.8.1")
    username  = cfg.get("username", "admin")
    password  = cfg.get("password", "admin123")

    tg_token  = cfg.get("telegram_token", "")
    tg_chat   = cfg.get("chat_id", "")

    hostname = socket.gethostname()
    conn_url = f"http://{username}:{password}@{router_ip}/"

    try:
        with Connection(conn_url) as conn:
            client = Client(conn)

            print("=== HUAWEI FORCE PUBLIC IP ===")

            ip_before, dev = get_wan_info(client)
            print(f"Modem Name: {dev}")
            print(f"Current IP: {ip_before}")

            # ⬇⬇⬇ PENTING UNTUK oc.sh ⬇⬇⬇
            print(f"IP_BEFORE={ip_before}")

            print("Initiating PLMN refresh...")
            initiate_ip_change(client)

            time.sleep(5)

            ip_after, _ = get_wan_info(client)
            print(f"New IP: {ip_after}")

            # ⬇⬇⬇ PENTING UNTUK oc.sh ⬇⬇⬇
            print(f"IP_AFTER={ip_after}")

            if ip_before != ip_after:
                msg = (
                    f"🔁 IP Changed ({hostname})\n"
                    f"Before: {ip_before}\n"
                    f"After : {ip_after}"
                )
                telegram_send(tg_token, tg_chat, msg)
            else:
                telegram_send(
                    tg_token,
                    tg_chat,
                    f"⚠️ IP NOT CHANGED ({hostname})\nIP: {ip_before}"
                )

    except Exception as e:
        telegram_send(
            cfg.get("telegram_token", ""),
            cfg.get("chat_id", ""),
            f"❌ Huawei IP change error:\n{e}"
        )
        print(f"ERROR: {e}")


if __name__ == "__main__":
    main()
