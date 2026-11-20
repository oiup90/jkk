"""Repair exposed hook permissions in a disposable database with synthetic users."""
import json
from pathlib import Path
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ROOT = Path(__file__).resolve().parents[2]
MIGRATION = ROOT / 'supabase/migrations/20261120033341_restore_password_hook_permissions.sql'
USER = '62000000-0000-4000-8000-000000000001'


def sql(query, role=None, succeeds=True):
    result = subprocess.run(
        ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
         (f'set role {role}; ' if role else '') + query],
        text=True, capture_output=True,
    )
    if succeeds and result.returncode:
        raise AssertionError(result.stderr)
    if not succeeds and (result.returncode == 0 or 'permission denied for function hook_password_login_throttle' not in result.stderr):
        raise AssertionError('Expected a permission-denied error: ' + result.stderr)
    return result.stdout.strip()


def attempt(valid, role='supabase_auth_admin', succeeds=True):
    event = json.dumps({'user_id': USER, 'valid': valid})
    result = sql(f"select public.hook_password_login_throttle('{event}'::jsonb)", role, succeeds)
    return json.loads(result) if succeeds else None


class PasswordHookPermissions(unittest.TestCase):
    def test_repair_revokes_exposure_preserving_auth_and_lockouts(self):
        sql(f"insert into auth.users(id) values ('{USER}')")
        # Reproduce the observed hosted ACL, including Auth access via PUBLIC.
        sql('revoke execute on function public.hook_password_login_throttle(jsonb) from supabase_auth_admin; '
            'grant execute on function public.hook_password_login_throttle(jsonb) to public, anon, authenticated')
        self.assertEqual(sql("select has_function_privilege('anon', 'public.hook_password_login_throttle(jsonb)', 'EXECUTE')"), 't')
        self.assertEqual(attempt(False)['decision'], 'continue')
        for _ in range(2):
            subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-f', str(MIGRATION)], check=True, capture_output=True)
        self.assertEqual(sql(f"select failures from growth_internal.password_login_limits where user_id='{USER}'"), '1')
        before = sql('select count(*) from growth_internal.security_password_events')
        for role in ('anon', 'authenticated', 'service_role'):
            self.assertEqual(sql(f"select has_function_privilege('{role}', 'public.hook_password_login_throttle(jsonb)', 'EXECUTE')"), 'f')
            attempt(False, role=role, succeeds=False)
        self.assertEqual(sql('select count(*) from growth_internal.security_password_events'), before)
        for _ in range(4):
            self.assertEqual(attempt(False)['decision'], 'continue')
        self.assertEqual(attempt(True)['decision'], 'reject')
        self.assertEqual(sql(f"select failures from growth_internal.password_login_limits where user_id='{USER}'"), '5')


if __name__ == '__main__':
    unittest.main(verbosity=2)
