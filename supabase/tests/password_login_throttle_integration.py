"""Password hook behavior in an isolated database; does not simulate Supabase Auth."""
import concurrent.futures
import json
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
USER = '50000000-0000-4000-8000-000000000101'
OTHER = '50000000-0000-4000-8000-000000000102'


def sql(query, role=None, fails=False):
    result = subprocess.run(
        ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
         (f'set role {role}; ' if role else '') + query],
        capture_output=True, text=True,
    )
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success: ' + query)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return result.stdout.strip().splitlines()[-1] if result.stdout.strip() else ''


def attempt(user, valid):
    event = json.dumps({'user_id': user, 'valid': valid})
    return json.loads(sql(f"select public.hook_password_login_throttle('{event}'::jsonb)", 'supabase_auth_admin'))


class PasswordLoginThrottle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql(f"insert into auth.users(id) values ('{USER}'), ('{OTHER}')")

    def setUp(self):
        sql('delete from growth_internal.password_login_limits')

    def test_limit_expiry_and_user_isolation(self):
        for _ in range(5):
            self.assertEqual(attempt(USER, False)['decision'], 'continue')
        blocked = attempt(USER, True)
        self.assertEqual(blocked, {'decision': 'reject', 'message': 'Invalid login credentials', 'should_logout_user': False})
        self.assertEqual(attempt(USER, False)['decision'], 'reject')
        self.assertEqual(attempt(OTHER, True)['decision'], 'continue')
        sql(f"update growth_internal.password_login_limits set locked_until=clock_timestamp()-interval '1 second' where user_id='{USER}'")
        self.assertEqual(attempt(USER, False)['decision'], 'continue')
        self.assertEqual(sql(f"select failures from growth_internal.password_login_limits where user_id='{USER}'"), '1')
        self.assertEqual(attempt(USER, True)['decision'], 'continue')
        self.assertEqual(sql('select count(*) from growth_internal.password_login_limits'), '0')

    def test_success_and_expired_window_reset_failures(self):
        for _ in range(4):
            attempt(USER, False)
        self.assertEqual(attempt(USER, True)['decision'], 'continue')
        for _ in range(4):
            self.assertEqual(attempt(USER, False)['decision'], 'continue')
        sql(f"update growth_internal.password_login_limits set window_started_at=clock_timestamp()-interval '16 minutes' where user_id='{USER}'")
        attempt(USER, False)
        self.assertEqual(sql(f"select failures from growth_internal.password_login_limits where user_id='{USER}'"), '1')
        self.assertEqual(attempt(USER, True)['decision'], 'continue')

    def test_concurrent_attempts_and_access_control(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=10) as pool:
            responses = list(pool.map(lambda _: attempt(USER, False), range(10)))
        self.assertEqual(sum(r['decision'] == 'continue' for r in responses), 5)
        self.assertEqual(sum(r['decision'] == 'reject' for r in responses), 5)
        for role in ('anon', 'authenticated', 'service_role'):
            sql("select public.hook_password_login_throttle('{}')", role, fails=True)
            sql('select * from growth_internal.password_login_limits', role, fails=True)
        sql("select public.hook_password_login_throttle('{}')", 'supabase_auth_admin', fails=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
