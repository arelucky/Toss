begin;

create extension if not exists pgtap with schema extensions;

select plan(74);

insert into auth.users (id, email, created_at, updated_at)
values
  ('20000000-0000-0000-0000-000000000001', 'rls-user-a@example.invalid', now(), now()),
  ('20000000-0000-0000-0000-000000000002', 'rls-user-b@example.invalid', now(), now());

update public.user_profiles
set display_name = case id
  when '20000000-0000-0000-0000-000000000001' then 'User A'
  when '20000000-0000-0000-0000-000000000002' then 'User B'
end,
updated_at = now() - interval '1 day'
where id in (
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002'
);

update public.user_preferences
set updated_at = now() - interval '1 day'
where user_id in (
  '20000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000002'
);

select ok(
  (select relrowsecurity and relforcerowsecurity from pg_catalog.pg_class where oid = 'public.user_profiles'::regclass),
  'profiles enable and force RLS'
);
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_catalog.pg_class where oid = 'public.user_preferences'::regclass),
  'preferences enable and force RLS'
);
select ok(
  has_table_privilege('authenticated', 'public.user_profiles', 'SELECT')
  and has_table_privilege('authenticated', 'public.user_preferences', 'SELECT'),
  'authenticated has SELECT on both account tables'
);
select is(
  (
    select array_agg(column_name order by column_name)::text[]
    from information_schema.column_privileges
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'user_profiles'
      and privilege_type = 'UPDATE'
  ),
  array['display_name']::text[],
  'authenticated can update only profile display_name'
);
select is(
  (
    select array_agg(column_name order by column_name)::text[]
    from information_schema.column_privileges
    where grantee = 'authenticated'
      and table_schema = 'public'
      and table_name = 'user_preferences'
      and privilege_type = 'UPDATE'
  ),
  array['haptic_enabled', 'selected_coin_id', 'sound_enabled']::text[],
  'authenticated can update only sound, haptic, and selected coin preferences'
);
select ok(
  not has_table_privilege('authenticated', 'public.user_profiles', 'INSERT, DELETE')
  and not has_table_privilege('authenticated', 'public.user_preferences', 'INSERT, DELETE'),
  'authenticated has no direct INSERT or DELETE'
);
select ok(
  not has_table_privilege('anon', 'public.user_profiles', 'SELECT, INSERT, UPDATE, DELETE')
  and not has_table_privilege('anon', 'public.user_preferences', 'SELECT, INSERT, UPDATE, DELETE'),
  'anon has no account table privileges'
);
select ok(
  has_function_privilege('authenticated', 'public.claim_account_preference_bootstrap(boolean,boolean)', 'EXECUTE'),
  'authenticated can execute only the bootstrap client RPC'
);
select ok(
  to_regprocedure('public.claim_account_preference_bootstrap(uuid,boolean,boolean)') is null,
  'bootstrap RPC exposes no caller-supplied user id parameter'
);
select ok(
  not has_function_privilege('anon', 'public.claim_account_preference_bootstrap(boolean,boolean)', 'EXECUTE'),
  'anon cannot execute the bootstrap RPC'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'public.claim_account_preference_bootstrap(boolean,boolean)'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  0,
  'PUBLIC cannot execute the bootstrap RPC'
);
select ok(
  not has_function_privilege('anon', 'private.handle_auth_user_lifecycle()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.handle_auth_user_lifecycle()', 'EXECUTE')
  and not exists (
    select 1
    from pg_catalog.pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'private.handle_auth_user_lifecycle()'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'internal Auth lifecycle function has no client execute privilege'
);
select ok(
  not has_function_privilege('anon', 'private.set_account_updated_at()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'private.set_account_updated_at()', 'EXECUTE')
  and not exists (
    select 1
    from pg_catalog.pg_proc p
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) acl
    where p.oid = 'private.set_account_updated_at()'::regprocedure
      and acl.grantee = 0
      and acl.privilege_type = 'EXECUTE'
  ),
  'internal updated-at function has no client execute privilege'
);
select ok(
  not has_schema_privilege('anon', 'private', 'USAGE')
  and not has_schema_privilege('authenticated', 'private', 'USAGE')
  and not exists (
    select 1
    from pg_catalog.pg_namespace n
    cross join lateral aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) acl
    where n.oid = 'private'::regnamespace
      and acl.grantee = 0
      and acl.privilege_type = 'USAGE'
  ),
  'private schema has no client USAGE privilege'
);
select ok(
  not has_table_privilege('anon', 'private.account_preference_bootstrap', 'SELECT, INSERT, UPDATE, DELETE')
  and not has_table_privilege('authenticated', 'private.account_preference_bootstrap', 'SELECT, INSERT, UPDATE, DELETE'),
  'private bootstrap table has no client table privileges'
);
select ok(
  has_table_privilege('service_role', 'public.user_profiles', 'SELECT, INSERT, UPDATE, DELETE')
  and has_table_privilege('service_role', 'public.user_preferences', 'SELECT, INSERT, UPDATE, DELETE'),
  'trusted service role retains account lifecycle table privileges'
);

