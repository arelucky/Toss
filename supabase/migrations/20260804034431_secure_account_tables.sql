alter table public.user_profiles enable row level security;
alter table public.user_profiles force row level security;
alter table public.user_preferences enable row level security;
alter table public.user_preferences force row level security;

create policy user_profiles_select_own
on public.user_profiles
for select
to authenticated
using ((select auth.uid()) = id);

create policy user_profiles_update_own
on public.user_profiles
for update
to authenticated
using ((select auth.uid()) = id)
with check ((select auth.uid()) = id);

create policy user_preferences_select_own
on public.user_preferences
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy user_preferences_update_own
on public.user_preferences
for update
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on table public.user_profiles from public;
revoke all on table public.user_profiles from anon;
revoke all on table public.user_profiles from authenticated;
revoke all on table public.user_preferences from public;
revoke all on table public.user_preferences from anon;
revoke all on table public.user_preferences from authenticated;

grant select on table public.user_profiles to authenticated;
grant update (display_name) on table public.user_profiles to authenticated;
grant select on table public.user_preferences to authenticated;
grant update (sound_enabled, haptic_enabled) on table public.user_preferences to authenticated;

grant select, insert, update, delete on table public.user_profiles to service_role;
grant select, insert, update, delete on table public.user_preferences to service_role;

revoke all on schema private from public;
revoke all on schema private from anon;
revoke all on schema private from authenticated;
revoke all on table private.account_preference_bootstrap from public;
revoke all on table private.account_preference_bootstrap from anon;
revoke all on table private.account_preference_bootstrap from authenticated;

revoke all on function private.handle_auth_user_lifecycle() from public;
revoke all on function private.handle_auth_user_lifecycle() from anon;
revoke all on function private.handle_auth_user_lifecycle() from authenticated;
revoke all on function private.set_account_updated_at() from public;
revoke all on function private.set_account_updated_at() from anon;
revoke all on function private.set_account_updated_at() from authenticated;
revoke all on function public.claim_account_preference_bootstrap(boolean, boolean) from public;
revoke all on function public.claim_account_preference_bootstrap(boolean, boolean) from anon;
revoke all on function public.claim_account_preference_bootstrap(boolean, boolean) from authenticated;
grant execute on function public.claim_account_preference_bootstrap(boolean, boolean) to authenticated;
