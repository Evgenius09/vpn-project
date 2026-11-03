-- name: AdvisoryLock :exec
select pg_advisory_xact_lock(sqlc.arg(key)::bigint);

-- name: GetTelegramUser :one
select telegram_id, account_id, username, bot_blocked_at, last_update_id
from telegram_users
where telegram_id = $1;

-- name: CreateAccount :one
insert into accounts default values
returning id;

-- name: InsertTelegramUser :exec
insert into telegram_users (telegram_id, account_id, chat_id, username, first_name, last_update_id)
values ($1, $2, $3, $4, $5, $6);

-- name: UpdateTelegramUser :exec
update telegram_users
set chat_id = $2,
    username = $3,
    first_name = $4,
    bot_blocked_at = $5,
    last_update_id = $6,
    updated_at = now()
where telegram_id = $1;

-- name: ReleaseTelegramUsername :exec
update telegram_users
set username = null,
    updated_at = now()
where username = $1 and telegram_id <> $2;

-- name: MarkTelegramBotBlocked :exec
update telegram_users
set bot_blocked_at = now(),
    updated_at = now()
where telegram_id = $1;
