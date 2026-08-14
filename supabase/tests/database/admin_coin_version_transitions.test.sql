begin;

create extension if not exists pgtap with schema extensions;

select plan(32);

select has_function(
  'public',
  'admin_publish_coin_version',
  array['uuid', 'uuid'],
  'admin publish coin version RPC exists'
);
select has_function(
  'public',
  'admin_rollback_coin_version',
  array['uuid', 'uuid'],
  'admin rollback coin version RPC exists'
);

select ok(
  not coalesce((
    select has_function_privilege('public', function_record.oid, 'EXECUTE')
    from pg_catalog.pg_proc function_record
    join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace
    where function_schema.nspname = 'public'
      and function_record.proname = 'admin_publish_coin_version'
      and function_record.proargtypes = '2950 2950'::oidvector
  ), true),
  'PUBLIC cannot execute publish RPC'
);
select ok(
  not coalesce((select has_function_privilege('anon', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_publish_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), true),
  'anon cannot execute publish RPC'
);
select ok(
  not coalesce((select has_function_privilege('authenticated', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_publish_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), true),
  'authenticated cannot execute publish RPC'
);
select ok(
  coalesce((select has_function_privilege('service_role', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_publish_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'service role can execute publish RPC'
);
select ok(
  not coalesce((select has_function_privilege('public', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), true),
  'PUBLIC cannot execute rollback RPC'
);
select ok(
  not coalesce((select has_function_privilege('anon', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), true),
  'anon cannot execute rollback RPC'
);
select ok(
  not coalesce((select has_function_privilege('authenticated', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), true),
  'authenticated cannot execute rollback RPC'
);
select ok(
  coalesce((select has_function_privilege('service_role', function_record.oid, 'EXECUTE') from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'service role can execute rollback RPC'
);

select ok(
  coalesce((select function_record.prosecdef from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_publish_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'publish RPC is security definer'
);
select ok(
  coalesce((select function_record.prosecdef from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'rollback RPC is security definer'
);
select ok(
  coalesce((select array_to_string(function_record.proconfig, ',') = 'search_path=""' from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_publish_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'publish RPC fixes an empty search path'
);
select ok(
  coalesce((select array_to_string(function_record.proconfig, ',') = 'search_path=""' from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'rollback RPC fixes an empty search path'
);
select ok(
  coalesce((select regexp_count(lower(pg_get_functiondef(function_record.oid)), 'for update') >= 2 from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_publish_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'publish RPC locks both coin and version'
);
select ok(
  coalesce((select regexp_count(lower(pg_get_functiondef(function_record.oid)), 'for update') >= 2 from pg_catalog.pg_proc function_record join pg_catalog.pg_namespace function_schema on function_schema.oid = function_record.pronamespace where function_schema.nspname = 'public' and function_record.proname = 'admin_rollback_coin_version' and function_record.proargtypes = '2950 2950'::oidvector), false),
  'rollback RPC locks both coin and version'
);

insert into public.coins (id, slug, display_name, status)
values
  ('71000000-0000-4000-8000-000000000001', 'rpc-gold', 'RPC Gold', 'published'),
  ('71000000-0000-4000-8000-000000000002', 'rpc-silver', 'RPC Silver', 'draft');

insert into public.coin_versions (
  id, coin_id, version_number, model_path, preview_path,
  model_byte_size, model_sha256, min_app_version, status, published_at
)
values
  ('72000000-0000-4000-8000-000000000001', '71000000-0000-4000-8000-000000000001', 1, 'coins/rpc-gold/v1/model.usdz', 'coins/rpc-gold/v1/preview.webp', 1024, repeat('a', 64), '1.0.0', 'draft', null),
  ('72000000-0000-4000-8000-000000000002', '71000000-0000-4000-8000-000000000001', 2, 'coins/rpc-gold/v2/model.usdz', 'coins/rpc-gold/v2/preview.webp', 1024, repeat('b', 64), '1.0.0', 'published', now() - interval '1 day'),
  ('72000000-0000-4000-8000-000000000003', '71000000-0000-4000-8000-000000000002', 1, 'coins/rpc-silver/v1/model.usdz', 'coins/rpc-silver/v1/preview.webp', 1024, repeat('c', 64), '1.0.0', 'published', now() - interval '1 day'),
  ('72000000-0000-4000-8000-000000000004', '71000000-0000-4000-8000-000000000001', 3, 'coins/rpc-gold/v3/model.usdz', 'coins/rpc-gold/v3/preview.webp', 1024, repeat('d', 64), '1.0.0', 'draft', null);

update public.coins
set active_version_id = '72000000-0000-4000-8000-000000000002',
    published_at = now() - interval '1 day'
where id = '71000000-0000-4000-8000-000000000001';

create temporary table publish_failure_snapshot as
select row(
  version_record.status,
  version_record.published_at,
  coin_record.status,
  coin_record.active_version_id,
  coin_record.published_at
)::text as state
from public.coin_versions version_record
join public.coins coin_record on coin_record.id = version_record.coin_id
where version_record.id = '72000000-0000-4000-8000-000000000001';

select throws_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000099', '72000000-0000-4000-8000-000000000001')$$,
  'P0001', 'coin_not_found', 'publish rejects a missing coin'
);
select throws_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000099')$$,
  'P0001', 'version_not_found', 'publish rejects a missing version'
);
select throws_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000003')$$,
  'P0001', 'version_coin_mismatch', 'publish rejects a version owned by another coin'
);
select throws_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000002')$$,
  'P0001', 'version_not_draft', 'publish rejects an already published version'
);
select throws_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001')$$,
  'P0001', 'model_object_missing', 'publish requires the model object'
);

insert into storage.objects (bucket_id, name)
values ('coin-models-free', 'coins/rpc-gold/v1/model.usdz');

select throws_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001')$$,
  'P0001', 'preview_object_missing', 'publish requires the preview object'
);
select is(
  (select row(version_record.status, version_record.published_at, coin_record.status, coin_record.active_version_id, coin_record.published_at)::text
   from public.coin_versions version_record
   join public.coins coin_record on coin_record.id = version_record.coin_id
   where version_record.id = '72000000-0000-4000-8000-000000000001'),
  (select state from publish_failure_snapshot),
  'failed publish preserves every transition field'
);

insert into storage.objects (bucket_id, name)
values ('coin-previews', 'coins/rpc-gold/v1/preview.webp');

select lives_ok(
  $$select public.admin_publish_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000001')$$,
  'publish succeeds when both assets exist'
);
select ok(
  (select version_record.status = 'published'
       and version_record.published_at is not null
       and coin_record.status = 'published'
       and coin_record.active_version_id = version_record.id
       and coin_record.published_at is not null
   from public.coin_versions version_record
   join public.coins coin_record on coin_record.id = version_record.coin_id
   where version_record.id = '72000000-0000-4000-8000-000000000001'),
  'publish atomically updates version, coin, timestamps, and active pointer'
);

create temporary table rollback_version_snapshot as
select array_agg(row(id, status, published_at)::text order by id) as states
from public.coin_versions
where coin_id = '71000000-0000-4000-8000-000000000001';

select throws_ok(
  $$select public.admin_rollback_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000003')$$,
  'P0001', 'version_coin_mismatch', 'rollback rejects another coin version'
);
select throws_ok(
  $$select public.admin_rollback_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000004')$$,
  'P0001', 'version_not_published', 'rollback rejects a draft version'
);
select is(
  (select active_version_id from public.coins where id = '71000000-0000-4000-8000-000000000001'),
  '72000000-0000-4000-8000-000000000001'::uuid,
  'failed rollback preserves the active pointer'
);
select lives_ok(
  $$select public.admin_rollback_coin_version('71000000-0000-4000-8000-000000000001', '72000000-0000-4000-8000-000000000002')$$,
  'rollback accepts a published version of the same coin'
);
select is(
  (select active_version_id from public.coins where id = '71000000-0000-4000-8000-000000000001'),
  '72000000-0000-4000-8000-000000000002'::uuid,
  'rollback switches only the active pointer'
);
select is(
  (select array_agg(row(id, status, published_at)::text order by id) from public.coin_versions where coin_id = '71000000-0000-4000-8000-000000000001'),
  (select states from rollback_version_snapshot),
  'rollback leaves all version records immutable'
);
select is(
  (select count(*)::integer from storage.objects where bucket_id in ('coin-models-free', 'coin-previews') and name like 'coins/rpc-gold/%'),
  2,
  'rollback does not delete or overwrite storage objects'
);

select * from finish();
rollback;
