"""Audience isolation, reporting permissions and global-release compatibility."""
import sys
import unittest
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
        self.assertEqual(sql('select count(*) from public.app_releases', VIEWER), '1')
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
        sql('set role service_role; ' + publish(21))
        self.assertEqual(sql('select max(version_code) from public.app_releases', OTHER), '21')
        self.assertEqual(sql('select count(*) from public.referral_download_link'), '1')
        sql(f"insert into public.user_access(user_id,blocked) values('{OTHER}',true)")
        sql('select public.report_app_version(21)', OTHER, fails=True)
        sql('set role service_role; ' + publish(22, f"'{OTHER}'"), fails=True)
        self.assertEqual(sql('select max(version_code) from public.app_releases'), '21')

if __name__ == '__main__': unittest.main()
