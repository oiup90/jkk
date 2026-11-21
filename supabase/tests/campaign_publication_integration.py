"""Disposable PostgreSQL: campaign publication, cancellation and order IDs."""
import concurrent.futures
import re
import subprocess
import sys
import time
import uuid
from admin_test_support import test_claims

DB = sys.argv[1]
OWNER, OTHER = [str(uuid.uuid4()) for _ in range(2)]
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='


def sql(query, user=None, fails=False):
    prefix = '' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], capture_output=True, text=True)
    if fails:
        assert result.returncode != 0, query
        return result.stderr
    assert result.returncode == 0, result.stderr
    return (result.stdout.strip().splitlines() or [''])[-1]


sql(f"insert into auth.users(id) values('{OWNER}'),('{OTHER}'); insert into public.wallets(id,balance) values('{OWNER}',1000),('{OTHER}',10)")
def create(owner=OWNER):
    return sql("select public.create_campaign_at_rate('like','https://instagram.com/p/ABC/',1,1)", owner)

campaign = create()
order_id = sql(f"select order_id from public.campaigns where id='{campaign}'", OWNER)
assert re.fullmatch(r'[1-9][0-9]{11}', order_id)
assert sql(f"select count(*) from public.campaigns where id='{campaign}'", OWNER) == '1'
assert sql(f"select count(*) from public.campaigns where id='{campaign}'", OTHER) == '0'
assert 'not yet available' in sql(f"select public.submit_claim('{campaign}','sample','image/png','{PNG}')", OTHER, fails=True)
sql(f"select public.set_task_saved('{campaign}',true)", OTHER, fails=True)
sql(f"select public.report_campaign('{campaign}','reason')", OTHER, fails=True)
sql(f"update public.campaigns set order_id='123456789012' where id='{campaign}'", fails=True)
sql(f"select public.cancel_campaign('{campaign}')", OTHER, fails=True)
sql(f"select public.cancel_campaign('{campaign}')", OWNER)
assert sql(f"select balance from public.wallets where id='{OWNER}'") == '1000'
assert sql(f"select status from public.campaigns where id='{campaign}'", OWNER) == 'cancelled'

sql(f"update public.campaigns set \"createdAt\"=clock_timestamp()-interval '25 hours' where id='{campaign}'")
published = create()
sql(f"update public.campaigns set \"createdAt\"=clock_timestamp()-interval '61 seconds' where id='{published}'")
assert sql(f"select count(*) from public.campaigns where id='{published}'", OTHER) == '1'
assert 'cancellation period has ended' in sql(f"select public.cancel_campaign('{published}')", OWNER, fails=True)
sql(f"select public.set_task_saved('{published}',true)", OTHER)
sql(f"select public.submit_claim('{published}','sample','image/png','{PNG}')", OTHER)
assert sql(f"select status from public.campaign_claims where campaign_id='{published}'", OTHER) == 'pending'

# A request begun before the deadline must still fail if it acquires the row
# lock only after the deadline has passed.
sql(f"update public.campaigns set \"createdAt\"=clock_timestamp()-interval '25 hours' where id='{published}'")
waiting = create()
sql(f"update public.campaigns set \"createdAt\"=clock_timestamp()-interval '59 seconds' where id='{waiting}'")
locker = subprocess.Popen(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
    f"begin; select id from public.campaigns where id='{waiting}' for update; select pg_sleep(2); commit"],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
time.sleep(0.3)
assert 'cancellation period has ended' in sql(f"select public.cancel_campaign('{waiting}')", OWNER, fails=True)
assert locker.wait(timeout=5) == 0, locker.stderr.read()

owners = [str(uuid.uuid4()) for _ in range(40)]
sql('insert into auth.users(id) values ' + ','.join(f"('{owner}')" for owner in owners))
sql('insert into public.wallets(id,balance) values ' + ','.join(f"('{owner}',10)" for owner in owners))
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    campaigns = list(pool.map(create, owners))
ids = [sql(f"select order_id from public.campaigns where id='{c}'") for c in campaigns]
assert len(set(ids + [order_id])) == 41
assert all(re.fullmatch(r'[1-9][0-9]{11}', item) for item in ids)
assert sql("select count(*) from growth_internal.reference_reservations where reference_id in (select order_id from public.campaigns)") == str(len(ids) + 3)
sql(f"delete from public.campaigns where id='{campaign}'")
assert sql(f"select count(*) from growth_internal.reference_reservations where reference_id='{order_id}'") == '1'
print('PASS: publication delay, owner cancellation and refund, submission gates and concurrent random order IDs')
