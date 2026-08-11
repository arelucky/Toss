begin;

create extension if not exists pgtap with schema extensions;

select plan(37);

select has_table('public', 'coins', 'coins table exists');
select has_table('public', 'coin_versions', 'coin_versions table exists');
select col_is_unique('public', 'coins', 'slug', 'coins slug is unique');
select policies_are('public', 'coins', array['published coins are publicly readable']);
select policies_are('public', 'coin_versions', array['active published versions are publicly readable']);

select ok(
  (select relrowsecurity and relforcerowsecurity from pg_catalog.pg_class where oid = 'public.coins'::regclass),
  'coins enable and force RLS'
);
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_catalog.pg_class where oid = 'public.coin_versions'::regclass),
  'coin_versions enable and force RLS'
);
select ok(
  (
    select condeferrable and condeferred
    from pg_catalog.pg_constraint
    where conrelid = 'public.coins'::regclass
      and conname = 'coins_active_version_id_fkey'
  ),
  'active version foreign key is deferrable and initially deferred'
);

select ok(
  has_table_privilege('anon', 'public.coins', 'SELECT')
  and not has_table_privilege('anon', 'public.coins', 'INSERT, UPDATE, DELETE'),
  'anon can only select coins'
);
select ok(
  has_table_privilege('anon', 'public.coin_versions', 'SELECT')
  and not has_table_privilege('anon', 'public.coin_versions', 'INSERT, UPDATE, DELETE'),
  'anon can only select coin versions'
);
select ok(
  has_table_privilege('authenticated', 'public.coins', 'SELECT')
  and not has_table_privilege('authenticated', 'public.coins', 'INSERT, UPDATE, DELETE'),
  'authenticated can only select coins'
);
select ok(
  has_table_privilege('authenticated', 'public.coin_versions', 'SELECT')
  and not has_table_privilege('authenticated', 'public.coin_versions', 'INSERT, UPDATE, DELETE'),
  'authenticated can only select coin versions'
);

insert into public.coins (id, slug, display_name, status)
values
  ('30000000-0000-0000-0000-000000000001', 'classic-gold', 'Classic Gold', 'published'),
  ('30000000-0000-0000-0000-000000000002', 'draft-silver', 'Draft Silver', 'draft'),
  ('30000000-0000-0000-0000-000000000003', 'hidden-copper', 'Hidden Copper', 'hidden');

insert into public.coin_versions (
  id,
  coin_id,
  version_number,
  model_path,
  preview_path,
  model_byte_size,
  model_sha256,
  min_app_version,
  status
)
values
  (
    '40000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    1,
    'coins/classic-gold/v1/model.usdz',
    'coins/classic-gold/v1/preview.webp',
    1024,
    repeat('a', 64),
    '1.0.0',
    'published'
  ),
  (
    '40000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000001',
    2,
    'coins/classic-gold/v2/model.usdz',
    'coins/classic-gold/v2/preview.webp',
    2048,
    repeat('b', 64),
    '1.0.0',
    'draft'
  ),
  (
    '40000000-0000-0000-0000-000000000003',
    '30000000-0000-0000-0000-000000000002',
    1,
    'coins/draft-silver/v1/model.usdz',
    'coins/draft-silver/v1/preview.webp',
    1024,
    repeat('c', 64),
    '1.0.0',
    'published'
  ),
  (
    '40000000-0000-0000-0000-000000000004',
    '30000000-0000-0000-0000-000000000003',
    1,
    'coins/hidden-copper/v1/model.usdz',
    'coins/hidden-copper/v1/preview.webp',
    1024,
    repeat('d', 64),
    '1.0.0',
    'published'
  );

update public.coins
set
  active_version_id = '40000000-0000-0000-0000-000000000001',
  published_at = now()
where id = '30000000-0000-0000-0000-000000000001';

set local role anon;

