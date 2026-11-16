"""Local disposable DB only: profile account selection cannot impersonate another member."""
import subprocess
import sys
import uuid
DB = sys.argv[1]
A, B = [str(uuid.uuid4()) for _ in range(2)]
def sql(query, user=None, fails=False):
    prefix='' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
    p=subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query],capture_output=True,text=True)
    assert (p.returncode!=0) if fails else (p.returncode==0), p.stderr
    return (p.stdout.strip().splitlines() or [''])[-1]
for user, name in [(A,'my.account'),(B,'other.account')]:
    sql(f"insert into auth.users(id) values('{user}'); insert into public.wallets(id,balance) values('{user}',100); insert into public.instagram_accounts(user_id,username) values('{user}','{name}');")
sql("select public.create_campaign_for_account('follow','other.account',null,1,1)",A,True)
campaign=sql("select public.create_campaign_for_account('follow','my.account',null,2,1)",A)
assert sql(f"select link||':'||instagram_username from public.campaigns where id='{campaign}'")=='https://www.instagram.com/my.account/:my.account'
sql("select public.create_campaign_for_account('like','my.account','https://www.instagram.com/my.account/',1,1)",A,True)
sql("select public.create_campaign_for_account('like','my.account','https://www.instagram.com/p/Abc123/',1,1)",A)
sql("select public.create_campaign_for_account('follow','my.account',null,1,999)",A,True)
assert sql(f"select balance from public.wallets where id='{A}'")=='97'
print('PASS: own profile account required; follow target generated; post/rate validation and exact reservation preserved')
