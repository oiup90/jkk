"""Local-only tests for generated bonus and transfer references."""
import concurrent.futures
import subprocess
import sys
import uuid
DB=sys.argv[1]
a,b=str(uuid.uuid4()),str(uuid.uuid4())
def sql(query, user=None, fails=False):
    prefix='' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query],capture_output=True,text=True)
    if fails: assert p.returncode != 0,query
    else: assert p.returncode == 0,p.stderr
    return (p.stdout.strip().splitlines() or [''])[-1]
for u in (a,b):
    sql(f"insert into auth.users(id) values('{u}'); insert into public.wallets(id,balance) values('{u}',100)")
def add(i):
    reason='welcome' if i%2==0 else 'referral'
    return sql(f"insert into public.coin_ledger(user_id,amount,reason) values('{a}',1,'{reason}') returning reference_id")
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    refs=list(pool.map(add,range(30)))
assert len(set(refs))==30
assert all(len(r)==12 and r[:2] in ('RG','RF') and r[2:].isdigit() for r in refs)
assert sql(f"select count(*) from public.coin_ledger where user_id='{a}'",b)=='0'
sql(f"update public.coin_ledger set reference_id='RG9999999999' where reference_id='{refs[0]}'",fails=True)
sql(f"insert into public.coin_ledger(user_id,amount,reason) values('{a}',1,'welcome')",a,fails=True)
print('PASS: concurrent bonus references unique, correctly prefixed, immutable and owner protected')
