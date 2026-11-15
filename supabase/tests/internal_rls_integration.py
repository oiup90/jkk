"""Private-table permissions after the hosted RLS settings are replayed locally."""
import subprocess
import sys
import unittest

DB = sys.argv[1]
sys.argv = sys.argv[:1]
TABLES = [
    'admin_alert_settings', 'admin_event_reads', 'admin_events', 'admin_notes',
    'admin_operations_audit', 'admin_setting_audit', 'campaign_reports',
    'coin_adjustments', 'instagram_lookup_limits', 'support_messages',
    'support_tickets',
]


class PrivateTables(unittest.TestCase):
    def test_private_tables_are_protected(self):
        for table in TABLES:
            with self.subTest(table=table):
                result = subprocess.run([
                    'psql', '-X', '-qAt', '-v', 'ON_ERROR_STOP=1', '-d', DB, '-c',
                    f"select relrowsecurity and not relforcerowsecurity "
                    f"and not has_table_privilege('anon',oid,'SELECT,INSERT,UPDATE,DELETE') "
                    f"and not has_table_privilege('authenticated',oid,'SELECT,INSERT,UPDATE,DELETE') "
                    f"from pg_class where oid='growth_internal.{table}'::regclass",
                ], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), 't')


if __name__ == '__main__':
    unittest.main()
