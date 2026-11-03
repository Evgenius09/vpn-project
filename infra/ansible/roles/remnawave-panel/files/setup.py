#!/usr/bin/env python3
"""Idempotent staging setup through the Remnawave panel API (tech.md 37.2, 38).

Creates the admin, an API token, the config profile with the VLESS Reality and
Hysteria2 inbounds, the node, the squad, the hosts, and the probe user. Writes
the node's .env and probe.json for the smoke script. Prints "changed:" lines
for Ansible. Secrets go only to 0600 files under /opt.
"""
import argparse
import base64
import json
import os
import secrets
import string
import subprocess
import urllib.error
import urllib.request

PANEL_DIR = "/opt/remnawave"
NODE_DIR = "/opt/remnanode"
BASE = "http://127.0.0.1:3000"
# The panel answers only requests that look proxied over HTTPS.
HEADERS = {"Content-Type": "application/json", "X-Forwarded-For": "127.0.0.1", "X-Forwarded-Proto": "https"}
NODE_PORT = 2222

parser = argparse.ArgumentParser()
parser.add_argument("--node-name", required=True)
parser.add_argument("--node-address", required=True, help="public address of the VLESS host")
parser.add_argument("--node-fqdn", required=True, help="certificate name of the Hysteria2 host")
parser.add_argument("--country", required=True)
parser.add_argument("--reality-target", required=True)
args = parser.parse_args()

token = None


def call(method, path, body=None, extra=None):
    headers = dict(HEADERS, **(extra or {}))
    if token:
        headers["Authorization"] = "Bearer " + token
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, method=method, headers=headers, data=data)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.load(resp)["response"]
    except urllib.error.HTTPError as err:
        # The body may echo request fields; keep it short and out of secrets' way.
        raise SystemExit(f"{method} {path}: {err.code} {err.read()[:300]!r}")


def changed(what):
    print("changed:", what)


def write_secret(path, text):
    """Writes a 0600 file and reports whether its content changed."""
    if os.path.exists(path) and open(path).read() == text:
        return False
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    os.write(fd, text.encode())
    os.close(fd)
    return True


def password():
    alphabet = string.ascii_letters + string.digits
    while True:
        pw = "".join(secrets.choice(alphabet) for _ in range(32))
        if any(c.isupper() for c in pw) and any(c.islower() for c in pw) and any(c.isdigit() for c in pw):
            return pw


def x25519_public(private_key):
    """Derives the Reality public key with openssl, so the node need not run yet."""
    raw = base64.urlsafe_b64decode(private_key + "=" * (-len(private_key) % 4))
    der = bytes.fromhex("302e020100300506032b656e04220420") + raw
    out = subprocess.run(["openssl", "pkey", "-inform", "DER", "-pubout", "-outform", "DER"],
                         input=der, capture_output=True, check=True).stdout
    return base64.urlsafe_b64encode(out[-32:]).rstrip(b"=").decode()


# 1. Admin. admin.txt keeps the only copy of the password.
admin_file = f"{PANEL_DIR}/admin.txt"
if not os.path.exists(admin_file):
    pw = password()
    token = call("POST", "/api/auth/register", {"username": "vpnadmin", "password": pw})["accessToken"]
    write_secret(admin_file, f"username=vpnadmin\npassword={pw}\n")
    changed("admin registered")
else:
    pw = dict(line.split("=", 1) for line in open(admin_file).read().split())["password"]
    token = call("POST", "/api/auth/login", {"username": "vpnadmin", "password": pw})["accessToken"]
if call("GET", "/api/auth/status")["isRegisterAllowed"]:
    raise SystemExit("panel registration is still open")

# The API refuses the admin JWT; only an API token, made with that JWT, works.
token_file = f"{PANEL_DIR}/api-token.txt"
if not os.path.exists(token_file):
    api_token = call("POST", "/api/tokens", {"name": "staging-setup", "expiresInDays": 3650},
                     {"X-Remnawave-Client-Type": "browser"})["token"]
    write_secret(token_file, api_token)
    changed("api token created")
token = open(token_file).read().strip()

obfs_file = f"{PANEL_DIR}/hy2-obfs.txt"
if not os.path.exists(obfs_file):
    write_secret(obfs_file, secrets.token_urlsafe(32))
    changed("salamander password created")
obfs = open(obfs_file).read().strip()

# 2. The config profile: VLESS Reality on 443/tcp, Hysteria2 on 443/udp (tech.md 38.2).
le = f"/etc/letsencrypt/live/{args.node_fqdn}"
hy2 = {
    "tag": "HYSTERIA2", "listen": "0.0.0.0", "port": 443, "protocol": "hysteria",
    "settings": {"version": 2, "clients": []},
    "streamSettings": {
        "network": "hysteria", "security": "tls",
        "tlsSettings": {"alpn": ["h3"], "certificates": [
            {"certificateFile": f"{le}/fullchain.pem", "keyFile": f"{le}/privkey.pem"}]},
        "hysteriaSettings": {"version": 2},
        "finalmask": {"udp": [{"type": "salamander", "settings": {"password": obfs}}]},
    },
}
profile = next((p for p in call("GET", "/api/config-profiles")["configProfiles"] if p["name"] == "staging"), None)
if profile is None:
    keys = call("GET", "/api/system/tools/x25519/generate")["keypairs"][0]
    vless = {
        "tag": "VLESS_REALITY", "listen": "0.0.0.0", "port": 443, "protocol": "vless",
        "settings": {"clients": [], "decryption": "none"},
        "sniffing": {"enabled": True, "destOverride": ["http", "tls", "quic"]},
        "streamSettings": {"network": "tcp", "security": "reality", "realitySettings": {
            "show": False, "xver": 0, "target": f"{args.reality_target}:443",
            "serverNames": [args.reality_target], "privateKey": keys["privateKey"],
            "shortIds": [secrets.token_hex(4)]}},
    }
    config = {
        "log": {"loglevel": "warning", "access": "none"},
        "inbounds": [vless, hy2],
        "outbounds": [{"tag": "DIRECT", "protocol": "freedom"}, {"tag": "BLOCK", "protocol": "blackhole"}],
        "routing": {"rules": [{"ip": ["geoip:private"], "outboundTag": "BLOCK"}]},
    }
    profile = call("POST", "/api/config-profiles", {"name": "staging", "config": config})
    changed("profile created")
