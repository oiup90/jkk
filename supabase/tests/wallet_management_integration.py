"""Synthetic, disposable PostgreSQL only; run with the repository test runner."""
import concurrent.futures
import json
import subprocess
import sys
import uuid
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
E, V, A, B = [str(uuid.uuid4()) for _ in range(4)]

def sql(q, user=None, fails=False):
    prefix = '' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false);"
    p = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix)+q], capture_output=True, text=True)
    if fails:
        assert p.returncode, q
    else:
        assert p.returncode == 0, p.stderr
    return (p.stdout.strip().splitlines() or [''])[-1]

sql(f"insert into auth.users(id,raw_user_meta_data) values ('{E}','{{}}'),('{V}','{{}}'),('{A}','{{\"full_name\":\"Alice Wallet\"}}'),('{B}','{{\"full_name\":\"Bob Wallet\"}}'); insert into public.admin_members(user_id,role) values('{E}','editor'),('{V}','viewer');")
enroll_test_admins(DB)
for user in (A, B):
    sql(f"insert into public.wallets(id,balance) values('{user}',100); insert into growth_internal.release_pins(user_id,pin_hash) values('{user}',growth_internal.pin_hash('1234'))")
    sql("select public.register_push_token('synthetic-wallet-device-"+user+"')", user)
wallet = {u: sql(f"select wallet_number from public.wallets where id='{u}'") for u in (A, B)}
public_id = {u: sql(f"select public_id from growth_internal.user_identifiers where user_id='{u}'") for u in (A, B)}

def op(action, amount=0, source=A, recipient=None, request=None, actor=E, fails=False):
    target = 'null,null' if recipient is None else f"'{wallet[recipient]}','{recipient}'"
    value = sql(f"select public.admin_wallet_operate('{request or uuid.uuid4()}','{source}','{action}',{amount},'Synthetic test',{target})", actor, fails)
    return None if fails else json.loads(value)

def balance(u=A):
    return int(sql(f"select balance from public.wallets where id='{u}'"))

def payment(amount, request=None):
    return json.loads(sql(f"select public.pay_wallet_coins('{wallet[B]}',{amount},'1234','{request or uuid.uuid4()}','{public_id[B]}')", A))

# Search is server-side and paginated, covering all three requested identities.
for query in ('alice wallet', wallet[A], public_id[A]):
    assert sql(f"select user_id from public.admin_wallets('{query}')", V) == A
sql("select * from public.admin_wallets()", A, fails=True)
sql("set role anon; select * from public.admin_wallets()", fails=True)
sql("select * from public.admin_wallets('',-1)", E, fails=True)
for action in ('add','deduct','debit','hold','release','transfer','activate','deactivate'):
    op(action, amount=1, recipient=B if action=='transfer' else None, actor=V, fails=True)
    op(action, amount=1, recipient=B if action=='transfer' else None, actor=A, fails=True)
# Direct writes to wallets and private operation receipts remain denied.
sql(f"update public.wallets set is_active=false where id='{A}'", A, fails=True)
sql(f"update public.wallets set held_balance=0 where id='{A}'", E, fails=True)
sql('select * from growth_internal.wallet_operations', E, fails=True)
sql('select * from public.claim_push_jobs_v3()', E, fails=True)
# A single editor credits immediately, no other editor or pending approval.
request = str(uuid.uuid4())
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
    results = list(pool.map(lambda _: op('add', 20, request=request), range(6)))
