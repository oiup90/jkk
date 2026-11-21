"""Admin plan permissions and the effect of settings on creation, disposable DB only."""
import json
import subprocess
import sys
import unittest
import uuid
from admin_test_support import enroll_test_admins, test_claims

DB=sys.argv[1]
sys.argv=sys.argv[:1]
EDITOR, VIEWER, MEMBER, REFERRED = [str(uuid.uuid4()) for _ in range(4)]

def sql(q, user=None, claims=None, fails=False):
    prefix='' if user is None else f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{json.dumps(claims or {})}',false); "
    result=subprocess.run(['psql','-XqAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',test_claims(prefix)+q],capture_output=True,text=True)
    if fails:
        assert result.returncode != 0, q
    else:
        assert result.returncode == 0, result.stderr
    return (result.stdout.strip().splitlines() or [''])[-1]

class AdminPlan(unittest.TestCase):
    def test_admin_edit_and_live_enforcement(self):
        sql(f"insert into auth.users(id) values ('{EDITOR}'),('{VIEWER}'),('{MEMBER}'),('{REFERRED}'); insert into public.admin_members(user_id,role) values('{EDITOR}','editor'),('{VIEWER}','viewer'); insert into public.wallets(id,balance) values('{MEMBER}',100),('{REFERRED}',100);")
        enroll_test_admins(DB)
        self.assertEqual(json.loads(sql('select public.admin_campaign_plan()',VIEWER))['base_tasks'],3)
        sql('select public.admin_campaign_plan()',MEMBER,fails=True)
        sql('select public.admin_set_campaign_plan(2,12,6,4)',VIEWER,fails=True)
        sql('select public.admin_set_campaign_plan(2,12,6,4)',MEMBER,fails=True)
        sql('select public.admin_set_campaign_plan(2,12,6,4)',EDITOR,{'aal':'aal1'},fails=True)
        for values in ('0,12,6,4','2,0,6,4','2,12,99,2','2,12,6,-1','2,12,null,4'):
            sql(f'select public.admin_set_campaign_plan({values})',EDITOR,fails=True)
        sql('select public.admin_set_campaign_plan(2,12,6,4)',EDITOR)
        plan=json.loads(sql('select public.campaign_plan_limits()',MEMBER))
        self.assertEqual((plan['campaign_count'],plan['window_hours'],plan['max_tasks']),(2,12,6))
        create=lambda count: f"select public.create_campaign_at_rate('like','https://instagram.com/p/TEST/',{count},1)"
        first=sql(create(6),MEMBER)
        self.assertIsNone(json.loads(sql('select public.campaign_plan_limits()',MEMBER))['next_campaign_at'])
        second=sql(create(1),MEMBER)
        self.assertIsNotNone(json.loads(sql('select public.campaign_plan_limits()',MEMBER))['next_campaign_at'])
        sql(create(1),MEMBER,fails=True)
        sql(f'update public.campaigns set "createdAt"=clock_timestamp()-interval \'13 hours\' where id=\'{first}\'')
        code=json.loads(sql('select public.referral_info()',MEMBER))['code']
        sql(f"select public.apply_referral('{code}')",REFERRED)
        self.assertEqual(json.loads(sql('select public.campaign_plan_limits()',MEMBER))['max_tasks'],10)
        sql(create(11),MEMBER,fails=True)
        sql(create(10),MEMBER)
        self.assertEqual(sql(f"select count(*) from growth_internal.admin_operations_audit where actor_id='{EDITOR}' and action='Campaign plan updated'"),'1')
        sql('set role authenticated; select * from growth_internal.campaign_plan_settings',fails=True)

if __name__ == '__main__': unittest.main(verbosity=2)
