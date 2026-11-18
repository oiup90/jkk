"""PIN hashing and legacy upgrade checks on disposable PostgreSQL only."""
import concurrent.futures
import json
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
USER = '99000000-0000-4000-8000-000000000001'
OTHER = '99000000-0000-4000-8000-000000000002'


def sql(query, user=None, fails=False):
    prefix = ''
    if user:
        claims = json.dumps({'email': 'synthetic@example.test', 'phone': ''})
        prefix = (f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
                  f"select set_config('request.jwt.claims','{claims}',false); ")
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', prefix + query],
                            text=True, capture_output=True)
    if fails:
        if result.returncode == 0:
            raise AssertionError('Unexpected success')
    elif result.returncode:
        raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


class PinHashUpgradeTests(unittest.TestCase):
    def setUp(self):
        sql(f"delete from auth.users where id in ('{USER}','{OTHER}'); "
            f"insert into auth.users(id) values('{USER}'),('{OTHER}'); "
            f"insert into growth_internal.release_pins(user_id,pin_hash) "
            f"values('{USER}',extensions.crypt('1234',extensions.gen_salt('bf',10)))")

    def test_new_hashes_use_unique_salts_and_cost_12(self):
        self.assertEqual(sql("with hashes as (select growth_internal.pin_hash('1234') a, "
                             "growth_internal.pin_hash('1234') b) select "
                             "a like '$2a$12$%' and b like '$2a$12$%' and a<>b and "
                             "extensions.crypt('1234',a)=a and extensions.crypt('9999',a)<>a from hashes"), 't')
        sql("select growth_internal.pin_hash('1234')", USER, fails=True)
        sql('select pin_hash from growth_internal.release_pins', USER, fails=True)

    def test_wrong_pin_and_lockout_do_not_upgrade_legacy_hash(self):
        for _ in range(5):
            self.assertEqual(sql("select public.verify_security_pin('9999')", USER), 'invalid_pin')
        self.assertEqual(sql("select public.verify_security_pin('1234')", USER), 'pin_locked')
        self.assertEqual(sql(f"select pin_hash like '$2a$10$%' and failures=5 and locked_until>now() "
                             f"from growth_internal.release_pins where user_id='{USER}'"), 't')

    def test_success_upgrades_legacy_pin_and_preserves_verification(self):
        self.assertEqual(sql("select public.verify_security_pin('1234')", USER), 'ok')
        self.assertEqual(sql(f"select pin_hash like '$2a$12$%' and extensions.crypt('1234',pin_hash)=pin_hash "
                             f"and failures=0 and locked_until is null from growth_internal.release_pins where user_id='{USER}'"), 't')
        self.assertEqual(sql("select public.verify_security_pin('1234')", USER), 'ok')
        self.assertEqual(sql("select public.verify_security_pin('1234')", OTHER), 'pin_missing')

    def test_concurrent_legacy_verifications_both_succeed(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            outcomes = list(executor.map(lambda _: sql("select public.verify_security_pin('1234')", USER), range(2)))
        self.assertEqual(outcomes, ['ok', 'ok'])
        self.assertEqual(sql(f"select pin_hash like '$2a$12$%' from growth_internal.release_pins where user_id='{USER}'"), 't')


if __name__ == '__main__':
    unittest.main(verbosity=2)
