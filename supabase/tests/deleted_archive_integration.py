"""Deleted-account archive: disposable DB and synthetic users only."""
import json,unittest
from pin_reauthentication_integration import sql,issue,USER,OTHER,DB
from admin_test_support import enroll_test_admins
ADMIN='91000000-0000-4000-8000-000000000003'
CAMPAIGN='92000000-0000-4000-8000-000000000001'
class Archive(unittest.TestCase):
 def test_archive_atomicity_scope_and_permissions(self):
  sql(f"insert into auth.users(id,raw_user_meta_data) values('{USER}','{{\"full_name\":\"Deleted member\",\"password\":\"never-copy\"}}'),('{OTHER}','{{}}'),('{ADMIN}','{{}}'); insert into public.admin_members(user_id,role) values('{ADMIN}','viewer')")
  enroll_test_admins(DB)
  for user in (USER,OTHER):sql('select public.initialize_wallet()',user)
  sql(f"insert into public.campaigns(id,\"ownerId\",type,link,requested,remaining,status) values('{CAMPAIGN}','{USER}','like','https://instagram.com/p/TEST/',1,1,'active')")
  ticket=sql(f"insert into growth_internal.support_tickets(user_id,subject) values('{USER}','Test ticket') returning id")
  sql(f"insert into growth_internal.support_messages(ticket_id,author_id,is_admin,body) values('{ticket}','{ADMIN}',true,'Historical admin reply')")
  issue();self.assertEqual(sql("select public.delete_my_account('000000')",USER),'otp_required')
  self.assertEqual(sql('select count(*) from growth_internal.deleted_account_archives'),'0')
  self.assertEqual(sql("select public.delete_my_account('123456')",USER),'ok')
  archive=sql(f"select id from growth_internal.deleted_account_archives where user_id='{USER}'")
  snapshot=json.loads(sql(f"select snapshot from growth_internal.deleted_account_archives where id='{archive}'"))
  self.assertEqual(snapshot['account']['display_name'],'Deleted member')
  self.assertNotIn('never-copy',json.dumps(snapshot));self.assertNotIn('reauthentication_token',json.dumps(snapshot))
  self.assertEqual(len(snapshot['public.wallets']),1);self.assertEqual(len(snapshot['public.campaigns']),1)
  self.assertEqual(snapshot['growth_internal.support_messages'][0]['body'],'Historical admin reply')
  self.assertEqual(sql(f"select count(*) from public.campaigns where id='{CAMPAIGN}'"),'0')
  sql(f"select public.admin_deleted_account_snapshot('{archive}')",OTHER,fails=True)
  sql(f"select public.admin_deleted_account_snapshot('{archive}')",ADMIN,claims={'aal':'aal1'},fails=True)
  data=json.loads(sql(f"select public.admin_deleted_account_snapshot('{archive}')",ADMIN,claims={'aal':'aal2'}))
  self.assertEqual(data['data'],snapshot)
  self.assertEqual(sql("select count(*) from public.admin_deleted_accounts('Deleted member',0)",ADMIN,claims={'aal':'aal2'}),'1')
  for query in ["select * from growth_internal.deleted_account_archives","delete from growth_internal.deleted_account_archives",f"update growth_internal.deleted_account_archives set snapshot='{{}}' where id='{archive}'"]: sql(query,ADMIN,claims={'aal':'aal2'},fails=True)
  self.assertEqual(sql("select count(*) from growth_internal.admin_operations_audit where action='Deleted account archive viewed/exported'"),'1')
  sql("create function growth_internal.test_fail_archive() returns trigger language plpgsql as $$ begin raise exception 'synthetic archive storage failure'; end $$; create trigger fail_archive before insert on growth_internal.deleted_account_archives for each row execute function growth_internal.test_fail_archive()")
  issue(user=OTHER)
  sql("select public.delete_my_account('123456')",OTHER,fails=True)
  self.assertEqual(sql(f"select count(*) from auth.users where id='{OTHER}'"),'1')
  self.assertEqual(sql(f"select count(*) from public.wallets where id='{OTHER}'"),'1')
  self.assertEqual(sql(f"select count(*) from growth_internal.deleted_account_archives where user_id='{OTHER}'"),'0')

if __name__=='__main__':unittest.main(verbosity=2)
