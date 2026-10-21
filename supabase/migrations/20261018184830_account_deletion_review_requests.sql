-- Preparation only: no account, album, Storage object or financial row is
-- removed. Concurrent user requests share one active support inquiry.
create unique index if not exists support_account_deletion_one_open_per_owner
on public.support_inquiries(user_id)
where category='ACCOUNT_DELETION' and status in ('OPEN','IN_PROGRESS');
