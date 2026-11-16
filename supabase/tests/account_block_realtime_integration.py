"""Run only on a disposable DB with bootstrap and all migrations applied."""
import subprocess
import sys
import unittest

from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
ADMIN = '81000000-0000-4000-8000-000000000001'
USER = '81000000-0000-4000-8000-000000000002'
OTHER = '81000000-0000-4000-8000-000000000003'


def sql(query, user=None, role='authenticated', fails=False):
    prefix = f'set role {role}; '
    if user:
        prefix += f"select set_config('request.jwt.claim.sub','{user}',false); "
    result = subprocess.run(
        ['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query],
        capture_output=True, text=True,
    )
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success: ' + query)
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


class BlockRealtimeTests(unittest.TestCase):
    def test_admin_block_projection_and_isolation(self):
        values = ','.join(f"('{uid}')" for uid in (ADMIN, USER, OTHER))
        subprocess.run(['psql', '-X', '-q', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
                        f"insert into auth.users(id) values {values}; insert into public.admin_members(user_id) values ('{ADMIN}')"], check=True)
        enroll_test_admins(DB)
        sql('select public.initialize_wallet()', USER)
        sql('select public.initialize_wallet()', OTHER)
        self.assertEqual(sql('select count(*) from public.account_block_status', USER), '0')
        sql(f"select public.admin_set_blocked('{USER}',true)", ADMIN)
        self.assertEqual(sql('select blocked from public.account_block_status', USER), 't')
        self.assertEqual(sql('select count(*) from public.account_block_status', OTHER), '0')
        self.assertEqual(sql('select public.account_access_allowed()', USER), 'f')
        self.assertEqual(sql('select count(*) from public.wallets', USER), '0')
        sql('select * from public.user_access', USER, fails=True)
        sql('select * from public.account_block_status', role='anon', fails=True)
        sql(f"update public.account_block_status set blocked=false where user_id='{USER}'", USER, fails=True)
        sql(f"insert into public.account_block_status values ('{OTHER}',false)", OTHER, fails=True)
        sql(f"select public.admin_set_blocked('{USER}',false)", ADMIN)
        self.assertEqual(sql('select blocked from public.account_block_status', USER), 'f')
        self.assertEqual(sql('select public.account_access_allowed()', USER), 't')
        result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
            "select count(*) from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='account_block_status'"],
            capture_output=True, text=True, check=True)
        self.assertEqual(result.stdout.strip(), '1')


if __name__ == '__main__':
    unittest.main(verbosity=2)