set local role service_role;
select is((select count(*)::integer from public.user_profiles), 2, 'trusted service role can verify account lifecycle rows');
reset role;

set local role anon;

select throws_ok($$select * from public.user_profiles$$, '42501', null, 'anon cannot read profiles');
select throws_ok($$select * from public.user_preferences$$, '42501', null, 'anon cannot read preferences');
select throws_ok($$insert into public.user_profiles (id) values ('20000000-0000-0000-0000-000000000001')$$, '42501', null, 'anon cannot insert profiles');
select throws_ok($$update public.user_profiles set display_name = 'Anonymous' where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'anon cannot update profiles');
select throws_ok($$delete from public.user_profiles where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'anon cannot delete profiles');
select throws_ok($$insert into public.user_preferences (user_id) values ('20000000-0000-0000-0000-000000000001')$$, '42501', null, 'anon cannot insert preferences');
select throws_ok($$update public.user_preferences set sound_enabled = false where user_id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'anon cannot update preferences');
select throws_ok($$delete from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'anon cannot delete preferences');
select throws_ok($$select public.claim_account_preference_bootstrap(false, false)$$, '42501', null, 'anon cannot call bootstrap RPC');
select throws_ok($$select private.handle_auth_user_lifecycle()$$, '42501', null, 'anon cannot call Auth lifecycle function');
select throws_ok($$select private.set_account_updated_at()$$, '42501', null, 'anon cannot call updated-at function');
select throws_ok($$select * from private.account_preference_bootstrap$$, '42501', null, 'anon cannot access private bootstrap rows');