assert all(x == results[0] for x in results) and balance() == 120
assert sql(f"select count(*) from public.coin_ledger where user_id='{A}'") == '1'
op('add', 21, request=request, fails=True)
op('deduct', 5); op('debit', 5)
assert balance() == 110
op('deduct', 111, fails=True)
op('add', 0, fails=True); op('hold', -1, fails=True)
sql(f"insert into public.instagram_accounts(user_id,username) values('{A}','alice.wallet')")
# Holds reserve availability across every consumer, including older clients.
op('hold', 100)
assert balance() == 110
assert sql(f"select available_balance from public.admin_wallets('{wallet[A]}')", E) == '10'
op('deduct', 11, fails=True)
op('transfer', 11, recipient=B, fails=True)
sql("select public.create_campaign_for_account('like','alice.wallet','https://instagram.com/p/TEST/',11,1)", A, fails=True)
failed = payment(11)
assert failed['status'] == 'failure' and failed['failure_code'] == 'insufficient_balance'
op('release', 20)
assert payment(11)['status'] == 'success'
op('release', 81, fails=True)
op('release', 80)
# Deactivation blocks spending (including old RPCs) but never destroys earnings.
op('deactivate')
blocked = payment(1)
assert blocked['status'] == 'failure' and blocked['failure_code'] == 'wallet_inactive'
sql(f"select public.transfer_wallet_coins('{wallet[B]}',1,'1234','{uuid.uuid4()}')", A, fails=True)
sql("select public.create_campaign_for_account('like','alice.wallet','https://instagram.com/p/TEST/',1,1)", A, fails=True)
op('debit', 1, fails=True)
before = balance(); op('add', 2); assert balance() == before+2
op('activate')
# Transfers conserve totals, yield balanced ledger entries and retry exactly once.
before = balance()+balance(B); request = str(uuid.uuid4())
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    receipts = list(pool.map(lambda _: op('transfer', 3, recipient=B, request=request), range(4)))
assert all(r == receipts[0] for r in receipts)
assert balance()+balance(B) == before
ref = receipts[0]['reference']
assert sql(f"select count(*)=2 and sum(amount)=0 from public.coin_ledger where reference_id='{ref}'") == 't'
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
    list(pool.map(lambda u: op('transfer', 1, source=u, recipient=B if u==A else A), (A,B)))
op('transfer', 1, recipient=A, fails=True)
# Referral/welcome/purchase/task/refund credits use the same transactional trigger.
for reason in ('welcome','referral','purchase','task','refund'):
    sql(f"begin; update public.wallets set balance=balance+1 where id='{A}'; insert into public.coin_ledger(user_id,amount,reason) values('{A}',1,'{reason}'); commit;")
assert sql("select count(*) from public.notifications where kind='coins_received'") == sql('select count(*) from public.coin_ledger where amount>0')
assert sql("select count(*) from growth_internal.push_jobs") == sql("select count(*) from public.notifications where kind='coins_received'")
assert sql("select count(*) from public.notifications where kind='coins_received' and credit_source is null") == '0'
# Rollback must not leave receipt/notification/push artifacts.
counts = sql('select (select count(*) from growth_internal.push_jobs)||\':\'||(select count(*) from public.coin_ledger)')
sql(f"begin; update public.wallets set balance=balance+1 where id='{A}'; insert into public.coin_ledger(user_id,amount,reason) values('{A}',1,'referral'); rollback;")
assert sql('select (select count(*) from growth_internal.push_jobs)||\':\'||(select count(*) from public.coin_ledger)') == counts
jobs = json.loads(sql('select jsonb_agg(j) from public.claim_push_jobs_v3(100) j'))
assert all(j['amount'] > 0 and j['source'] for j in jobs)
assert any(j['source']=='referral' for j in jobs) and any(j['source']=='transfer_received' for j in jobs)
# Operation history and audit are admin-only, including recipient history.
assert int(sql(f"select count(*) from public.admin_wallet_history('{A}')", V)) > 0
assert int(sql(f"select count(*) from public.admin_wallet_history('{B}') where action='transfer_received'", E)) > 0
sql(f"select * from public.admin_wallet_history('{A}')", A, fails=True)
assert sql('select count(*) from growth_internal.wallet_operations') == sql("select count(*) from growth_internal.admin_operations_audit where action like 'Wallet %'")
# Overflows, concurrent holds/spends, and malformed parameters must be atomic.
sql(f"update public.wallets set balance=2147483647 where id='{B}'")
op('add', 1, source=B, fails=True); op('transfer', 1, recipient=B, fails=True)
remaining = balance()
def hold_once(_):
    try: op('hold', remaining); return True
    except AssertionError: return False
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    assert sum(pool.map(hold_once, range(4))) == 1
op('debit', 1, fails=True)
print('PASS: direct editor operations, wallet search, hold/deactivation enforcement, audit/RLS, idempotent concurrent retries, balanced transfers and receipt push queue')
