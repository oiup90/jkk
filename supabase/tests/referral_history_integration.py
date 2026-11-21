"""Run in a disposable database bootstrapped by run_integration.py."""
import json
import subprocess
import sys
import unittest

DB = sys.argv.pop(1)
A = "fa100000-0000-4000-8000-000000000001"
B = "fa100000-0000-4000-8000-000000000002"
C = "fa100000-0000-4000-8000-000000000003"
D = "fa100000-0000-4000-8000-000000000004"


def sql(query, uid=None, role=None):
    args = ["psql", "-XqAt", "-v", "ON_ERROR_STOP=1", "-d", DB]
    if role:
        args += ["-c", f"set role {role}"]
    if uid:
        args += ["-c", f"set request.jwt.claim.sub='{uid}'"]
    return subprocess.run(args + ["-c", query], capture_output=True, text=True)


class ReferralHistory(unittest.TestCase):
    def test_masking_and_isolation(self):
        fixture = sql(f"""
          insert into auth.users(id,email,raw_user_meta_data) values
          ('{A}','alice@example.test','{{"full_name":"Alice Full Name"}}'),
          ('{B}','bob@example.test','{{"full_name":"Bob Full Name"}}'),
          ('{C}','cat@example.test','{{"full_name":"Cat Full Name"}}'),
          ('{D}','d@example.test','{{"full_name":"D"}}');
          insert into public.wallets(id,balance) values ('{A}',0), ('{B}',0);
          insert into growth_internal.referrals(referred_id,referrer_id)
          values ('{B}','{A}'), ('{C}','{B}');
        """)
        self.assertEqual(fixture.returncode, 0, fixture.stderr)
        query = "select coalesce(json_agg(h),'[]') from public.referral_history() h"
        result = sql(query, B, "authenticated")
        self.assertEqual(result.returncode, 0, result.stderr)
        rows = json.loads(result.stdout)
        self.assertEqual(
            {row['direction']: (row['masked_name'],row['masked_email']) for row in rows},
            {'referrer': ('A***','a***@***'), 'referred': ('C***','c***@***')},
        )
        self.assertEqual(json.loads(sql(query, D, "authenticated").stdout), [])
        self.assertEqual(
            json.loads(sql(query.replace('history()', 'history(2)'), B, "authenticated").stdout), [],
        )
        self.assertIn("permission denied", sql(query, role="anon").stderr)
        sql(f"insert into public.user_access(user_id,blocked) values ('{B}',true)").check_returncode()
        self.assertIn("Account access is blocked", sql(query, B, "authenticated").stderr)


if __name__ == "__main__":
    unittest.main()
