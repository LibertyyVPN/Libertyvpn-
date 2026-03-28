import sys
import argparse
import urllib.request
import base64
from urllib.parse import urlparse, parse_qs
import json


def fetch_url(url):
    with urllib.request.urlopen(url) as response:
        return response.read().decode("utf-8", errors="ignore")


def extract_vless_from_html(html_text):
    decoded_bytes = base64.b64decode(html_text)
    decoded_string = decoded_bytes.decode("utf-8")

    return decoded_string.split("\n")


def parse_vless(link):
    parsed = urlparse(link)
    params = parse_qs(parsed.query)

    return {
        "uuid": parsed.username,
        "host": parsed.hostname,
        "port": parsed.port,
        "flow": params.get("flow", [""])[0],
        "security": params.get("security", ["none"])[0],
        "sni": params.get("sni", [""])[0],
        "fp": params.get("fp", ["chrome"])[0],
        "pbk": params.get("pbk", [""])[0],
        "sid": params.get("sid", [""])[0]
    }

def build_config(v):
    return {
        "log": {
            "loglevel": "warning"
        },
        "inbounds": [
            {
                "listen": "127.0.0.1",
                "port": 1080,
                "protocol": "socks",
                "settings": {
                    "udp": True
                }
            }
        ],
        "outbounds": [
            {
                "protocol": "vless",
                "settings": {
                    "vnext": [
                        {
                            "address": v["host"],
                            "port": v["port"],
                            "users": [
                                {
                                    "id": v["uuid"],
                                    "encryption": "none",
                                    "flow": v["flow"]
                                }
                            ]
                        }
                    ]
                },
                "streamSettings": {
                    "network": "tcp",
                    "security": "reality",
                    "realitySettings": {
                        "serverName": v["sni"],
                        "fingerprint": v["fp"],
                        "publicKey": v["pbk"],
                        "shortId": v["sid"],
                        "spiderX": "/"
                    }
                }
            }
        ]
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", help="URL страницы")

    args = parser.parse_args()

    if not args.url:
        print("Укажите --url")
        sys.exit(1)
    else:
        html_text = fetch_url(args.url)

    links = extract_vless_from_html(html_text)

    if not links:
        print("VLESS ссылки не найдены")
        return

    print(f"Найдено {len(links)} ссылок:\n")

    for link, num in zip(links, range(len(links))):
        with open(f"config{num}.json", "w") as f:
            json.dump(build_config(parse_vless(link)), f, indent=2)


if __name__ == "__main__":
    main()