"""Validate Free Plan enforcement in an isolated database."""
import concurrent.futures
import json
import subprocess
import sys
import uuid

DB = sys.argv[1]
OWNER, REFERRED, OTHER = [str(uuid.uuid4()) for _ in range(3)]


def sql(query, user=None, error=None):
    prefix = '' if user is None else f"set role authenticated; set request.jwt.claim.sub='{user}'; "
    result = subprocess.run(
        ['psql', '-XqAt', '-v', 'ON_ERROR_STOP=1', '-v', 'VERBOSITY=verbose', '-d', DB, '-c', prefix+query],
        capture_output=True, text=True,
    )
    if error:
        assert result.returncode != 0 and error in result.stderr, result.stderr
    else:
        assert result.returncode == 0, result.stderr
    return result.stdout.strip()


sql(f"""insert into auth.users(id) values('{OWNER}'),('{REFERRED}'),('{OTHER}');
insert into public.wallets(id,balance) values('{OWNER}',100),('{REFERRED}',100),('{OTHER}',100);
insert into public.instagram_accounts(user_id,username) values('{OWNER}','owner.account');""")
plan = lambda user: json.loads(sql('select public.campaign_plan_limits()', user))
legacy = lambda n: f"select public.create_campaign('like','https://instagram.com/p/ONE/',{n})"
priced = lambda n: f"select public.create_campaign_at_rate('like','https://instagram.com/p/ONE/',{n},1)"
account = lambda n: f"select public.create_campaign_for_account('like','owner.account','https://instagram.com/p/ONE/',{n},1)"

assert plan(OWNER)['max_tasks'] == 3 and plan(OWNER)['next_campaign_at'] is None
sql('set role anon; select public.campaign_plan_limits()', error='42501')
for create in (legacy, priced, account):
    sql(create(4), OWNER, error='P0C02')
assert sql(f"select balance from public.wallets where id='{OWNER}'") == '100'
first = sql(account(3), OWNER)
assert plan(OWNER)['next_campaign_at'] is not None
sql(f"select public.cancel_campaign('{first}')", OWNER)
sql(legacy(1), OWNER, error='P0C01')
sql(f"""update public.campaigns set "createdAt"=clock_timestamp()-interval '23 hours 59 minutes' where id='{first}'""")
sql(priced(1), OWNER, error='P0C01')
sql(f"""update public.campaigns set "createdAt"=clock_timestamp()-interval '24 hours' where id='{first}'""")
code = json.loads(sql('select public.referral_info()', OWNER))['code']
sql(f"select public.apply_referral('{code}')", REFERRED)
assert plan(OWNER)['max_tasks'] == 8
assert plan(REFERRED)['max_tasks'] == 3
sql(f"select public.apply_referral('{code}')", OTHER)
assert plan(OWNER)['max_tasks'] == 8
sql(priced(9), OWNER, error='P0C02')
assert sql(account(8), OWNER)
sql(legacy(1), OWNER, error='P0C01')

def try_create(_):
    try:
        sql(legacy(3), REFERRED)
        return True
    except AssertionError as exc:
        assert 'P0C01' in str(exc), exc
        return False

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    assert sum(pool.map(try_create, range(4))) == 1
assert sql(f"select balance from public.wallets where id='{REFERRED}'") == '97'
print('PASS: Free Plan task limits, referral unlock, 24-hour window, cancellation, concurrency and wallet integrity')
