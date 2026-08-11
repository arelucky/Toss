revoke all privileges
on table public.account_deletion_requests
from service_role;

grant select, insert, update, delete
on table public.account_deletion_requests
to service_role;
