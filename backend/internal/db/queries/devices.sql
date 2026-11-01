-- name: GetDeviceByTokenHash :one
select id, account_id, revoked_at
from devices
where token_hash = $1;

-- name: TouchDevice :exec
-- The window keeps a read-heavy client from writing the row on every request.
update devices
set last_seen_at = now()
where id = $1 and last_seen_at < now() - interval '1 minute';
