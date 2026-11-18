"""Disposable database: random references and public/admin social links."""
import concurrent.futures
import json
import subprocess
import sys
import uuid
from admin_test_support import enroll_test_admins, test_claims

DB=sys.argv[1]
E,V,U=[str(uuid.uuid4()) for _ in range(3)]
def sql(q,user=None,fails=False):
    pre='' if not user else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false);"
    r=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(pre)+q],capture_output=True,text=True)
    if fails: assert r.returncode, q
    else: assert r.returncode==0, r.stderr
    return (r.stdout.strip().splitlines() or [''])[-1]
sql(f"insert into auth.users(id) values('{E}'),('{V}'),('{U}'); insert into public.admin_members(user_id,role) values('{E}','editor'),('{V}','viewer'); insert into public.wallets(id,balance) values('{U}',10)")
enroll_test_admins(DB)
# A collision against a retired/old value is retried and no caller can read reservations.
sql("insert into growth_internal.reference_reservations values('100000000000'),('RG0000000000'),('RF0000000000')")
sql('select * from growth_internal.reference_reservations',U,fails=True)
sql("select growth_internal.allocate_reference('payment')",U,fails=True)
def allocate(i):
    reason=('welcome','referral','task')[i%3]
    return sql(f"insert into public.coin_ledger(user_id,amount,reason) values('{U}',1,'{reason}') returning reference_id")
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    refs=list(pool.map(allocate,range(120)))
assert len(set(refs))==120
assert all(len(x)==12 and (x.isdigit() or (x[:2] in ('RG','RF') and x[2:].isdigit())) for x in refs)
assert all(x not in ('100000000000','RG0000000000','RF0000000000') for x in refs)
assert len(set(refs[i] for i in range(0,120,3)))==40
# Legacy references are not changed; transfer entries intentionally share one receipt.
assert sql(f"select count(*) from public.coin_ledger where user_id='{U}'")=='120'
sql("set role anon; select platform,url from public.official_social_links")
sql("select * from growth_internal.official_social_links",U,fails=True)
for p,url in [('instagram','https://www.instagram.com/freelan'),('facebook','https://facebook.com/freelan'),('youtube','https://www.youtube.com/@freelan'),('x','https://x.com/freelan')]:
    sql(f"select public.admin_set_social_link('{p}','{url}')",E)
    assert sql(f"set role anon; select url from public.official_social_links where platform='{p}'")==url
    sql(f"select public.admin_set_social_link('{p}','{url}')",V,fails=True)
    sql(f"select public.admin_set_social_link('{p}','{url}')",U,fails=True)
for url in ('http://instagram.com/a','https://instagram.com.evil.test/a','https://instagram.com@evil.test/a','https://127.0.0.1/a','https://instagram.com:443/a','https://instagram.com/a b'):
    sql(f"select public.admin_set_social_link('instagram','{url}')",E,fails=True)
assert sql("select count(*) from public.official_social_links")=='4'
sql("select public.admin_set_social_link('instagram','')",E)
assert sql("select count(*) from public.official_social_links")=='3'
assert sql("select count(*) from growth_internal.admin_operations_audit where action='Official social link'")=='5'
print('PASS: random unique references and public social links with admin authorization, allowlisted hosts and audit')
