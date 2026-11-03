#!/usr/bin/env bash
# Smoke test of a staging node (tech.md 38.5): VLESS Reality, Hysteria2 direct,
# and Hysteria2 with port hopping must each get 204 from generate_204.
# Usage: smoke-nodes.sh <node-address>
# Env: SSH_KEY (default ~/.ssh/vpn_deploy), SING_BOX (default sing-box on PATH).
# Run it from a machine outside the node's hoster: the hoster forbids scanners.
set -euo pipefail

host=${1:?usage: smoke-nodes.sh <node-address>}
key=${SSH_KEY:-$HOME/.ssh/vpn_deploy}
sing_box=${SING_BOX:-sing-box}
url=https://www.gstatic.com/generate_204

work=$(mktemp -d)
pid=
cleanup() {
  [[ -n $pid ]] && kill "$pid" 2>/dev/null || true
  rm -rf "$work"
}
trap cleanup EXIT
umask 077

ssh -i "$key" -o IdentitiesOnly=yes -o BatchMode=yes "root@$host" cat /opt/remnawave/probe.json > "$work/probe.json"

# Writes one sing-box config per check; the probe secrets stay in $work.
python3 -I - "$work" "$host" <<'PY'
import json, sys
work, host = sys.argv[1], sys.argv[2]
p = json.load(open(f"{work}/probe.json"))
vless = {"type": "vless", "server": host, "server_port": 443, "uuid": p["uuid"],
         "flow": "xtls-rprx-vision", "packet_encoding": "xudp",
         "tls": {"enabled": True, "server_name": p["serverName"],
                 "utls": {"enabled": True, "fingerprint": "chrome"},
                 "reality": {"enabled": True, "public_key": p["publicKey"], "short_id": p["shortId"]}}}
hy2 = {"type": "hysteria2", "server": p["hy2ServerName"], "server_port": 443, "password": p["uuid"],
       "obfs": {"type": "salamander", "password": p["obfs"]},
       "tls": {"enabled": True, "server_name": p["hy2ServerName"], "alpn": ["h3"]}}
# portHopping {ports: "20000-50000", intervalSec: 30} from tech.md 38.2.
hop = dict(hy2, server_ports=["20000:50000"], hop_interval="30s")
for name, out in {"vless": vless, "hy2": hy2, "hy2-hop": hop}.items():
    cfg = {"log": {"level": "error"},
           "inbounds": [{"type": "mixed", "listen": "127.0.0.1", "listen_port": 0}],
           "outbounds": [dict(out, tag="probe")]}
    json.dump(cfg, open(f"{work}/{name}.json", "w"))
PY

# Prints the HTTP code of one request through the local proxy.
fetch() {
  curl -sS -o /dev/null -w '%{http_code}' --max-time 15 -x "socks5h://127.0.0.1:$1" "$url" || true
}

failed=0
for name in vless hy2 hy2-hop; do
  port=$(python3 -I -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')
  python3 -I - "$work/$name.json" "$port" <<'PY'
import json, sys
path, port = sys.argv[1], int(sys.argv[2])
cfg = json.load(open(path))
cfg["inbounds"][0]["listen_port"] = port
json.dump(cfg, open(path, "w"))
PY
  "$sing_box" check -c "$work/$name.json"
  "$sing_box" run -c "$work/$name.json" > "$work/$name.log" 2>&1 &
  pid=$!
  for _ in $(seq 50); do
    (exec 3<>"/dev/tcp/127.0.0.1/$port") 2>/dev/null && break
    sleep 0.1
  done

  code=$(fetch "$port")
  # A second request after one hop interval proves the client survives a hop.
  if [[ $name == hy2-hop && $code == 204 ]]; then
    sleep 35
    code=$(fetch "$port")
  fi
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  pid=

  if [[ $code == 204 ]]; then
    echo "ok   $name"
  else
    echo "FAIL $name: HTTP $code" >&2
    # sing-box errors name the server, not the probe secrets.
    tail -n 5 "$work/$name.log" >&2
    failed=1
  fi
done
exit "$failed"
