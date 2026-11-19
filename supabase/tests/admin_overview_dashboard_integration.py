"""Overview aggregates and permissions against a disposable database."""
import json
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR, VIEWER, USER, OTHER = [f'98000000-0000-4000-8000-{i:012d}' for i in range(1, 5)]
ACTIVE = '98100000-0000-4000-8000-000000000001'
CLOSED = '98100000-0000-4000-8000-000000000002'

def sql(query, user=None, claims=None, fails=False):
    prefix = '' if not user else (f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
        f"select set_config('request.jwt.claims','{json.dumps(claims or {})}',false); ")
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success')
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class OverviewDashboard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id,email) values ' + ','.join(f"('{u}','user{i}@example.test')" for i,u in enumerate((EDITOR, VIEWER, USER, OTHER))))
        sql(f"insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer')")
        enroll_test_admins(DB)
        sql(f'''update auth.users set created_at=(date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') - interval '1 second' where id='{OTHER}';
          insert into public.campaigns(id,"ownerId",type,link,requested,remaining,status) values
          ('{ACTIVE}','{USER}','like','https://instagram.com/p/ABC/',4,4,'active'),
          ('{CLOSED}','{USER}','like','https://instagram.com/p/DEF/',4,4,'cancelled');
          update public.campaigns set "createdAt"=(date_trunc('day',now() at time zone 'UTC') at time zone 'UTC') - interval '1 second' where id='{CLOSED}';
          insert into public.campaign_claims(campaign_id,user_id,status,created_at,reviewed_at) values
          ('{ACTIVE}','{EDITOR}','pending',now()-interval '3 hours',null),
          ('{ACTIVE}','{VIEWER}','approved',now()-interval '1 day',now()),
          ('{CLOSED}','{EDITOR}','pending',now()-interval '5 hours',null);
          insert into growth_internal.support_tickets(user_id,subject,status) values ('{USER}','Open','open'),('{USER}','Closed','closed');
          insert into public.coin_ledger(user_id,amount,reason) values ('{USER}',25,'welcome'),('{USER}',-5,'campaign');''')

    def test_counts_and_existing_contract(self):
        result = json.loads(sql('select public.admin_workspace_overview()', VIEWER))
        self.assertEqual((result['users'], result['active_campaigns'], result['pending_submissions'], result['coins_credited']), (4, 1, 1, 25))
        self.assertEqual((result['open_support_chats'], result['today_users'], result['today_campaigns'], result['today_approved']), (1, 1, 1, 1))
        self.assertIsNotNone(result['oldest_pending_at'])
        hours = float(sql("select extract(epoch from (now()-(public.admin_workspace_overview()->>'oldest_pending_at')::timestamptz))/3600", VIEWER))
        self.assertGreaterEqual(hours, 2.99)
        self.assertLess(hours, 4)
        today = json.loads(sql("select row_to_json(r) from public.admin_daily_report((now() at time zone 'UTC')::date,(now() at time zone 'UTC')::date) r", VIEWER))
        self.assertEqual((today['registrations'], today['campaigns'], today['coins_credited'], today['coins_spent']), (3, 1, 25, 5))

    def test_restricted_and_empty_queue(self):
        sql('select public.admin_workspace_overview()', USER, fails=True)
        sql('select public.admin_workspace_overview()', EDITOR, {'aal':'aal1'}, fails=True)
        sql(f"update public.campaign_claims set status='withdrawn' where campaign_id='{ACTIVE}' and user_id='{EDITOR}'")
        result = json.loads(sql('select public.admin_workspace_overview()', EDITOR))
        self.assertEqual(result['pending_submissions'], 0)
        self.assertIsNone(result['oldest_pending_at'])

if __name__ == '__main__':
    unittest.main()
