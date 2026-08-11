begin;

create extension if not exists pgtap with schema extensions;

select plan(16);

select has_column(
  'public',
  'user_preferences',
  'selected_coin_id',
  'user preferences has a selected coin id'
);
select col_type_is(
  'public',
  'user_preferences',
  'selected_coin_id',
  'uuid',
  'selected coin id is uuid'
);
select col_is_null(
  'public',
  'user_preferences',
  'selected_coin_id',
  'selected coin id is nullable'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint constraint_record
    join pg_catalog.pg_attribute source_column
      on source_column.attrelid = constraint_record.conrelid
      and source_column.attnum = any (constraint_record.conkey)
    join pg_catalog.pg_attribute target_column
      on target_column.attrelid = constraint_record.confrelid
      and target_column.attnum = any (constraint_record.confkey)
    where constraint_record.contype = 'f'
      and constraint_record.conrelid = 'public.user_preferences'::regclass
      and constraint_record.confrelid = 'public.coins'::regclass
      and source_column.attname = 'selected_coin_id'
      and target_column.attname = 'id'
  ),
  'selected coin id references coins id'
);
select ok(
  exists (
    select 1
    from pg_catalog.pg_constraint
    where contype = 'f'
      and conrelid = 'public.user_preferences'::regclass
      and confrelid = 'public.coins'::regclass
      and confdeltype = 'n'
  ),
  'selected coin deletion sets the preference to null'
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
  'authenticated can update only feedback fields and selected coin id'
);

insert into auth.users (id, email, created_at, updated_at)
values
  ('50000000-0000-0000-0000-000000000001', 'coin-user-a@example.invalid', now(), now()),
  ('50000000-0000-0000-0000-000000000002', 'coin-user-b@example.invalid', now(), now());

insert into public.coins (id, slug, display_name, status)
values ('60000000-0000-0000-0000-000000000001', 'selected-test-coin', 'Selected Test Coin', 'draft');

update public.user_preferences
set sound_enabled = false, haptic_enabled = true
where user_id = '50000000-0000-0000-0000-000000000001';

update public.user_preferences
set sound_enabled = true, haptic_enabled = false
where user_id = '50000000-0000-0000-0000-000000000002';

select set_config('request.jwt.claim.role', 'authenticated', true);
select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select results_eq(
  $$select user_id from public.user_preferences$$,
  $$values ('50000000-0000-0000-0000-000000000001'::uuid)$$,
  'user reads only own selected coin preference row'
);
select is(
  (select count(*)::integer from public.user_preferences where user_id = '50000000-0000-0000-0000-000000000002'),
  0,
  'user cannot read another selected coin preference row'
);
select lives_ok(
  $$update public.user_preferences set selected_coin_id = '60000000-0000-0000-0000-000000000001' where user_id = '50000000-0000-0000-0000-000000000001'$$,
  'user can update own selected coin id'
);
select is(
  (select selected_coin_id from public.user_preferences where user_id = '50000000-0000-0000-0000-000000000001'),
  '60000000-0000-0000-0000-000000000001'::uuid,
  'own selected coin id is updated'
);
select is(
  (select array[sound_enabled, haptic_enabled] from public.user_preferences where user_id = '50000000-0000-0000-0000-000000000001'),
  array[false, true],
  'selected coin update preserves sound and haptic fields'
);
select lives_ok(
  $$update public.user_preferences set selected_coin_id = '60000000-0000-0000-0000-000000000001' where user_id = '50000000-0000-0000-0000-000000000002'$$,
  'cross-user selected coin update affects no visible row'
);

reset role;

select is(
  (select selected_coin_id from public.user_preferences where user_id = '50000000-0000-0000-0000-000000000002'),
  null::uuid,
  'cross-user update does not change another selection'
);

select set_config('request.jwt.claim.sub', '50000000-0000-0000-0000-000000000001', true);
set local role authenticated;

select lives_ok(
  $$update public.user_preferences set selected_coin_id = null where user_id = '50000000-0000-0000-0000-000000000001'$$,
  'user can clear own selected coin id'
);
select is(
  (select selected_coin_id from public.user_preferences where user_id = '50000000-0000-0000-0000-000000000001'),
  null::uuid,
  'cleared selected coin id maps to null'
);
select throws_ok(
  $$update public.user_preferences set selected_coin_id = '60000000-0000-0000-0000-000000000099' where user_id = '50000000-0000-0000-0000-000000000001'$$,
  '23503',
  null,
  'selected coin id must reference an existing coin'
);

select * from finish();
rollback;
