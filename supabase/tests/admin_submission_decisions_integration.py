"""Exercise admin decisions and directory separation on a disposable database."""
import concurrent.futures
import json
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR, VIEWER, OWNER, ACTOR, OTHER = [f'97000000-0000-4000-8000-{i:012d}' for i in range(1, 6)]
PNG = 'iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGPcHdrBwMDAxMDAwMDAAAATfQGcYGP+awAAAABJRU5ErkJggg=='


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


class AdminDecisions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id,email) values ' + ','.join(f"('{u}','person{i}@example.test')" for i,u in enumerate((EDITOR, VIEWER, OWNER, ACTOR, OTHER))))
        sql(f"insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer')")
        enroll_test_admins(DB)
        for user in (OWNER, ACTOR, OTHER):
            sql('select public.initialize_wallet()', user)

    def campaign_and_claim(self, actor=ACTOR):
        # Each fixture represents a separate 24-hour campaign window.
        sql(f"""update public.campaigns set "createdAt"=clock_timestamp()-interval '25 hours' where "ownerId"='{OWNER}'""")
        campaign = sql("select public.create_campaign_at_rate('like','https://instagram.com/p/ABC/',1,1)", OWNER)
        sql(f'''update public.campaigns set "createdAt"=now()-interval '61 seconds' where id='{campaign}' ''')
        sql(f"select public.submit_claim('{campaign}','participant','image/png','{PNG}')", actor)
        submission = sql(f"select submission_id from public.campaign_claims where campaign_id='{campaign}'", OWNER)
        return campaign, submission

    def test_directory_filters_before_pagination(self):
        self.assertEqual(sql('select count(*) from public.admin_list_users_v2()', EDITOR), '3')
        self.assertEqual(sql("select count(*) from public.admin_list_users_v2('person0')", EDITOR), '0')
        self.assertEqual(sql('select count(*) from public.admin_roles()', EDITOR), '2')
        self.assertEqual(sql('select count(*) from public.admin_list_users_v2(\'\',0,1)', EDITOR), '1')

    def test_editor_decides_without_owner_pin_with_permissions_and_single_reward(self):
        campaign, submission = self.campaign_and_claim()
        call = f"select public.admin_decide_submission('{campaign}','{ACTOR}','{submission}',true)"
        sql(call, ACTOR, fails=True)
        sql(call, VIEWER, fails=True)
        sql(f"select public.review_claim_with_pin('{campaign}','{ACTOR}','{submission}',false,null)", EDITOR, fails=True)
        sql(call, EDITOR, {'aal':'aal1'}, fails=True)
        sql(call, EDITOR)
        sql(call, EDITOR, fails=True)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{campaign}'", ACTOR), 'approved')
        self.assertEqual(sql(f"select count(*) from public.coin_ledger where campaign_id='{campaign}' and reason='task'"), '1')
        self.assertEqual(sql(f"select count(*) from public.claim_evidence where campaign_id='{campaign}'"), '0')
        self.assertEqual(sql(f"select count(*) from growth_internal.admin_operations_audit where action='Submission approved' and subject_id='{campaign}'"), '1')

    def test_reject_stale_and_competing_decisions(self):
        campaign, submission = self.campaign_and_claim(OTHER)
        sql(f"select public.admin_decide_submission('{campaign}','{OTHER}',gen_random_uuid(),false)", EDITOR, fails=True)
        call = f"select public.admin_decide_submission('{campaign}','{OTHER}','{submission}',false)"
        def decide(_):
            try:
                sql(call, EDITOR)
                return True
            except AssertionError:
                return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual(sum(pool.map(decide, range(2))), 1)
        self.assertEqual(sql(f"select status from public.campaign_claims where campaign_id='{campaign}'", OTHER), 'rejected')
        self.assertEqual(sql(f"select count(*) from public.coin_ledger where campaign_id='{campaign}' and reason='task'"), '0')

if __name__ == '__main__':
    unittest.main()
