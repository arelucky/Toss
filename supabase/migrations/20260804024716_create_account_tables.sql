create schema if not exists private;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;

create table public.user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text null,
  status text not null default 'active'::text,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),
  constraint user_profiles_display_name_check check (
    display_name is null
    or char_length(btrim(display_name)) between 1 and 80
  ),
  constraint user_profiles_status_check check (
    status = any (array['active'::text, 'disabled'::text, 'deleted'::text])
  )
);

create table public.user_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  sound_enabled boolean not null default true,
  haptic_enabled boolean not null default true,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now()
);

create table private.account_preference_bootstrap (
  user_id uuid primary key references auth.users(id) on delete cascade,
  claimed_at timestamp with time zone not null default now()
);

create function private.set_account_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_user_profiles_updated_at
before update on public.user_profiles
for each row
execute function private.set_account_updated_at();

create trigger set_user_preferences_updated_at
before update on public.user_preferences
for each row
execute function private.set_account_updated_at();

create function private.handle_auth_user_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.user_profiles (id, display_name)
  values (new.id, null)
  on conflict (id) do nothing;

  insert into public.user_preferences (user_id)
  values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

create trigger initialize_account_after_auth_user_change
after insert or update on auth.users
for each row
execute function private.handle_auth_user_lifecycle();

create function public.claim_account_preference_bootstrap(
  p_sound_enabled boolean,
  p_haptic_enabled boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := auth.uid();
  v_rows_affected integer;
begin
  if v_user_id is null then
    raise insufficient_privilege using message = 'Authentication required';
  end if;

  insert into private.account_preference_bootstrap (user_id)
  values (v_user_id)
  on conflict (user_id) do nothing;

  get diagnostics v_rows_affected = row_count;

  if v_rows_affected = 1 then
    update public.user_preferences
    set
      sound_enabled = p_sound_enabled,
      haptic_enabled = p_haptic_enabled
    where user_id = v_user_id;

    if not found then
      raise foreign_key_violation using message = 'Account preferences not initialized';
    end if;

    return true;
  end if;

  return false;
end;
$$;

revoke all on function private.set_account_updated_at() from public;
revoke all on function private.set_account_updated_at() from anon;
revoke all on function private.set_account_updated_at() from authenticated;
revoke all on function private.handle_auth_user_lifecycle() from public;
revoke all on function private.handle_auth_user_lifecycle() from anon;
revoke all on function private.handle_auth_user_lifecycle() from authenticated;
revoke all on function public.claim_account_preference_bootstrap(boolean, boolean) from public;
revoke all on function public.claim_account_preference_bootstrap(boolean, boolean) from anon;
revoke all on function public.claim_account_preference_bootstrap(boolean, boolean) from authenticated;
