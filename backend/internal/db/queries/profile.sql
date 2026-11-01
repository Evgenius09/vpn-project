-- name: GetProfileAccount :one
select
    a.status,
    a.expires_at,
    a.device_limit,
    t.username,
    p.vless_uuid,
    p.hysteria2_auth,
    p.traffic_limit_bytes,
    p.traffic_used_bytes
from accounts a
left join telegram_users t on t.account_id = a.id
left join panel_users p on p.account_id = a.id
where a.id = $1;

-- name: ListEnabledServers :many
select id, grp, protocol, display_name, country_code, city, address, port, params, sort_weight
from servers
where enabled
order by grp, sort_weight, id;
