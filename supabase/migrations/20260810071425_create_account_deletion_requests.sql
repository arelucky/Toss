create table public.account_deletion_requests (
  request_id uuid primary key,
  status text not null default 'requested'::text,
  requested_at timestamp with time zone not null default now(),
  completed_at timestamp with time zone null,
  apple_revocation_status text not null default 'pending'::text,
  constraint account_deletion_requests_status_check check (
    status = any (array['requested'::text, 'processing'::text, 'completed'::text])
  ),
  constraint account_deletion_requests_apple_status_check check (
    apple_revocation_status = any (
      array['pending'::text, 'revoked'::text, 'already_invalid'::text, 'manual_required'::text]
    )
  ),
  constraint account_deletion_requests_completed_at_check check (
    (status = 'completed'::text and completed_at is not null)
    or (status <> 'completed'::text and completed_at is null)
  )
);

create function private.enforce_account_deletion_request_transition()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.status <> 'requested'::text or new.completed_at is not null then
      raise check_violation using message = 'Deletion requests must begin requested';
    end if;
    return new;
  end if;

  if new.request_id <> old.request_id or new.requested_at <> old.requested_at then
    raise check_violation using message = 'Deletion request identity is immutable';
  end if;

  if old.status = 'completed'::text and new is distinct from old then
    raise check_violation using message = 'Completed deletion requests are immutable';
  end if;

  if new.status = old.status
    or (old.status = 'requested'::text and new.status = 'processing'::text)
    or (old.status = 'processing'::text and new.status = 'requested'::text)
    or (old.status = 'processing'::text and new.status = 'completed'::text) then
    return new;
  end if;

  raise check_violation using message = 'Invalid deletion request transition';
end;
$$;

create trigger enforce_account_deletion_request_transition
before insert or update on public.account_deletion_requests
for each row
execute function private.enforce_account_deletion_request_transition();

alter table public.account_deletion_requests enable row level security;
alter table public.account_deletion_requests force row level security;

revoke all on table public.account_deletion_requests from public;
revoke all on table public.account_deletion_requests from anon;
revoke all on table public.account_deletion_requests from authenticated;
grant select, insert, update, delete on table public.account_deletion_requests to service_role;

revoke all on function private.enforce_account_deletion_request_transition() from public;
revoke all on function private.enforce_account_deletion_request_transition() from anon;
revoke all on function private.enforce_account_deletion_request_transition() from authenticated;
