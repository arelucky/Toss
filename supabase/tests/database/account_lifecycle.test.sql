begin;

create extension if not exists pgtap with schema extensions;

select plan(27);

select has_function(
  'public',
  'claim_account_preference_bootstrap',
  array['boolean', 'boolean'],
  'preference bootstrap claim function exists'
);
select fk_ok('public', 'user_profiles', 'id', 'auth', 'users', 'id', 'profile references auth user');
select fk_ok('public', 'user_preferences', 'user_id', 'auth', 'users', 'id', 'preferences reference auth user');
select fk_ok('private', 'account_preference_bootstrap', 'user_id', 'auth', 'users', 'id', 'bootstrap marker references auth user');

select is(
  (
    select confdeltype
    from pg_catalog.pg_constraint
    where conname = 'user_profiles_id_fkey'
  ),
  'c'::"char",
  'profile foreign key cascades on Auth deletion'
);
select is(
  (
    select confdeltype
    from pg_catalog.pg_constraint
    where conname = 'user_preferences_user_id_fkey'
  ),
  'c'::"char",
  'preference foreign key cascades on Auth deletion'
);

insert into auth.users (
  id,
  email,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  '10000000-0000-0000-0000-000000000001',
  'synthetic-account@example.invalid',
  jsonb_build_object('provider', 'apple', 'provider_' || 'subject', 'must-not-copy'),
  jsonb_build_object('full_name', 'Must Not Copy', 'token', 'must-not-copy'),
  now(),
  now()
);

select is((select count(*)::integer from public.user_profiles where id = '10000000-0000-0000-0000-000000000001'), 1, 'Auth creation provisions one profile');
select is((select count(*)::integer from public.user_preferences where user_id = '10000000-0000-0000-0000-000000000001'), 1, 'Auth creation provisions one preference row');
select is((select display_name from public.user_profiles where id = '10000000-0000-0000-0000-000000000001'), null, 'new profile display name is null');
select is((select status from public.user_profiles where id = '10000000-0000-0000-0000-000000000001'), 'active', 'new profile is active');
select ok((select sound_enabled and haptic_enabled from public.user_preferences where user_id = '10000000-0000-0000-0000-000000000001'), 'new preferences enable sound and haptics');

insert into auth.users (
  id,
  email,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
values (
  '10000000-0000-0000-0000-000000000001',
  'synthetic-account@example.invalid',
  '{}'::jsonb,
  '{}'::jsonb,
  now(),
  now()
)
on conflict (id) do update set updated_at = excluded.updated_at;

select is((select count(*)::integer from public.user_profiles where id = '10000000-0000-0000-0000-000000000001'), 1, 'repeated lifecycle initialization keeps one profile');
select is((select count(*)::integer from public.user_preferences where user_id = '10000000-0000-0000-0000-000000000001'), 1, 'repeated lifecycle initialization keeps one preference row');

select set_config('request.jwt.claim.sub', '10000000-0000-0000-0000-000000000001', true);
select is(
  public.claim_account_preference_bootstrap(false, true),
  true,
  'first bootstrap call claims the guest preference upload'
);
select is(
  (select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '10000000-0000-0000-0000-000000000001'),
  array[false, true],
  'first bootstrap claim uploads guest preferences'
);
select is(
  public.claim_account_preference_bootstrap(true, false),
  false,
  'subsequent bootstrap call reports an existing account'
);
select is(
  (select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '10000000-0000-0000-0000-000000000001'),
  array[false, true],
  'subsequent bootstrap call does not overwrite server preferences'
);
select is(
  (select count(*)::integer from private.account_preference_bootstrap where user_id = '10000000-0000-0000-0000-000000000001'),
  1,
  'bootstrap claim creates one private marker'
);

select throws_ok(
  $$update public.user_profiles set display_name = '   ' where id = '10000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'blank display names are rejected'
);
select lives_ok(
  $$update public.user_profiles set display_name = '  ' || repeat('a', 80) || '  ' where id = '10000000-0000-0000-0000-000000000001'$$,
  'display names whose trimmed value is at most 80 characters are accepted'
);
select throws_ok(
  $$update public.user_profiles set display_name = repeat('a', 81) where id = '10000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'display names longer than 80 characters are rejected'
);
select throws_ok(
  $$update public.user_profiles set status = 'unknown' where id = '10000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'unknown profile status is rejected'
);
select lives_ok(
  $$update public.user_profiles set status = 'disabled' where id = '10000000-0000-0000-0000-000000000001'$$,
  'disabled is an allowed profile status'
);
select lives_ok(
  $$update public.user_profiles set status = 'deleted' where id = '10000000-0000-0000-0000-000000000001'$$,
  'deleted is an allowed controlled pre-deletion status'
);

delete from auth.users where id = '10000000-0000-0000-0000-000000000001';

select is((select count(*)::integer from public.user_profiles where id = '10000000-0000-0000-0000-000000000001'), 0, 'Auth deletion cascades profile deletion');
select is((select count(*)::integer from public.user_preferences where user_id = '10000000-0000-0000-0000-000000000001'), 0, 'Auth deletion cascades preference deletion');
select is((select count(*)::integer from private.account_preference_bootstrap where user_id = '10000000-0000-0000-0000-000000000001'), 0, 'Auth deletion cascades bootstrap marker deletion');

select * from finish();
rollback;
