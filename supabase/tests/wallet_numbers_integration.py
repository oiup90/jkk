"""Only run against an isolated DB: bootstrap, base wallet schema, wallet-number migration."""
import concurrent.futures
import json
import subprocess
import sys
import uuid

DB = sys.argv[1]

def sql(query, fails=False):
    p = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', query], capture_output=True, text=True)
    if fails:
        assert p.returncode != 0, 'Expected database rejection'
    else:
        assert p.returncode == 0, p.stderr
    return p.stdout.strip()

def new_wallet(_=None):
    uid = str(uuid.uuid4())
    return sql(f"insert into auth.users(id) values ('{uid}'); select set_config('request.jwt.claim.sub','{uid}',false); select public.initialize_wallet(); select wallet_number from public.wallets where id='{uid}';").splitlines()[-1]

before = json.loads(sql("select json_agg(json_build_object('id',id,'balance',balance,'number',wallet_number)) from public.wallets")) or []
with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
    numbers = list(pool.map(new_wallet, range(120)))
assert len(numbers) == len(set(numbers))
assert all(len(n) == 10 and n.isdecimal() and n[0] != '0' for n in numbers)
assert sql('select count(*)=count(distinct wallet_number) and bool_and(wallet_number ~ \'^[1-9][0-9]{9}$\') from public.wallets') == 't'
for row in before:
    uid = row['id']
    assert sql(f"select balance={row['balance']} and wallet_number='{row['number']}' from public.wallets where id='{uid}'") == 't'
    sql(f"update public.wallets set wallet_number='9999999999' where id='{uid}'", fails=True)
    sql(f"set role authenticated; select set_config('request.jwt.claim.sub','{uid}',false); update public.wallets set balance=999999 where id='{uid}'", fails=True)
    assert sql(f"set role authenticated; select set_config('request.jwt.claim.sub','{uid}',false); select count(*) from public.wallets").splitlines()[-1] == '1'
    sql(f"select set_config('request.jwt.claim.sub','{uid}',false); select public.initialize_wallet();")
    assert sql(f"select wallet_number='{row['number']}' from public.wallets where id='{uid}'") == 't'
# Force one random collision deterministically, then verify retry chooses a new number.
# Test-only crypto replacement is restored; never run against a connected project.
sql('alter function extensions.gen_random_bytes(integer) rename to wallet_original_random_bytes; create sequence extensions.wallet_test_draw;')
try:
    existing = sql("select wallet_number from public.wallets limit 1")
    sample = int(existing) - 1000000000
    sql(f"create function extensions.gen_random_bytes(integer) returns bytea language sql as $$ select case when nextval('extensions.wallet_test_draw')=1 then decode('{sample:010x}','hex') else extensions.wallet_original_random_bytes($1) end $$;")
    assert new_wallet() != existing
    assert int(sql('select last_value from extensions.wallet_test_draw')) >= 2
finally:
    sql('drop function if exists extensions.gen_random_bytes(integer); alter function extensions.wallet_original_random_bytes(integer) rename to gen_random_bytes; drop sequence extensions.wallet_test_draw;')
# The unique constraint still rejects duplicates even with triggers disabled.
uid = str(uuid.uuid4())
sql(f"insert into auth.users(id) values ('{uid}')")
sql(f"set session_replication_role=replica; insert into public.wallets(id,balance,wallet_number) values ('{uid}',0,'{numbers[0]}')", fails=True)
print('PASS: backfilled identifiers preserved; 120 concurrent allocations unique; collision retry, immutability, unique constraint, owner RLS and coin write denial verified')
