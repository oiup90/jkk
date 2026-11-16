-- A minimal, owner-readable projection; user_access and its audit fields remain private.
begin;
create table public.account_block_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  blocked boolean not null
);
alter table public.account_block_status enable row level security;
revoke all on public.account_block_status from public, anon, authenticated;
grant select on public.account_block_status to authenticated;
create policy account_block_status_read on public.account_block_status
  for select to authenticated using (user_id = auth.uid());

create function growth_internal.sync_account_block_status() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' or (tg_op = 'UPDATE' and old.user_id is distinct from new.user_id) then
    update public.account_block_status set blocked = false where user_id = old.user_id;
  end if;
  if tg_op <> 'DELETE' then
    insert into public.account_block_status(user_id, blocked) values (new.user_id, new.blocked)
      on conflict (user_id) do update set blocked = excluded.blocked;
  end if;
  return null;
end $$;
revoke all on function growth_internal.sync_account_block_status() from public, anon, authenticated;
create trigger sync_account_block_status
  after insert or update or delete on public.user_access
  for each row execute function growth_internal.sync_account_block_status();
insert into public.account_block_status(user_id, blocked)
  select user_id, blocked from public.user_access
  on conflict (user_id) do update set blocked = excluded.blocked;

do $$
begin
  if exists (select 1 from pg_publication where pubname='supabase_realtime' and not puballtables)
    and not exists (select 1 from pg_publication_tables where pubname='supabase_realtime'
      and schemaname='public' and tablename='account_block_status') then
    alter publication supabase_realtime add table public.account_block_status;
  end if;
end $$;
commit;
