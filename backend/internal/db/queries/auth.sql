-- name: GetTelegramUserByUsername :one
select telegram_id, bot_blocked_at
from telegram_users
where username = $1;

-- name: ListRecentLoginCodes :many
select created_at
from login_codes
where telegram_id = $1 and created_at > $2
order by created_at;

-- name: InvalidateLoginCodes :exec
update login_codes
set invalidated_at = $3
where telegram_id = $1
  and install_id = $2
  and consumed_at is null
  and invalidated_at is null;

-- name: InsertLoginCode :one
insert into login_codes (telegram_id, install_id, code_hash, expires_at, created_at)
values ($1, $2, $3, $4, $5)
returning id;

-- name: GetLoginCodeForUpdate :one
select c.install_id, c.code_hash, c.attempts, c.expires_at, c.consumed_at, c.invalidated_at, u.account_id
from login_codes c
join telegram_users u on u.telegram_id = c.telegram_id
where c.id = $1
for update of c;

-- name: SetLoginCodeAttempts :exec
update login_codes
set attempts = $2
where id = $1;

-- name: ConsumeLoginCode :exec
update login_codes
set consumed_at = $2
where id = $1;

-- name: GetLoginCodeDelivery :one
select c.expires_at, c.sent_at, c.consumed_at, c.invalidated_at, u.telegram_id, u.chat_id
from login_codes c
join telegram_users u on u.telegram_id = c.telegram_id
where c.id = $1;

-- name: MarkLoginCodeSent :exec
update login_codes
set sent_at = $2
where id = $1;

-- name: GetDeviceLimitForUpdate :one
-- The row lock makes the count below safe against a concurrent login.
select device_limit
from accounts
where id = $1
for update;

-- name: CountActiveDevices :one
select count(*)
from devices
where account_id = $1 and revoked_at is null;

-- name: GetDeviceByInstallIDForUpdate :one
select id, account_id, revoked_at
from devices
where install_id = $1
for update;

-- name: InsertDevice :one
insert into devices (account_id, install_id, platform, model, app_version, token_hash)
values ($1, $2, $3, $4, $5, $6)
returning id;

-- name: RebindDevice :exec
update devices
set account_id = $2,
    platform = $3,
    model = $4,
    app_version = $5,
    token_hash = $6,
    last_seen_at = now(),
    revoked_at = null
where id = $1;

-- name: RevokeDevice :exec
update devices
set revoked_at = now()
where id = $1 and revoked_at is null;
