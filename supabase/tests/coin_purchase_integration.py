"""Run only against isolated DB with bootstrap/base/owner_review/admin_access/wallet numbers/purchase migration."""
import concurrent.futures
import json
import subprocess
import sys
import uuid
DB = sys.argv[1]
request_a, request_b = uuid.uuid4().hex, uuid.uuid4().hex
default_payment = 'MOJO' + uuid.uuid4().hex
def sql(q, fails=False):
    p = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',q],capture_output=True,text=True)
    assert (p.returncode != 0) if fails else (p.returncode == 0), p.stderr
    return p.stdout.strip().splitlines()[-1] if p.stdout.strip() else ''
def owner(uid):
    return f"set role authenticated; select set_config('request.jwt.claim.sub','{uid}',false); "
def create(uid,plan='starter'):
    return json.loads(sql(owner(uid)+f"select public.create_coin_purchase('{plan}')"))
def attach(oid,request):
    sql(f"set role service_role; select public.attach_coin_checkout('{oid}','{request}','https://www.instamojo.com/@synthetic/{request}')")
def credit(oid,request,payment=default_payment,amount=4900,fails=False,role='service_role'):
    return sql(f"set role {role}; select public.credit_coin_purchase('{oid}','{request}','{payment}',{amount})",fails)
def uid():
    u=str(uuid.uuid4())
    sql(f"insert into auth.users(id) values('{u}'); select set_config('request.jwt.claim.sub','{u}',false); select public.initialize_wallet()")
    return u
u,v=uid(),uid()
initial=int(sql(f"select balance from public.wallets where id='{u}'"))
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results=list(pool.map(lambda _:create(u),range(16)))
assert sum(r['created'] for r in results)==1
assert len({r['order']['id'] for r in results})==1
order=results[0]['order']; oid=order['id']; request=request_a
assert (order['coins'],order['amount_paise'])==(100,4900)
assert sql(owner(v)+f"select count(*) from public.coin_purchase_orders where id='{oid}'")=='0'
sql(owner(u)+f"update public.coin_purchase_orders set coins=9999 where id='{oid}'",True)
sql(owner(u)+"insert into public.coin_purchase_plans values('fake',9999,900,'INR',true)",True)
credit(oid,request,role='authenticated',fails=True)
sql(f"set role authenticated; select public.attach_coin_checkout('{oid}','{request}','https://www.instamojo.com/x')",True)
credit(oid,request,fails=True)  # creating is not payable
attach(oid,request)
assert create(u)['order']['checkout_url'].startswith('https://www.instamojo.com/')
credit(oid,request_b,fails=True)
credit(oid,request,amount=1,fails=True)
assert int(sql(f"select balance from public.wallets where id='{u}'"))==initial
# Concurrent verification/retries must credit once with one ledger record.
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    assert all(x=='t' for x in pool.map(lambda _:credit(oid,request),range(16)))
assert int(sql(f"select balance from public.wallets where id='{u}'"))==initial+100
assert sql(f"select count(*) from public.coin_ledger where purchase_order_id='{oid}' and amount=100 and reason='purchase'")=='1'
credit(oid,request,payment='MOJOother',fails=True)
other=create(v)['order']['id']; attach(other,request_b)
start=int(sql(f"select balance from public.wallets where id='{v}'"))
credit(other,request_b,fails=True) # globally duplicate provider payment rolls back wallet & ledger
assert int(sql(f"select balance from public.wallets where id='{v}'"))==start
assert sql(f"select count(*) from public.coin_ledger where purchase_order_id='{other}'")=='0'
sql(f"insert into public.user_access(user_id,blocked) values('{v}',true)")
sql(owner(v)+"select public.create_coin_purchase('value')",True)
credit(other,request_b,payment='MOJO'+v.replace('-',''),fails=True)
assert sql(owner(v)+"select count(*) from public.coin_purchase_orders")=='0'
sql(f"update public.user_access set blocked=false where user_id='{v}'")
credit(other,request_b,payment='MOJO'+v.replace('-',''))
assert sql(f"select count(*) from public.notifications where user_id='{u}' and amount=100")=='1'
# Failed checkout may retry; plan snapshot survives later price edits.
new=create(u,'popular')['order']; sql(f"set role service_role; select public.fail_coin_checkout('{new['id']}')")
assert create(u,'popular')['created']
sql("update public.coin_purchase_plans set amount_paise=13900 where id='popular'")
assert create(u,'popular')['order']['amount_paise']==12900
sql("update public.coin_purchase_plans set amount_paise=12900 where id='popular'")
sql(owner(u)+"select public.create_coin_purchase('missing')",True)
print('PASS: 16 concurrent creates share one reservation; 16 credit retries grant exactly once; RLS, blocked access, privileges, snapshot pricing, amount/request mismatch and duplicate payment rollback verified')
