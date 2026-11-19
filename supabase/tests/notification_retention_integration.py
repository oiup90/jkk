"""Test in a disposable local database with the full schema applied."""
import subprocess
import sys

DB = sys.argv[1]


def sql(query, *, fails=False):
    result = subprocess.run(
        ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', query],
        capture_output=True, text=True,
    )
    if fails:
        assert result.returncode != 0, 'Unexpected success'
    elif result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ''


# No client or service role may invoke the privileged cleanup.
for role in ('anon', 'authenticated', 'service_role'):
    assert sql("select has_function_privilege('%s', "
               "'growth_internal.purge_expired_user_notifications()', 'EXECUTE')" % role) == 'f'
    sql('set role %s; select growth_internal.purge_expired_user_notifications()' % role, fails=True)

# now() is constant inside the transaction, so the boundary is exact.
assert sql("""
begin;
insert into auth.users(id) values
 ('b0000000-0000-4000-8000-000000000001'),
 ('b0000000-0000-4000-8000-000000000002');
insert into growth_internal.push_tokens(id,user_id,token) values
 ('b1000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001','synthetic-retention-token-001');
insert into public.notifications(id,user_id,kind,created_at,read_at,show_in_app,deliver_push) values
 ('b2000000-0000-4000-8000-000000000001','b0000000-0000-4000-8000-000000000001','approved',now()-interval '72 hours',null,true,true),
 ('b2000000-0000-4000-8000-000000000002','b0000000-0000-4000-8000-000000000002','rejected',now()-interval '100 hours',now(),true,false),
 ('b2000000-0000-4000-8000-000000000003','b0000000-0000-4000-8000-000000000001','approved',now()-interval '72 hours'+interval '1 microsecond',null,true,true),
 ('b2000000-0000-4000-8000-000000000004','b0000000-0000-4000-8000-000000000001','approved',now()-interval '100 hours',null,false,true);
do $$ begin
 if growth_internal.purge_expired_user_notifications() <> 2 then raise exception 'wrong deletion count'; end if;
 if exists(select 1 from public.notifications where id in
  ('b2000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000002')) then raise exception 'expired inbox rows retained'; end if;
 if (select count(*) from public.notifications where id in
  ('b2000000-0000-4000-8000-000000000003','b2000000-0000-4000-8000-000000000004')) <> 2 then raise exception 'young or push-only rows deleted'; end if;
 if exists(select 1 from growth_internal.push_jobs where notification_id='b2000000-0000-4000-8000-000000000001') then raise exception 'old push job retained'; end if;
 if (select count(*) from growth_internal.push_jobs where notification_id in
  ('b2000000-0000-4000-8000-000000000003','b2000000-0000-4000-8000-000000000004')) <> 2 then raise exception 'unrelated push jobs deleted'; end if;
 if growth_internal.purge_expired_user_notifications() <> 0 then raise exception 'cleanup not idempotent'; end if;
end $$;
rollback;
select 'ok';
""") == 'ok'
print('PASS: 72-hour boundary, users, read states, push-only exclusion, cascading jobs, idempotency and permissions')
