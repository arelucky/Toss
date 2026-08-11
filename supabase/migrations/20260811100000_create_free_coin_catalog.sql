create table public.coins (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  display_name text not null,
  description text,
  sort_order integer not null default 0,
  is_featured boolean not null default false,
  status text not null check (status in ('draft', 'published', 'hidden', 'retired')),
  active_version_id uuid,
  published_at timestamp with time zone,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table public.coin_versions (
  id uuid primary key default gen_random_uuid(),
  coin_id uuid not null references public.coins(id) on delete restrict,
  version_number integer not null check (version_number > 0),
  model_path text not null,
  preview_path text not null,
  model_byte_size bigint not null check (model_byte_size > 0),
  model_sha256 text not null check (model_sha256 ~ '^[0-9a-f]{64}$'),
  min_app_version text not null,
  asset_schema_version integer not null default 1 check (asset_schema_version > 0),
  status text not null check (status in ('draft', 'published', 'deprecated')),
  created_at timestamp with time zone not null default now(),
  published_at timestamp with time zone,
  unique (coin_id, version_number),
  unique (model_path),
  unique (preview_path)
);

alter table public.coins
add constraint coins_active_version_id_fkey
foreign key (active_version_id)
references public.coin_versions(id)
on delete restrict
deferrable initially deferred;

create function private.enforce_coin_active_version()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.active_version_id is null then
    return new;
  end if;

  if not exists (
    select 1
    from public.coin_versions
    where id = new.active_version_id
      and coin_id = new.id
      and status = 'published'
  ) then
    raise check_violation using
      message = 'Active version must belong to the same coin and be published';
  end if;

  return new;
end;
$$;

create function private.enforce_active_coin_version_update()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if exists (
    select 1
    from public.coins
    where active_version_id = new.id
      and (id <> new.coin_id or new.status <> 'published')
  ) then
    raise check_violation using
      message = 'An active version must remain published and belong to its coin';
  end if;

  return new;
end;
$$;

create constraint trigger enforce_coin_active_version
after insert or update on public.coins
deferrable initially deferred
for each row
execute function private.enforce_coin_active_version();

create constraint trigger enforce_active_coin_version_update
after update on public.coin_versions
deferrable initially deferred
for each row
execute function private.enforce_active_coin_version_update();

revoke all on function private.enforce_coin_active_version() from public;
revoke all on function private.enforce_coin_active_version() from anon;
revoke all on function private.enforce_coin_active_version() from authenticated;
revoke all on function private.enforce_active_coin_version_update() from public;
revoke all on function private.enforce_active_coin_version_update() from anon;
revoke all on function private.enforce_active_coin_version_update() from authenticated;

alter table public.coins enable row level security;
alter table public.coins force row level security;
alter table public.coin_versions enable row level security;
alter table public.coin_versions force row level security;

create policy "published coins are publicly readable"
on public.coins
for select
to anon, authenticated
using (status = 'published');

create policy "active published versions are publicly readable"
on public.coin_versions
for select
to anon, authenticated
using (
  status = 'published'
  and exists (
    select 1
    from public.coins
    where coins.id = coin_versions.coin_id
      and coins.status = 'published'
      and coins.active_version_id = coin_versions.id
  )
);

revoke all on table public.coins from public;
revoke all on table public.coins from anon;
revoke all on table public.coins from authenticated;
revoke all on table public.coin_versions from public;
revoke all on table public.coin_versions from anon;
revoke all on table public.coin_versions from authenticated;

grant select on table public.coins to anon, authenticated;
grant select on table public.coin_versions to anon, authenticated;

grant select, insert, update, delete on table public.coins to service_role;
grant select, insert, update, delete on table public.coin_versions to service_role;
