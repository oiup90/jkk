"""Payment lookup and receipts against the disposable full-schema test database."""
import concurrent.futures
import json
import subprocess
import sys
import time
import uuid

DB = sys.argv[1]
A, B, C = [str(uuid.uuid4()) for _ in range(3)]


def sql(query, user=None, fails=False):
    prefix = '' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    proc = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix + query], capture_output=True, text=True)
    if fails:
        assert proc.returncode != 0, query
    else:
        assert proc.returncode == 0, proc.stderr
    return (proc.stdout.strip().splitlines() or [''])[-1]


for uid, name in ((A, 'Alice'), (B, 'Bob'), (C, 'Charlie')):
    sql(f"insert into auth.users(id,raw_user_meta_data) values('{uid}',jsonb_build_object('full_name','{name}')); insert into public.wallets(id,balance) values('{uid}',100); insert into growth_internal.release_pins(user_id,pin_hash) values('{uid}',growth_internal.pin_hash('1234'))")
wallet = {u: sql(f"select wallet_number from public.wallets where id='{u}'") for u in (A, B, C)}
public_id = {u: sql(f"select public_id from growth_internal.user_identifiers where user_id='{u}'") for u in (A, B, C)}


def pay(sender=A, recipient=B, amount=10, request=None, pin='1234', fails=False, expected_id=None):
    expected_id = expected_id or public_id[recipient]
    response = sql(f"select public.pay_wallet_coins('{wallet[recipient]}',{amount},'{pin}','{request or uuid.uuid4()}','{expected_id}')", sender, fails)
    return None if fails else json.loads(response)


def lookup(number, user=A):
    return json.loads(sql(f"select public.lookup_wallet_recipient('{number}')", user))


def balance(uid):
    return int(sql(f"select balance from public.wallets where id='{uid}'"))


assert lookup(wallet[B]) == {'status': 'found', 'name': 'Bob', 'recipient_id': public_id[B]}
missing = '1000000000'
if missing in wallet.values(): missing = '1000000001'
assert lookup(missing)['status'] == 'not_found'
sql(f"set role anon; select public.lookup_wallet_recipient('{wallet[B]}')", fails=True)
sql(f"set role anon; select public.pay_wallet_coins('{wallet[B]}',1,'1234','{uuid.uuid4()}')", fails=True)
sql('select * from growth_internal.wallet_payment_results', A, fails=True)
request = str(uuid.uuid4())
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    results = list(pool.map(lambda _: pay(request=request), range(6)))
receipt = results[0]
assert all(item == receipt for item in results)
assert receipt['status'] == 'success' and receipt['name'] == 'Bob' and receipt['wallet'] == wallet[B]
assert len(receipt['reference']) == 12 and receipt['reference'].isdigit() and receipt['created_at']
assert balance(A) == 90 and balance(B) == 110
pay(request=request, amount=11, fails=True)
assert sql(f"select count(*)=2 and sum(amount)=0 from public.coin_ledger where transfer_id=(select transfer_id from growth_internal.wallet_payment_results where request_id='{request}')") == 't'
assert sql(f"select count(*)=2 and bool_and(l.reference_id=r.reference_id) from public.coin_ledger l join growth_internal.wallet_payment_results r on r.transfer_id=l.transfer_id where r.request_id='{request}'") == 't'
invalid = pay(pin='0000')
assert invalid['status'] == 'failure' and invalid['failure_code'] == 'invalid_pin'
assert sql(f"select failures from growth_internal.release_pins where user_id='{A}'") == '1'
sql(f"insert into public.user_access(user_id,blocked) values('{B}',true)")
assert lookup(wallet[B])['name'] == 'Bob'
blocked_request = str(uuid.uuid4())
blocked = pay(request=blocked_request)
assert blocked['status'] == 'failure' and blocked['failure_code'] == 'recipient_unavailable' and blocked['name'] == 'Bob'
assert pay(request=blocked_request) == blocked
assert balance(A) == 90 and balance(B) == 110
assert len({receipt['reference'], invalid['reference'], blocked['reference']}) == 3
sql(f"update public.user_access set blocked=false where user_id='{B}'")
sql(f"select public.transfer_wallet_coins('{wallet[B]}',10,'1234','{blocked_request}')", A, fails=True)
assert balance(A) == 90 and balance(B) == 110
changed = pay(expected_id=public_id[C])
assert changed['status'] == 'failure' and changed['failure_code'] == 'recipient_changed'
assert balance(A) == 90 and balance(B) == 110
insufficient = pay(amount=1000)
assert insufficient['status'] == 'failure' and insufficient['failure_code'] == 'insufficient_balance'
assert len(insufficient['reference']) == 12
# A pre-upgrade committed transfer can be recovered using its existing request ID.
legacy_request = str(uuid.uuid4())
legacy = json.loads(sql(f"select public.transfer_wallet_coins('{wallet[B]}',1,'1234','{legacy_request}')", A))
recovered = pay(request=legacy_request, amount=1)
assert recovered['status'] == 'success' and balance(A) == 89 and balance(B) == 111
assert sql(f"select transfer_id='{legacy['id']}'::uuid from growth_internal.wallet_payment_results where request_id='{legacy_request}'") == 't'
assert len({receipt['reference'], invalid['reference'], blocked['reference'], insufficient['reference'], recovered['reference']}) == 5
# A block holding the recipient lock commits before a waiting payment checks status.
block = subprocess.Popen(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
    f"begin; select pg_advisory_xact_lock(hashtextextended('{B}',314159)); update public.user_access set blocked=true where user_id='{B}'; select pg_sleep(1.5); commit"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
try:
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        if sql(f"select pg_try_advisory_lock(hashtextextended('{B}',314159))") == 'f': break
        time.sleep(.05)
    else: raise AssertionError('Block did not acquire recipient lock')
    waiting = pay(amount=1)
    _, err = block.communicate(timeout=5)
    assert block.returncode == 0, err
    assert waiting['status'] == 'failure' and waiting['failure_code'] == 'recipient_unavailable'
    assert balance(A) == 89 and balance(B) == 111
finally:
    if block.poll() is None: block.kill(); block.communicate()
    sql(f"update public.user_access set blocked=false where user_id='{B}'")
# Opposite-direction payments acquire account and wallet locks in the same order.
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    opposite = list(pool.map(lambda pair: pay(sender=pair[0], recipient=pair[1], amount=1), [(A, B), (B, A)]))
assert all(item['status'] == 'success' for item in opposite)
assert opposite[0]['reference'] != opposite[1]['reference']
assert balance(A) == 89 and balance(B) == 111
# Only the active caller can look up names; other users cannot read receipt records.
sql(f"insert into public.user_access(user_id,blocked) values('{C}',true)")
sql(f"select public.lookup_wallet_recipient('{wallet[B]}')", C, fails=True)
sql(f"select public.pay_wallet_coins('{wallet[B]}',1,'1234','{uuid.uuid4()}')", C, fails=True)
for _ in range(17): lookup(wallet[B])
assert lookup(wallet[B])['status'] == 'rate_limited'
print('PASS: exact lookup permissions, quota, unique success/failure references, blocked recipient, PIN, idempotency, ledger and legacy recovery')
