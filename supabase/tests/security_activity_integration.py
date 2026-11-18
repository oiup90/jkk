"""Exercise password audit and alerts in an isolated database."""
from admin_test_support import enroll_test_admins
import json
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = '75000000-0000-4000-8000-000000000001'
USER = '75000000-0000-4000-8000-000000000002'
OTHER = '75000000-0000-4000-8000-000000000003'


def sql(query, role=None, uid=None, aal='aal2', fails=False):
    prefix = f'set role {role}; ' if role else ''
    if uid:
        prefix += f"select set_config('request.jwt.claim.sub','{uid}',false); select set_config('request.jwt.claims','{{\"aal\":\"{aal}\"}}',false); "
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix + query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('unexpected success: ' + query)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


def attempt(user, valid):
    event = json.dumps({'user_id': user, 'valid': valid})
    return json.loads(sql(f"select public.hook_password_login_throttle('{event}'::jsonb)", 'supabase_auth_admin'))


class SecurityActivity(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql(f"insert into auth.users(id,email) values ('{ADMIN}','admin@example.test'),('{USER}','user@example.test'),('{OTHER}','other@example.test'); insert into public.admin_members(user_id) values ('{ADMIN}')")
        enroll_test_admins(DB)

    def setUp(self):
        sql('delete from growth_internal.security_password_events; delete from growth_internal.password_login_limits')

    def test_events_alerts_and_throttle(self):
        self.assertEqual(attempt(OTHER, True)['decision'], 'continue')
        for _ in range(5):
            self.assertEqual(attempt(USER, False)['decision'], 'continue')
        self.assertEqual(attempt(USER, True)['decision'], 'reject')
        self.assertEqual(sql("select string_agg(event_type, ',' order by id) from growth_internal.security_password_events"), 'password_verified,password_invalid,password_invalid,password_invalid,password_invalid,password_invalid,password_throttled')
        self.assertEqual(sql("select activity from public.admin_alerts() where kind='password_failures'", 'authenticated', ADMIN), '5')
        self.assertEqual(sql("select count(*) from public.admin_security_activity()", 'authenticated', ADMIN), '7')
        sql("update growth_internal.security_password_events set occurred_at=now()-interval '16 minutes' where event_type='password_invalid'")
        self.assertEqual(sql("select count(*) from public.admin_alerts() where kind='password_failures'", 'authenticated', ADMIN), '0')

    def test_permissions_and_retention(self):
        attempt(USER, False)
        for role in ('anon', 'authenticated', 'service_role'):
            sql('select * from growth_internal.security_password_events', role, fails=True)
            sql("select public.password_login_throttle_impl('{}')", role, fails=True)
            sql('select growth_internal.prune_security_password_events()', role, fails=True)
        sql("select public.password_login_throttle_impl('{}')", 'supabase_auth_admin', fails=True)
        sql('select * from public.admin_security_activity()', 'anon', fails=True)
        sql('select * from public.admin_security_activity()', 'authenticated', USER, fails=True)
        sql('select * from public.admin_security_activity()', 'authenticated', ADMIN, aal='aal1', fails=True)
        sql('select * from public.admin_security_activity(0,101)', 'authenticated', ADMIN, fails=True)
        sql("update growth_internal.security_password_events set occurred_at=now()-interval '91 days'")
        attempt(OTHER, False)
        self.assertEqual(sql('select growth_internal.prune_security_password_events()'), '1')
        self.assertEqual(sql('select count(*) from growth_internal.security_password_events'), '1')
        sql(f"delete from auth.users where id='{OTHER}'")
        self.assertEqual(sql('select count(*) from growth_internal.security_password_events where user_id is null'), '1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
