"""Disposable upgrade fixture: backfill preserves campaigns and reserves IDs."""
import re
import subprocess
import sys

DB = sys.argv[1]
def sql(query):
    return subprocess.check_output(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', query], text=True).strip()

rows = sql("select id||':'||status||':'||remaining||':'||reward_per_task||':'||order_id from public.campaigns order by id").splitlines()
assert len(rows) == 2
assert rows[0].startswith('f2000000-0000-4000-8000-000000000001:active:2:2:')
assert rows[1].startswith('f2000000-0000-4000-8000-000000000002:completed:0:1:')
ids = [r.rsplit(':', 1)[1] for r in rows]
assert len(set(ids)) == 2 and all(re.fullmatch(r'[1-9][0-9]{11}', x) for x in ids)
assert sql("select count(*) from growth_internal.reference_reservations where reference_id in (select order_id from public.campaigns)") == '2'
assert sql("select balance from public.wallets where id='f1000000-0000-4000-8000-000000000001'") == '20'
print('PASS: campaign order IDs backfilled without altering existing balances or campaign state')
