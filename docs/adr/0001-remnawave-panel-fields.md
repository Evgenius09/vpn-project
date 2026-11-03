# ADR 0001: Remnawave panel fields

Status: accepted, 2026-11-03. Core: tech.md v22 (§38.3, §39).

## Context

S1-10 maps the Remnawave 3.4.8 API to `PanelClient` (tech.md 5.10). The profile
needs the Reality and Hysteria2 parameters in the shape of `openapi.yaml`, and
the panel does not expose them in that shape.

## Decision

Users:

- Remnawave 3.4.8 identifies a user by a numeric `id`. There is no user uuid,
  so `PanelUser.ID` is `int64` and `panel_users.remnawave_id` is `bigint`.
- `vlessUuid` is the VLESS credential. Remnawave gives the Hysteria2 user the
  same value as password, so `Hysteria2Auth = vlessUuid`.
- A taken username answers 400 with `errorCode: A019`, mapped to `ErrConflict`.
  A missing user answers 404 (`A063` on lookup, `A025` on update).
- New users join the internal squad `REMNAWAVE_SQUAD_UUID`: a user outside every
  squad gets no inbound.

Hosts: `GET /api/hosts` joined with `GET /api/config-profiles/inbounds` on
`inbound.configProfileInboundUuid`.

| Field | Source |
|---|---|
| protocol `vless_reality` | inbound `vless`, `network = tcp`, `security = reality` |
| `flow` | always `xtls-rprx-vision` |
| `serverName` | host `sni`, else `realitySettings.serverNames[0]` |
| `publicKey` | X25519 of `realitySettings.privateKey` |
| `shortId` | `realitySettings.shortIds[0]` |
| `fingerprint` | host `fingerprint`, else `chrome` |
| protocol `hysteria2` | inbound `hysteria`, `settings.version = 2` |
| `serverName` | host `sni`, else host `address` |
| `obfsSalamanderPassword` | `streamSettings.finalmask.udp[type = salamander].settings.password` |
| `portHopping` | `servers.yaml` (the panel does not store it) |
| enabled | `!isDisabled && !isHidden` |

The panel returns only the Reality private key, so the backend derives the
public key and drops the private one at once. It is never stored or logged.
Hosts on other inbound types are left out of `ListHosts`.

## Consequences

- Upgrading the panel means a new spec file, `make gen`, fresh recordings in
  `backend/internal/panel/remnawave/testdata/` and a core bump.
- The admin API token reaches the Reality private key. The token lives only in
  the worker's environment on the API host.
