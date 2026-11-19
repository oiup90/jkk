"""Audience isolation, reporting permissions and global-release compatibility."""
import sys
import unittest
from concurrent.futures import ThreadPoolExecutor
import app_updates_integration as base

DB = base.DB
sql = base.sql
EDITOR, VIEWER, USER = base.EDITOR, base.VIEWER, base.USER
OTHER = '92000000-0000-4000-8000-000000000004'

class TargetedReleases(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        base.Updates.setUpClass()
        sql(f"insert into auth.users(id) values('{OTHER}')")
        sql('select public.initialize_wallet()', OTHER)

    def test_audience_reports_and_global_compatibility(self):
        def publish(version, target='null'):
            path = f'12345678-1234-1234-1234-{version:012d}.apk'
            return f"select public.publish_r2_app_release_scoped('{EDITOR}',{version},'2.0','{path}','{'a'*64}',100,'Targeted notes','https://updates.example.test/{path}',{target})"
        sql(publish(20, f"'{USER}'"), USER, fails=True)
        sql(publish(20, f"'{USER}'"), EDITOR, fails=True)
        release = sql('set role service_role; ' + publish(20, f"'{USER}'"))
        self.assertEqual(sql('select count(*) from public.app_releases', USER), '1')
        self.assertEqual(sql('select count(*) from public.app_releases', OTHER), '0')
        self.assertEqual(sql('select count(*) from public.app_releases', VIEWER), '0')
        self.assertEqual(sql('select count(*) from public.app_releases', EDITOR), '0')
        self.assertEqual(sql('select count(*) from public.admin_app_release_history()', VIEWER), '1')
        sql('select * from public.admin_app_release_history()', USER, fails=True)
        self.assertEqual(sql("select count(*) from public.notifications where kind='app_update'", USER), '1')
        self.assertEqual(sql("select count(*) from public.notifications where kind='app_update'", OTHER), '0')
        self.assertEqual(sql('select count(*) from public.referral_download_link'), '0')
        sql('select public.report_app_version(20)', USER)
        self.assertEqual(sql('select count(*) from public.app_installations', USER), '0')
        sql(f"select * from public.admin_release_installations('{release}')", USER, fails=True)
        self.assertEqual(sql(f"select count(*) from public.admin_release_installations('{release}') where updated", VIEWER), '1')
        sql('select public.report_app_version(0)', USER, fails=True)
        sql(f"insert into public.app_installations(user_id,version_code) values('{OTHER}',20)", USER, fails=True)
        sql('select public.report_app_version(19)', USER)
        self.assertEqual(sql(f"select count(*) from public.admin_release_installations('{release}') where updated", EDITOR), '0')

        # Release artifacts remain protected even when the editor's app cannot see the target.
        path = '12345678-1234-1234-1234-000000000020.apk'
        sql(f"insert into storage.objects(bucket_id,name,metadata) values('app-releases','{path}','{{\"size\":100}}')", EDITOR)
        self.assertEqual(sql(f"with gone as (delete from storage.objects where name='{path}' returning id) select count(*) from gone", EDITOR), '0')
        promote = f"select public.admin_promote_app_release('{release}')"
        sql(promote, USER, fails=True)
        sql(promote, VIEWER, fails=True)
        sql("select set_config('request.jwt.claims','{\"aal\":\"aal1\",\"email\":\"synthetic@example.test\"}',false); " + promote, EDITOR, fails=True)
        # Competing retries publish exactly once, retaining the original artifact.
        with ThreadPoolExecutor(max_workers=2) as pool:
            list(pool.map(lambda _: sql(promote, EDITOR), range(2)))
        self.assertEqual(sql(f"select count(*) from public.app_releases where id='{release}' and version_code=20 and apk_path='{path}' and target_user_id is null", OTHER), '1')
        self.assertEqual(sql(f"select count(*) from public.notifications where kind='app_update' and release_id='{release}'", USER), '1')
        self.assertEqual(sql(f"select count(*) from public.notifications where kind='app_update' and release_id='{release}'", OTHER), '1')
        self.assertEqual(sql("select url from public.referral_download_link"), f'https://updates.example.test/{path}')
        self.assertEqual(sql(f"select count(*) from public.admin_release_installations('{release}')", EDITOR), '4')
        self.assertEqual(sql("select count(*) from growth_internal.admin_operations_audit where action='Targeted app release published to everyone'"), '1')
        sql('set role service_role; ' + publish(21))
        self.assertEqual(sql('select max(version_code) from public.app_releases', OTHER), '21')
        self.assertEqual(sql('select count(*) from public.referral_download_link'), '1')
        sql(f"insert into public.user_access(user_id,blocked) values('{OTHER}',true)")
        sql('select public.report_app_version(21)', OTHER, fails=True)
        sql('set role service_role; ' + publish(22, f"'{OTHER}'"), fails=True)
        self.assertEqual(sql('select max(version_code) from public.app_releases'), '21')

        # An older targeted version cannot replace a newer global version.
        old = sql('set role service_role; ' + publish(22, f"'{USER}'"))
        sql('set role service_role; ' + publish(23))
        sql(f"select public.admin_promote_app_release('{old}')", EDITOR, fails=True)
        self.assertEqual(sql(f"select target_user_id from public.app_releases where id='{old}'"), USER)
        self.assertEqual(sql('select count(*) from public.app_releases', OTHER), '0')

if __name__ == '__main__': unittest.main()
