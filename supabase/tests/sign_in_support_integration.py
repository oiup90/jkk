"""Guest support privacy and administrator workflow, in a disposable database."""
import json
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = 'd1000000-0000-4000-8000-000000000001'
VIEWER = 'd1000000-0000-4000-8000-000000000002'
USER = 'd1000000-0000-4000-8000-000000000003'
KEY = 'a' * 64
OTHER = 'b' * 64


def sql(query, role=None, uid=None, fails=False):
    prefix = f"set role {role}; " if role else ''
    if uid:
        prefix += f"select set_config('request.jwt.claim.sub','{uid}',false); select set_config('request.jwt.claims','{{}}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success: ' + query)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


class SignInSupport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql(f"insert into auth.users(id,email) values ('{ADMIN}','admin@example.test'),('{VIEWER}','viewer@example.test'),('{USER}','user@example.test'); insert into public.admin_members(user_id,role) values ('{ADMIN}','editor'),('{VIEWER}','viewer');")
        enroll_test_admins(DB)

    def test_guest_chat_and_access_control(self):
        sql(f"select public.guest_support_send('{KEY}','Need help',false)", 'anon')
        tid = sql("select id from growth_internal.support_tickets where user_id is null")
        self.assertEqual(json.loads(sql(f"select public.guest_support_get('{KEY}')", 'anon'))['messages'][0]['body'], 'Need help')
        self.assertEqual(sql(f"select public.guest_support_get('{OTHER}') is null", 'anon'), 't')
        sql(f"select public.guest_support_get('bad')", 'anon', fails=True)
        sql(f"select * from public.support_messages('{tid}')", 'authenticated', USER, fails=True)
        sql(f"select public.support_reply('{tid}','intrusion')", 'authenticated', USER, fails=True)
        sql(f"select public.support_reply('{tid}','no')", 'authenticated', VIEWER, fails=True)
        self.assertEqual(sql(f"select count(*) from public.admin_support_tickets() where id='{tid}'", 'authenticated', ADMIN), '1')
        notification_count = sql("select count(*) from public.notifications")
        sql(f"select public.support_reply('{tid}','We can help')", 'authenticated', ADMIN)
        self.assertEqual(len(json.loads(sql(f"select public.guest_support_get('{KEY}')", 'anon'))['messages']), 2)
        sql(f"select public.admin_close_ticket('{tid}')", 'authenticated', ADMIN)
        sql(f"select public.guest_support_send('{KEY}','again',false)", 'anon', fails=True)
        sql(f"select public.guest_support_send('{KEY}','new issue',true)", 'anon')
        self.assertEqual(json.loads(sql(f"select public.guest_support_get('{KEY}')", 'anon'))['messages'][0]['body'], 'new issue')
        self.assertEqual(sql("select count(*) from public.notifications"), notification_count)

    def test_rate_limits(self):
        sql(f"select public.guest_support_send('{OTHER}','start',false)", 'anon')
        for _ in range(19):
            sql(f"select public.guest_support_send('{OTHER}','reply',false)", 'anon')
        sql(f"select public.guest_support_send('{OTHER}','too fast',false)", 'anon', fails=True)
        sql("insert into growth_internal.support_tickets(user_id,guest_key_hash,subject) select null, md5(n::text), 'Synthetic' from generate_series(1,60) n")
        sql(f"select public.guest_support_send('{'c' * 64}','new',false)", 'anon', fails=True)

if __name__ == '__main__': unittest.main(verbosity=2)
