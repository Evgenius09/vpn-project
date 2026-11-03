-- Remnawave 3.4.8 identifies users by a numeric id, not a uuid (tech.md 39.2).

-- +goose Up
-- +goose StatementBegin
do $$
begin
    if exists (select 1 from panel_users) then
        raise exception 'panel_users is not empty: recreate the dev database and run make seed';
    end if;
end
$$;
-- +goose StatementEnd
alter table panel_users drop column remnawave_uuid;
alter table panel_users add column remnawave_id bigint not null unique;

-- +goose Down
-- +goose StatementBegin
do $$
begin
    if exists (select 1 from panel_users) then
        raise exception 'panel_users is not empty';
    end if;
end
$$;
-- +goose StatementEnd
alter table panel_users drop column remnawave_id;
alter table panel_users add column remnawave_uuid uuid not null unique;
