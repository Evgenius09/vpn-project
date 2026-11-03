-- name: LockCatalog :exec
-- Negative keys are global locks; telegram ids, the other keys, are positive.
select pg_advisory_xact_lock(-2);

-- name: UpsertCatalogServer :execrows
-- A row changes only when its content or its enabled flag does, so a repeated
-- sync keeps updated_at (tech.md 7).
insert into servers (
    remnawave_host_uuid, grp, protocol, display_name, country_code, city,
    address, port, params, enabled, sort_weight, content_hash
)
values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
on conflict (remnawave_host_uuid) do update
set grp = excluded.grp,
    protocol = excluded.protocol,
    display_name = excluded.display_name,
    country_code = excluded.country_code,
    city = excluded.city,
    address = excluded.address,
    port = excluded.port,
    params = excluded.params,
    enabled = excluded.enabled,
    sort_weight = excluded.sort_weight,
    content_hash = excluded.content_hash,
    updated_at = now()
where servers.content_hash <> excluded.content_hash
   or servers.enabled <> excluded.enabled;

-- name: DisableUnlistedServers :execrows
update servers
set enabled = false,
    updated_at = now()
where enabled
  and not (remnawave_host_uuid = any(sqlc.arg(listed)::uuid[]));
