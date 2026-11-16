"""Local disposable DB only: full migrations via run_integration.py."""
import concurrent.futures
import json
import subprocess
import sys
import uuid

DB = sys.argv[1]
A, B, C = [str(uuid.uuid4()) for _ in range(3)]

def sql(query, user=None, fails=False):
    prefix = '' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    p = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix+query], capture_output=True, text=True)
    if fails:
        assert p.returncode != 0, query
    else:
        assert p.returncode == 0, p.stderr
    return (p.stdout.strip().splitlines() or [''])[-1]

for user in (A, B, C):
    sql(f"insert into auth.users(id) values('{user}'); insert into public.wallets(id,balance) values('{user}',100); insert into growth_internal.release_pins(user_id,pin_hash) values('{user}',growth_internal.pin_hash('1234'));")
wallets = {u: sql(f"select wallet_number from public.wallets where id='{u}'") for u in (A, B, C)}

def transfer(sender=A, recipient=B, amount=10, request=None, pin='1234', fails=False):
    result = sql(f"select public.transfer_wallet_coins('{wallets[recipient]}',{amount},'{pin}','{request or uuid.uuid4()}')", sender, fails)
    return None if fails else json.loads(result)

def balance(user):
    return int(sql(f"select balance from public.wallets where id='{user}'"))

# Invalid PINs commit their attempts and lockout, without moving any coins.
for _ in range(5):
    assert transfer(pin='0000')['status'] == 'invalid_pin'
assert transfer()['status'] == 'pin_locked'
assert balance(A) == balance(B) == 100
sql(f"update growth_internal.release_pins set failures=0,locked_until=null where user_id='{A}'")
request = str(uuid.uuid4())
receipt = transfer(request=request)
assert receipt['status'] == 'ok'
assert transfer(request=request) == receipt
assert balance(A) == 90 and balance(B) == 110
transfer(request=request, amount=11, fails=True)
transfer(recipient=A, fails=True)
transfer(amount=0, fails=True)
transfer(amount=-10, fails=True)
transfer(amount=1000, fails=True)
assert sql(f"select sum(amount)=0 and count(*)=2 from public.coin_ledger where transfer_id='{receipt['id']}'") == 't'
sql(f"set role anon; select public.transfer_wallet_coins('{wallets[B]}',1,'1234','{uuid.uuid4()}')", fails=True)
assert sql('select count(*) from public.wallet_transfers', C) == '0'
sql(f"insert into public.wallet_transfers(sender_id,recipient_id,request_id,amount) values('{A}','{B}','{uuid.uuid4()}',100)", A, fails=True)
# Simultaneous retries and simultaneous spends preserve conservation and reject overspending.
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(lambda _: transfer(request=request), range(8)))
assert all(r == receipt for r in results)
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    results = list(pool.map(lambda _: transfer(amount=10), range(8)))
assert balance(A) == 10 and balance(B) == 190
transfer(amount=11, fails=True)
# Opposing transfers must not deadlock; both wallets are locked in UUID order.
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    list(pool.map(lambda u: transfer(sender=u, recipient=B if u==A else A, amount=1), [A,B]))
assert balance(A) == 10 and balance(B) == 190
assert sql('select sum(balance) from public.wallets') == '300'
assert sql("select sum(amount) from public.coin_ledger where transfer_id is not null") == '0'
print('PASS: transfers conserve coins; PIN lockout, idempotent concurrent retries, ordered locks, validation and participant RLS verified')
sql(f"insert into public.user_access(user_id,blocked) values('{B}',true)")
transfer(fails=True)
sql(f"update public.user_access set blocked=false where user_id='{B}'")
sql(f"update public.user_access set blocked=true where user_id='{B}'")
transfer(sender=B, recipient=A, fails=True)
sql(f"update public.user_access set blocked=false where user_id='{B}'")
sql(f"update public.wallets set balance=2147483647 where id='{B}'")
transfer(amount=1, fails=True)
sql(f"update public.wallets set balance=190 where id='{B}'")
def overspend(_):
    try:
        transfer(amount=10)
        return True
    except AssertionError:
        return False
with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
    assert sum(pool.map(overspend, range(8))) == 1
assert balance(A)==0 and balance(B)==200
assert sql("select sum(amount) from public.coin_ledger where transfer_id is not null") == '0'
print('PASS: blocked accounts, recipient overflow and concurrent overspending rejected')
# Deletion must not block account removal or erase the sender's retry receipt.
sql(f"delete from auth.users where id='{B}'")
assert transfer(request=request) == receipt
assert sql(f"select recipient_id is null from public.wallet_transfers where id='{receipt['id']}'") == 't'
print('PASS: recipient deletion retains idempotency receipts without blocking account deletion')
