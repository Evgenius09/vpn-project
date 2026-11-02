-- name: SeedAccount :exec
insert into accounts (id, status, expires_at, device_limit)
values ($1, $2, $3, $4)
on conflict (id) do update
set status = excluded.status,
    expires_at = excluded.expires_at,
    device_limit = excluded.device_limit;

-- name: SeedTelegramUser :exec
insert into telegram_users (telegram_id, account_id, chat_id, username, first_name)
values ($1, $2, $3, $4, $5)
on conflict (telegram_id) do update
set account_id = excluded.account_id,
    chat_id = excluded.chat_id,
    username = excluded.username,
    first_name = excluded.first_name;

-- name: SeedDevice :exec
insert into devices (id, account_id, install_id, platform, model, app_version, token_hash)
values ($1, $2, $3, $4, $5, $6, $7)
on conflict (id) do update
set token_hash = excluded.token_hash,
    revoked_at = null;

-- name: SeedPanelUser :exec
insert into panel_users (
    account_id, remnawave_uuid, short_uuid, vless_uuid, hysteria2_auth,
    traffic_limit_bytes, traffic_used_bytes
)
values ($1, $2, $3, $4, $5, $6, $7)
on conflict (account_id) do update
set traffic_limit_bytes = excluded.traffic_limit_bytes,
    traffic_used_bytes = excluded.traffic_used_bytes;

-- name: SeedServer :exec
insert into servers (
    id, remnawave_host_uuid, grp, protocol, display_name, country_code, city,
    address, port, params, sort_weight, content_hash
)
values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
on conflict (id) do update
set display_name = excluded.display_name,
    address = excluded.address,
    port = excluded.port,
    params = excluded.params,
    sort_weight = excluded.sort_weight,
    content_hash = excluded.content_hash;
