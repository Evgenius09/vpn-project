-- +goose Up
create extension if not exists citext;

create type platform        as enum ('android', 'windows');
create type server_group    as enum ('regular', 'whitelist');
create type server_protocol as enum ('vless_reality', 'hysteria2');
create type account_status  as enum ('provisioning', 'trial', 'active', 'expired', 'blocked');

create table accounts (
    id           uuid primary key default gen_random_uuid(),
    status       account_status not null default 'provisioning',
    expires_at   timestamptz,
    device_limit int not null default 5,
    created_at   timestamptz not null default now(),
    updated_at   timestamptz not null default now()
);

create table telegram_users (
    telegram_id    bigint primary key,
    account_id     uuid not null unique references accounts(id) on delete cascade,
    chat_id        bigint not null,
    username       citext unique,          -- последний известный ник без @; null, если ника нет
    first_name     text not null default '',
    bot_blocked_at timestamptz,
    last_update_id bigint not null default 0,
    created_at     timestamptz not null default now(),
    updated_at     timestamptz not null default now()
);

create table login_codes (
    id          uuid primary key default gen_random_uuid(),
    telegram_id bigint not null references telegram_users(telegram_id) on delete cascade,
    install_id  uuid not null,
    code_hash   bytea not null,            -- HMAC-SHA256(code, TOKEN_PEPPER)
    attempts    int not null default 0,
    expires_at  timestamptz not null,
    sent_at     timestamptz,
    consumed_at timestamptz,
    invalidated_at timestamptz,
    created_at  timestamptz not null default now()
);
create index login_codes_tg_created_idx on login_codes (telegram_id, created_at desc);

create table devices (
    id           uuid primary key default gen_random_uuid(),
    account_id   uuid not null references accounts(id) on delete cascade,
    install_id   uuid not null unique,
    platform     platform not null,
    model        text not null default '',
    app_version  text not null,
    token_hash   bytea not null unique,
    created_at   timestamptz not null default now(),
    last_seen_at timestamptz not null default now(),
    revoked_at   timestamptz
);
create index devices_account_active_idx on devices (account_id) where revoked_at is null;

create table panel_users (
    account_id          uuid primary key references accounts(id) on delete cascade,
    remnawave_uuid      uuid not null unique,
    short_uuid          text not null unique,
    vless_uuid          text not null,   -- секрет, не логировать
    hysteria2_auth      text not null,   -- секрет, не логировать
    traffic_limit_bytes bigint not null default 0,
    traffic_used_bytes  bigint not null default 0,
    synced_at           timestamptz not null default now()
);

create table servers (
    id                  uuid primary key default gen_random_uuid(),
    remnawave_host_uuid uuid not null unique,
    grp                 server_group not null,
    protocol            server_protocol not null,
    display_name        text not null,
    country_code        char(2) not null,
    city                text,
    address             text not null,
    port                int not null check (port between 1 and 65535),
    params              jsonb not null default '{}'::jsonb,  -- несекретные параметры протокола
    enabled             boolean not null default true,
    sort_weight         int not null default 0,
    content_hash        text not null,                       -- sha256 нормализованных полей
    updated_at          timestamptz not null default now()
);
create index servers_grp_enabled_idx on servers (grp, sort_weight) where enabled;

-- +goose Down
drop table servers;
drop table panel_users;
drop table devices;
drop table login_codes;
drop table telegram_users;
drop table accounts;
drop type account_status;
drop type server_protocol;
drop type server_group;
drop type platform;