reset role;
select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select results_eq($$select id from public.user_profiles$$, $$values ('20000000-0000-0000-0000-000000000001'::uuid)$$, 'user A reads only own profile');
select is((select count(*)::integer from public.user_profiles where id = '20000000-0000-0000-0000-000000000002'), 0, 'user A cannot read user B profile');
select results_eq($$select user_id from public.user_preferences$$, $$values ('20000000-0000-0000-0000-000000000001'::uuid)$$, 'user A reads only own preferences');
select is((select count(*)::integer from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000002'), 0, 'user A cannot read user B preferences');
select lives_ok($$update public.user_profiles set display_name = 'Updated A' where id = '20000000-0000-0000-0000-000000000001'$$, 'user A can update own display name');
select is((select display_name from public.user_profiles where id = '20000000-0000-0000-0000-000000000001'), 'Updated A', 'user A display name changed');
select lives_ok($$update public.user_profiles set display_name = 'Cross A' where id = '20000000-0000-0000-0000-000000000002'$$, 'cross-user profile update affects no visible row');
select is((select count(*)::integer from public.user_profiles where display_name = 'Cross A'), 0, 'user A did not change user B profile');
select lives_ok($$update public.user_preferences set sound_enabled = false, haptic_enabled = true where user_id = '20000000-0000-0000-0000-000000000001'$$, 'user A can update own preferences');
select is((select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'), array[false, true], 'user A preferences changed');
select lives_ok($$update public.user_preferences set sound_enabled = false where user_id = '20000000-0000-0000-0000-000000000002'$$, 'cross-user preference update affects no visible row');
select is((select count(*)::integer from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000002' and sound_enabled = false), 0, 'user A did not change user B preferences');
select throws_ok($$update public.user_profiles set id = '20000000-0000-0000-0000-000000000003' where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change profile id');
select throws_ok($$update public.user_profiles set status = 'disabled' where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change profile status');
select throws_ok($$update public.user_profiles set created_at = now() where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change profile created_at');
select throws_ok($$update public.user_profiles set updated_at = now() where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change profile updated_at');
select throws_ok($$update public.user_preferences set user_id = '20000000-0000-0000-0000-000000000003' where user_id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change preference user id');
select throws_ok($$update public.user_preferences set created_at = now() where user_id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change preference created_at');
select throws_ok($$update public.user_preferences set updated_at = now() where user_id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot change preference updated_at');
select throws_ok($$insert into public.user_profiles (id) values ('20000000-0000-0000-0000-000000000003')$$, '42501', null, 'user A cannot insert profiles');
select throws_ok($$delete from public.user_profiles where id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot delete profiles');
select throws_ok($$insert into public.user_preferences (user_id) values ('20000000-0000-0000-0000-000000000003')$$, '42501', null, 'user A cannot insert preferences');
select throws_ok($$delete from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'$$, '42501', null, 'user A cannot delete preferences');
select is((select updated_at from public.user_profiles where id = '20000000-0000-0000-0000-000000000001'), now(), 'profile updated_at is maintained by the database transaction');
select is(public.claim_account_preference_bootstrap(false, false), true, 'user A first bootstrap claim succeeds');
select is((select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'), array[false, false], 'user A bootstrap uploads guest preferences');
select is(public.claim_account_preference_bootstrap(true, true), false, 'user A repeated bootstrap claim fails');
select is((select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'), array[false, false], 'repeated bootstrap does not overwrite user A server preferences');

reset role;
select is((select count(*)::integer from private.account_preference_bootstrap where user_id = '20000000-0000-0000-0000-000000000001'), 1, 'user A has one bootstrap marker');
select is((select count(*)::integer from private.account_preference_bootstrap where user_id = '20000000-0000-0000-0000-000000000002'), 0, 'user A call did not bootstrap user B');

select set_config('request.jwt.claim.sub', '20000000-0000-0000-0000-000000000002', true);
set local role authenticated;

select results_eq($$select id from public.user_profiles$$, $$values ('20000000-0000-0000-0000-000000000002'::uuid)$$, 'user B reads only own profile');
select is((select count(*)::integer from public.user_profiles where id = '20000000-0000-0000-0000-000000000001'), 0, 'user B cannot read user A profile');
select results_eq($$select user_id from public.user_preferences$$, $$values ('20000000-0000-0000-0000-000000000002'::uuid)$$, 'user B reads only own preferences');
select is((select count(*)::integer from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'), 0, 'user B cannot read user A preferences');
select lives_ok($$update public.user_profiles set display_name = 'Updated B' where id = '20000000-0000-0000-0000-000000000002'$$, 'user B can update own display name');
select is((select display_name from public.user_profiles where id = '20000000-0000-0000-0000-000000000002'), 'Updated B', 'user B display name changed');
select lives_ok($$update public.user_profiles set display_name = 'Cross B' where id = '20000000-0000-0000-0000-000000000001'$$, 'user B cross-user profile update affects no visible row');
select is((select count(*)::integer from public.user_profiles where display_name = 'Cross B'), 0, 'user B did not change user A profile');
select lives_ok($$update public.user_preferences set sound_enabled = true, haptic_enabled = false where user_id = '20000000-0000-0000-0000-000000000002'$$, 'user B can update own preferences');
select is((select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000002'), array[true, false], 'user B preferences changed');
select lives_ok($$update public.user_preferences set haptic_enabled = true where user_id = '20000000-0000-0000-0000-000000000001'$$, 'user B cross-user preference update affects no visible row');
select is((select count(*)::integer from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001' and haptic_enabled = true), 0, 'user B did not change user A preferences');
select is(public.claim_account_preference_bootstrap(true, false), true, 'user B first bootstrap claim succeeds independently');

reset role;
select is((select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '20000000-0000-0000-0000-000000000001'), array[false, false], 'user B bootstrap did not change user A preferences');
select is((select count(*)::integer from private.account_preference_bootstrap where user_id = '20000000-0000-0000-0000-000000000002'), 1, 'user B has one bootstrap marker');

select * from finish();
rollback;