else:
    config = profile["config"]
    others = [i for i in config["inbounds"] if i["tag"] != "HYSTERIA2"]
    if others + [hy2] != config["inbounds"]:
        config["inbounds"] = others + [hy2]
        profile = call("PATCH", "/api/config-profiles", {"uuid": profile["uuid"], "config": config})
        changed("profile updated")
inbounds = {i["tag"]: i["uuid"] for i in profile["inbounds"]}
active = sorted(inbounds.values())

# 3. The node, reached from the panel container through the bridge gateway.
gateway = subprocess.check_output(["docker", "network", "inspect", "remnawave-network", "-f",
                                   "{{(index .IPAM.Config 0).Gateway}}"], text=True).strip()
node = next((n for n in call("GET", "/api/nodes") if n["name"] == args.node_name), None)
if node is None:
    call("POST", "/api/nodes", {"name": args.node_name, "address": gateway, "port": NODE_PORT,
                                "countryCode": args.country,
                                "configProfile": {"activeConfigProfileUuid": profile["uuid"], "activeInbounds": active}})
    changed("node created")
elif sorted(i["uuid"] for i in node["configProfile"]["activeInbounds"]) != active:
    call("PATCH", "/api/nodes", {"uuid": node["uuid"],
                                 "configProfile": {"activeConfigProfileUuid": profile["uuid"], "activeInbounds": active}})
    changed("node inbounds updated")

# The panel and the node share one server (tech.md 37.2), so the panel writes the node's key.
# keygen issues a fresh node certificate on every call, and a new key restarts the node.
# shortcut: a reinstalled panel has a new CA; delete the node's .env by hand then.
os.makedirs(NODE_DIR, mode=0o750, exist_ok=True)
if not os.path.exists(f"{NODE_DIR}/.env"):
    secret_key = call("GET", "/api/keygen")["pubKey"]
    write_secret(f"{NODE_DIR}/.env", f"NODE_PORT={NODE_PORT}\nSECRET_KEY={secret_key}\n")
    changed("node env written")

# 4. The squad, the hosts clients connect to, and the probe user.
squad = next((s for s in call("GET", "/api/internal-squads")["internalSquads"] if s["name"] == "staging"), None)
if squad is None:
    squad = call("POST", "/api/internal-squads", {"name": "staging", "inbounds": active})
    changed("squad created")
elif sorted(i["uuid"] for i in squad["inbounds"]) != active:
    call("PATCH", "/api/internal-squads", {"uuid": squad["uuid"], "inbounds": active})
    changed("squad inbounds updated")

remarks = {h["remark"] for h in call("GET", "/api/hosts")}
if f"{args.node_name}-vless" not in remarks:
    call("POST", "/api/hosts", {
        "inbound": {"configProfileUuid": profile["uuid"], "configProfileInboundUuid": inbounds["VLESS_REALITY"]},
        "remark": f"{args.node_name}-vless", "address": args.node_address, "port": 443,
        "sni": args.reality_target, "fingerprint": "chrome", "securityLayer": "DEFAULT"})
    changed("vless host created")
if f"{args.node_name}-hy2" not in remarks:
    call("POST", "/api/hosts", {
        "inbound": {"configProfileUuid": profile["uuid"], "configProfileInboundUuid": inbounds["HYSTERIA2"]},
        "remark": f"{args.node_name}-hy2", "address": args.node_fqdn, "port": 443,
        "sni": args.node_fqdn, "securityLayer": "DEFAULT"})
    changed("hysteria2 host created")

user = next((u for u in call("GET", "/api/users?size=100")["users"] if u["username"] == "staging_probe"), None)
if user is None:
    user = call("POST", "/api/users", {"username": "staging_probe", "expireAt": "2099-12-31T00:00:00Z",
                                       "activeInternalSquads": [squad["uuid"]]})
    changed("probe user created")

reality = next(i for i in profile["config"]["inbounds"] if i["tag"] == "VLESS_REALITY")["streamSettings"]["realitySettings"]
# Remnawave gives the Hysteria2 user the vlessUuid as password (tech.md 38.3).
probe = {"uuid": user["vlessUuid"], "publicKey": x25519_public(reality["privateKey"]),
         "shortId": reality["shortIds"][0], "serverName": reality["serverNames"][0],
         "hy2ServerName": args.node_fqdn, "obfs": obfs}
if write_secret(f"{PANEL_DIR}/probe.json", json.dumps(probe)):
    changed("probe.json written")