select is(
  (select array_agg(slug order by slug)::text[] from public.coins),
  array['classic-gold']::text[],
  'anon sees only published coins'
);
select is(
  (select array_agg(id order by id)::uuid[] from public.coin_versions),
  array['40000000-0000-0000-0000-000000000001'::uuid],
  'anon sees only the active published version of a published coin'
);
select is(
  (select active_version_id from public.coins where slug = 'classic-gold'),
  '40000000-0000-0000-0000-000000000001'::uuid,
  'anon can read the published coin active version id'
);
select throws_ok(
  $$insert into public.coins (slug, display_name, status) values ('anon-coin', 'Anon Coin', 'draft')$$,
  '42501',
  null,
  'anon cannot insert coins'
);
select throws_ok(
  $$update public.coins set display_name = 'Changed' where slug = 'classic-gold'$$,
  '42501',
  null,
  'anon cannot update coins'
);
select throws_ok(
  $$delete from public.coins where slug = 'classic-gold'$$,
  '42501',
  null,
  'anon cannot delete coins'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 9, 'anon-model', 'anon-preview', 1, repeat('e', 64), '1.0.0', 'draft')$$,
  '42501',
  null,
  'anon cannot insert coin versions'
);
select throws_ok(
  $$update public.coin_versions set model_byte_size = 1 where id = '40000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'anon cannot update coin versions'
);
select throws_ok(
  $$delete from public.coin_versions where id = '40000000-0000-0000-0000-000000000001'$$,
  '42501',
  null,
  'anon cannot delete coin versions'
);

reset role;
set local role authenticated;

select is(
  (select array_agg(slug order by slug)::text[] from public.coins),
  array['classic-gold']::text[],
  'authenticated sees only published coins'
);
select is(
  (select array_agg(id order by id)::uuid[] from public.coin_versions),
  array['40000000-0000-0000-0000-000000000001'::uuid],
  'authenticated sees only active published versions'
);

reset role;

select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 1, 'duplicate-version-model', 'duplicate-version-preview', 1, repeat('e', 64), '1.0.0', 'draft')$$,
  '23505',
  null,
  'version number is unique within a coin'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'uppercase-hash-model', 'uppercase-hash-preview', 1, repeat('A', 64), '1.0.0', 'draft')$$,
  '23514',
  null,
  'uppercase SHA-256 is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'short-hash-model', 'short-hash-preview', 1, repeat('a', 63), '1.0.0', 'draft')$$,
  '23514',
  null,
  'non-64-character SHA-256 is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'zero-size-model', 'zero-size-preview', 0, repeat('e', 64), '1.0.0', 'draft')$$,
  '23514',
  null,
  'zero model size is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'negative-size-model', 'negative-size-preview', -1, repeat('e', 64), '1.0.0', 'draft')$$,
  '23514',
  null,
  'negative model size is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 0, 'zero-version-model', 'zero-version-preview', 1, repeat('e', 64), '1.0.0', 'draft')$$,
  '23514',
  null,
  'non-positive version number is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, asset_schema_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'zero-schema-model', 'zero-schema-preview', 1, repeat('e', 64), '1.0.0', 0, 'draft')$$,
  '23514',
  null,
  'non-positive asset schema version is rejected'
);
select throws_ok(
  $$insert into public.coins (slug, display_name, status) values ('invalid-coin', 'Invalid Coin', 'invalid')$$,
  '23514',
  null,
  'unknown coin status is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'invalid-status-model', 'invalid-status-preview', 1, repeat('e', 64), '1.0.0', 'invalid')$$,
  '23514',
  null,
  'unknown coin version status is rejected'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'coins/classic-gold/v1/model.usdz', 'unique-preview', 1, repeat('e', 64), '1.0.0', 'draft')$$,
  '23505',
  null,
  'model paths are immutable and unique'
);
select throws_ok(
  $$insert into public.coin_versions (coin_id, version_number, model_path, preview_path, model_byte_size, model_sha256, min_app_version, status) values ('30000000-0000-0000-0000-000000000001', 3, 'unique-model', 'coins/classic-gold/v1/preview.webp', 1, repeat('e', 64), '1.0.0', 'draft')$$,
  '23505',
  null,
  'preview paths are immutable and unique'
);

set constraints all immediate;

select throws_ok(
  $$update public.coins set active_version_id = '40000000-0000-0000-0000-000000000003' where id = '30000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'active version must belong to the same coin'
);
select throws_ok(
  $$update public.coins set active_version_id = '40000000-0000-0000-0000-000000000002' where id = '30000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'active version must be published'
);
select lives_ok(
  $$update public.coins set active_version_id = '40000000-0000-0000-0000-000000000001' where id = '30000000-0000-0000-0000-000000000001'$$,
  'published version from the same coin can be active'
);

select * from finish();
rollback;
