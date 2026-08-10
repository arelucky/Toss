begin;

create extension if not exists pgtap with schema extensions;

select plan(33);

select has_table('public', 'account_deletion_requests', 'server-only deletion request table exists');
select columns_are(
  'public',
  'account_deletion_requests',
  array['request_id', 'status', 'requested_at', 'completed_at', 'apple_revocation_status'],
  'deletion requests contain only non-personal lifecycle fields'
);
select col_type_is('public', 'account_deletion_requests', 'request_id', 'uuid', 'request id is uuid');
select col_type_is('public', 'account_deletion_requests', 'status', 'text', 'status is text');
select col_type_is('public', 'account_deletion_requests', 'requested_at', 'timestamp with time zone', 'requested_at is timestamptz');
select col_type_is('public', 'account_deletion_requests', 'completed_at', 'timestamp with time zone', 'completed_at is timestamptz');
select col_type_is('public', 'account_deletion_requests', 'apple_revocation_status', 'text', 'Apple revocation status is text');
select col_is_pk('public', 'account_deletion_requests', 'request_id', 'request id is the primary key');
select col_not_null('public', 'account_deletion_requests', 'request_id', 'request id is required');
select col_not_null('public', 'account_deletion_requests', 'status', 'status is required');
select col_not_null('public', 'account_deletion_requests', 'requested_at', 'requested_at is required');
select col_is_null('public', 'account_deletion_requests', 'completed_at', 'completed_at is nullable');
select col_not_null('public', 'account_deletion_requests', 'apple_revocation_status', 'Apple status is required');
select col_default_is('public', 'account_deletion_requests', 'status', 'requested', 'status defaults requested');
select col_default_is('public', 'account_deletion_requests', 'requested_at', 'now()', 'requested_at defaults now');
select col_default_is('public', 'account_deletion_requests', 'apple_revocation_status', 'pending', 'Apple status defaults pending');

select ok(
  (select relrowsecurity and relforcerowsecurity from pg_catalog.pg_class where oid = 'public.account_deletion_requests'::regclass),
  'deletion requests enable and force RLS'
);
select ok(
  not has_table_privilege('anon', 'public.account_deletion_requests', 'SELECT, INSERT, UPDATE, DELETE')
  and not has_table_privilege('authenticated', 'public.account_deletion_requests', 'SELECT, INSERT, UPDATE, DELETE'),
  'client roles have no deletion request table privileges'
);
select is(
  (
    select count(*)::integer
    from pg_catalog.pg_class c
    cross join lateral aclexplode(coalesce(c.relacl, acldefault('r', c.relowner))) acl
    where c.oid = 'public.account_deletion_requests'::regclass
      and acl.grantee = 0
      and acl.privilege_type = any(array['SELECT', 'INSERT', 'UPDATE', 'DELETE'])
  ),
  0,
  'PUBLIC has no deletion request table privileges'
);
select ok(
  has_table_privilege('service_role', 'public.account_deletion_requests', 'SELECT, INSERT, UPDATE, DELETE'),
  'service role has the required request lifecycle privileges'
);
select is(
  (
    select count(*)::integer
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'account_deletion_requests'
      and column_name = any(array[
        'user_id', 'apple_subject', 'provider_subject', 'display_name', 'email',
        'authorization_code', 'token', 'secret', 'error', 'error_body', 'log_body', 'ip_address'
      ])
  ),
  0,
  'request rows contain no identity, credential, error, log, or network fields'
);

insert into public.account_deletion_requests (request_id)
values ('80000000-0000-0000-0000-000000000001');

select is(
  (select status from public.account_deletion_requests where request_id = '80000000-0000-0000-0000-000000000001'),
  'requested',
  'new requests start requested'
);
select ok(
  (select requested_at is not null and completed_at is null from public.account_deletion_requests where request_id = '80000000-0000-0000-0000-000000000001'),
  'new requests receive a timestamp and are incomplete'
);
select lives_ok(
  $$insert into public.account_deletion_requests (request_id) values ('80000000-0000-0000-0000-000000000001') on conflict (request_id) do nothing$$,
  'same request id can be claimed idempotently'
);
select is(
  (select count(*)::integer from public.account_deletion_requests where request_id = '80000000-0000-0000-0000-000000000001'),
  1,
  'idempotent replay keeps one request row'
);
select lives_ok(
  $$update public.account_deletion_requests set status = 'processing' where request_id = '80000000-0000-0000-0000-000000000001'$$,
  'requested can transition to processing'
);
select lives_ok(
  $$update public.account_deletion_requests set status = 'requested', apple_revocation_status = 'manual_required' where request_id = '80000000-0000-0000-0000-000000000001'$$,
  'failed data deletion can return to requested and retain non-sensitive Apple status'
);
select lives_ok(
  $$update public.account_deletion_requests set status = 'processing' where request_id = '80000000-0000-0000-0000-000000000001'$$,
  'retry can reclaim a requested row'
);
select lives_ok(
  $$update public.account_deletion_requests set status = 'completed', completed_at = now(), apple_revocation_status = 'manual_required' where request_id = '80000000-0000-0000-0000-000000000001'$$,
  'processing can transition to completed with a terminal timestamp'
);
select throws_ok(
  $$update public.account_deletion_requests set status = 'requested', completed_at = null where request_id = '80000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'completed requests cannot return to a mutable state'
);
select throws_ok(
  $$insert into public.account_deletion_requests (request_id, status) values ('80000000-0000-0000-0000-000000000002', 'unknown')$$,
  '23514',
  null,
  'unknown request status is rejected'
);
select throws_ok(
  $$insert into public.account_deletion_requests (request_id, apple_revocation_status) values ('80000000-0000-0000-0000-000000000003', 'unknown')$$,
  '23514',
  null,
  'unknown Apple status is rejected'
);
select throws_ok(
  $$insert into public.account_deletion_requests (request_id, status, completed_at) values ('80000000-0000-0000-0000-000000000004', 'completed', null)$$,
  '23514',
  null,
  'completed requests require completed_at'
);

select * from finish();
rollback;
