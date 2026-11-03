-- name: GetProvisionTarget :one
select t.telegram_id, (p.account_id is not null)::boolean as provisioned
from accounts a
join telegram_users t on t.account_id = a.id
left join panel_users p on p.account_id = a.id
where a.id = $1;

-- name: InsertPanelUser :execrows
insert into panel_users (
    account_id, remnawave_id, short_uuid, vless_uuid, hysteria2_auth,
    traffic_limit_bytes, traffic_used_bytes
)
values ($1, $2, $3, $4, $5, $6, $7)
on conflict do nothing;

-- name: StartTrial :exec
update accounts
set status = 'trial',
    expires_at = $2,
    updated_at = now()
where id = $1 and status = 'provisioning';
