"""Home slideshow permissions and image limits on a disposable database."""
from admin_test_support import enroll_test_admins
import base64
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
EDITOR = '61000000-0000-4000-8000-000000000001'
VIEWER = '61000000-0000-4000-8000-000000000002'
USER = '61000000-0000-4000-8000-000000000003'
BLOCKED = '61000000-0000-4000-8000-000000000004'
PNG = base64.b64encode(bytes.fromhex('89504e470d0a1a0a') + b'a' * 40).decode()


def sql(query, user=None, role='authenticated', aal='aal2', fails=False):
    prefix = f'set role {role}; ' if role else ''
    if user:
        prefix += f"select set_config('request.jwt.claim.sub','{user}',false); select set_config('request.jwt.claims','{{\"aal\":\"{aal}\"}}',false); "
    result = subprocess.run(['psql','-X','-qAt','-v','ON_ERROR_STOP=1','-d',DB,'-c',prefix+query],capture_output=True,text=True)
    if fails and result.returncode == 0: raise AssertionError('Unexpected success: '+query)
    if not fails and result.returncode: raise AssertionError(result.stderr)
    return (result.stdout.strip().splitlines() or [''])[-1]


class HomeSlides(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sql(f"insert into auth.users(id) values ('{EDITOR}'),('{VIEWER}'),('{USER}'),('{BLOCKED}'); "
            f"insert into public.admin_members(user_id,role) values ('{EDITOR}','editor'),('{VIEWER}','viewer'); "
            f"insert into public.user_access(user_id,blocked) values ('{BLOCKED}',true)",role=None)
        enroll_test_admins(DB)

    def test_access_visibility_download_and_limits(self):
        self.assertEqual(sql('select count(*) from public.home_slides()',USER),'2')
        sql('select * from public.home_slides()',role='anon',fails=True)
        sql('select * from public.home_slides()',BLOCKED,fails=True)
        sql('select * from public.admin_home_slides()',USER,fails=True)
        self.assertEqual(sql('select count(*) from public.admin_home_slides()',VIEWER),'2')
        add=f"select public.admin_add_home_slide('A slide','image/png','{PNG}')"
        sql(add,VIEWER,fails=True)
        sql(add,USER,fails=True)
        sql(add,EDITOR,aal='aal1',fails=True)
        sql("select public.admin_add_home_slide('x','image/png','YQ==')",EDITOR,fails=True)
        sql(f"select public.admin_add_home_slide('x','image/jpeg','{PNG}')",EDITOR,fails=True)
        slide=sql(add,EDITOR)
        self.assertEqual(sql(f"select image_base64 from public.admin_home_slides() where id='{slide}'",VIEWER),PNG)
        self.assertEqual(sql(f"select image_base64 from public.home_slides() where id='{slide}'",USER),PNG)
        sql(f"select public.admin_move_home_slide('{slide}',-1)",VIEWER,fails=True)
        sql(f"select public.admin_move_home_slide('{slide}',-1)",EDITOR)
        self.assertEqual(sql("select kind from public.home_slides() order by sort_order limit 1 offset 1",USER),'image')
        sql(f"select public.admin_move_home_slide('{slide}',2)",EDITOR,fails=True)
        sql(f"select public.admin_set_home_slide_enabled('{slide}',false)",EDITOR)
        self.assertEqual(sql('select count(*) from public.home_slides()',USER),'2')
        self.assertEqual(sql('select count(*) from public.admin_home_slides()',VIEWER),'3')
        sql(f"select public.admin_delete_home_slide('{slide}')",VIEWER,fails=True)
        # Built-in slides are now deletable; editor/MFA checks still apply.
        builtin='00000000-0000-4000-8000-000000000001'
        sql(f"select public.admin_delete_home_slide('{builtin}')",USER,fails=True)
        sql(f"select public.admin_delete_home_slide('{builtin}')",VIEWER,fails=True)
        sql(f"select public.admin_delete_home_slide('{builtin}')",EDITOR,aal='aal1',fails=True)
        sql(f"select public.admin_delete_home_slide('{builtin}')",EDITOR)
        self.assertEqual(sql(f"select count(*) from public.home_slides() where id='{builtin}'",USER),'0')
        self.assertEqual(sql(f"select count(*) from public.admin_home_slides() where id='{builtin}'",VIEWER),'0')
        sql(f"select public.admin_delete_home_slide('{builtin}')",EDITOR,fails=True)
        sql(f"select public.admin_delete_home_slide('{slide}')",EDITOR)
        for i in range(8): sql(f"select public.admin_add_home_slide('slide {i}','image/png','{PNG}')",EDITOR)
        sql(add,EDITOR,fails=True)
        self.assertEqual(sql("select count(*) from growth_internal.home_slides where kind='image'",role=None),'8')
        self.assertEqual(sql("select count(*) from growth_internal.admin_operations_audit where action='Home slide deleted'",role=None),'2')
        sql('select * from growth_internal.home_slides',USER,fails=True)
        sql("insert into growth_internal.home_slides(kind,title,sort_order,image_data,mime) values ('image','invalid',999,decode('89504e470d0a1a0a'||repeat('61',40),'hex'),null)",role=None,fails=True)

if __name__ == '__main__': unittest.main(verbosity=2)
