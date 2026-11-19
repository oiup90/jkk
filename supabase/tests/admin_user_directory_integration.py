"""Administrator directory and access history on a disposable database."""
import json
import subprocess
import sys
import unittest
from admin_test_support import enroll_test_admins, test_claims

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR, VIEWER, USER, OTHER = [f'99000000-0000-4000-8000-{i:012d}' for i in range(1, 5)]

def sql(query, user=None, claims=None, fails=False):
    prefix = '' if not user else (f"set role authenticated; select set_config('request.jwt.claim.sub','{user}',false); "
        f"select set_config('request.jwt.claims','{json.dumps(claims or {})}',false); ")
    result = subprocess.run(['psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c', test_claims(prefix) + query], capture_output=True, text=True)
    if fails:
        if result.returncode == 0: raise AssertionError('Unexpected success')
    elif result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]

class DirectoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql('insert into auth.users(id,email) values '+','.join(f"('{u}','test{i}@example.test')" for i,u in enumerate((EDITOR,VIEWER,USER,OTHER))))
        sql(f"insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer')")
        enroll_test_admins(DB)
        sql(f'''update auth.users set created_at='2026-01-01 23:30+00',last_sign_in_at='2026-02-03 10:00+00' where id='{USER}';
        update auth.users set created_at='2026-01-02 10:00+00',last_sign_in_at=null where id='{OTHER}';
        insert into auth.users(id,email,created_at) select gen_random_uuid(),'member'||n||'@example.test','2026-03-01'::timestamptz+n*interval '1 second' from generate_series(1,55) n;''')
        sql('select public.initialize_wallet()', USER)
        sql(f"update public.wallets set held_balance=2,is_active=false where id='{USER}'")
        sql(f"insert into growth_internal.support_tickets(user_id,subject,updated_at) values ('{USER}','Target',now()-interval '3 days')")
        sql(f"insert into growth_internal.support_tickets(user_id,subject) select '{OTHER}','Other' from generate_series(1,105)")
        sql(f"select public.admin_set_blocked('{USER}',true)", EDITOR)
        sql(f"select public.admin_set_blocked('{USER}',false)", EDITOR)

    def test_filters_sort_and_pagination(self):
        self.assertEqual(sql("select count(*) from public.admin_list_users_v3('member','all',null,null,null,null,'joined',true,0,50)",VIEWER),'50')
        self.assertEqual(sql("select count(*) from public.admin_list_users_v3('member','all',null,null,null,null,'joined',true,50,50)",VIEWER),'5')
        self.assertEqual(sql("select count(*) from public.admin_list_users_v3('test','active','2026-01-01','2026-01-01')",VIEWER),'1')
        self.assertEqual(sql("select count(*) from public.admin_list_users_v3('test','all',null,null,'2026-02-03','2026-02-03')",VIEWER),'1')
        self.assertEqual(sql("select email from public.admin_list_users_v3('test','all',null,null,null,null,'last_login',true,0,1)",VIEWER),'test2@example.test')
        sql("select * from public.admin_list_users_v3('','invalid')",VIEWER,fails=True)
        sql("select * from public.admin_list_users_v3('', 'all', '2026-02-01','2026-01-01')",VIEWER,fails=True)
        sql('select * from public.admin_list_users_v3()',USER,fails=True)

    def test_reason_history_and_user_specific_data(self):
        call=f"select public.admin_set_blocked_with_reason('{USER}',true,'Test reason')"
        sql(call,VIEWER,fails=True)
        sql(call,EDITOR,{'aal':'aal1'},fails=True)
        sql(f"select public.admin_set_blocked_with_reason('{USER}',true,'')",EDITOR,fails=True)
        sql(call,EDITOR)
        sql(call,EDITOR)
        details=json.loads(sql(f"select public.admin_user_details_v2('{USER}')",VIEWER))
        self.assertEqual(details['wallet']['held_balance'],2)
        self.assertFalse(details['wallet']['is_active'])
        self.assertEqual(len(details['block_history']),3)
        self.assertEqual(details['block_history'][0]['reason'],'Test reason')
        self.assertIsNone(details['block_history'][-1]['reason'])
        self.assertEqual(sql("select count(*) from public.admin_list_users_v3('test','blocked')",VIEWER),'1')
        self.assertEqual(sql(f"select count(*) from public.admin_support_tickets_for_user('{USER}')",VIEWER),'1')
        self.assertEqual(sql(f"select user_id from public.admin_wallet_for_user('{USER}')",VIEWER),USER)
        sql(f"select public.admin_user_details_v2('{OTHER}')",USER,fails=True)
        sql(f"select * from public.admin_support_tickets_for_user('{OTHER}')",USER,fails=True)
        sql(f"select * from public.admin_wallet_for_user('{OTHER}')",USER,fails=True)
        sql(f"select public.admin_set_blocked_with_reason('{EDITOR}',true,'test')",EDITOR,fails=True)

if __name__ == '__main__': unittest.main()
