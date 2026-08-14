create function public.admin_publish_coin_version(
  p_coin_id uuid,
  p_version_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_coin public.coins%rowtype;
  locked_version public.coin_versions%rowtype;
  transition_time timestamp with time zone := now();
begin
  select *
  into locked_coin
  from public.coins
  where id = p_coin_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'coin_not_found';
  end if;

  select *
  into locked_version
  from public.coin_versions
  where id = p_version_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'version_not_found';
  end if;

  if locked_version.coin_id <> locked_coin.id then
    raise exception using errcode = 'P0001', message = 'version_coin_mismatch';
  end if;

  if locked_version.status <> 'draft' then
    raise exception using errcode = 'P0001', message = 'version_not_draft';
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'coin-models-free'
      and name = locked_version.model_path
  ) then
    raise exception using errcode = 'P0001', message = 'model_object_missing';
  end if;

  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'coin-previews'
      and name = locked_version.preview_path
  ) then
    raise exception using errcode = 'P0001', message = 'preview_object_missing';
  end if;

  update public.coin_versions
  set status = 'published',
      published_at = transition_time
  where id = locked_version.id;

  update public.coins
  set status = 'published',
      active_version_id = locked_version.id,
      published_at = transition_time,
      updated_at = transition_time
  where id = locked_coin.id;
end;
$$;

create function public.admin_rollback_coin_version(
  p_coin_id uuid,
  p_version_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  locked_coin public.coins%rowtype;
  locked_version public.coin_versions%rowtype;
begin
  select *
  into locked_coin
  from public.coins
  where id = p_coin_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'coin_not_found';
  end if;

  select *
  into locked_version
  from public.coin_versions
  where id = p_version_id
  for update;

  if not found then
    raise exception using errcode = 'P0001', message = 'version_not_found';
  end if;

  if locked_version.coin_id <> locked_coin.id then
    raise exception using errcode = 'P0001', message = 'version_coin_mismatch';
  end if;

  if locked_version.status <> 'published' then
    raise exception using errcode = 'P0001', message = 'version_not_published';
  end if;

  update public.coins
  set active_version_id = locked_version.id,
      updated_at = now()
  where id = locked_coin.id;
end;
$$;

revoke all on function public.admin_publish_coin_version(uuid, uuid) from public;
revoke all on function public.admin_publish_coin_version(uuid, uuid) from anon;
revoke all on function public.admin_publish_coin_version(uuid, uuid) from authenticated;
grant execute on function public.admin_publish_coin_version(uuid, uuid) to service_role;

revoke all on function public.admin_rollback_coin_version(uuid, uuid) from public;
revoke all on function public.admin_rollback_coin_version(uuid, uuid) from anon;
revoke all on function public.admin_rollback_coin_version(uuid, uuid) from authenticated;
grant execute on function public.admin_rollback_coin_version(uuid, uuid) to service_role;
