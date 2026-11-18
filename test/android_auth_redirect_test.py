"""Verify the app can receive new and already issued recovery links."""

from pathlib import Path
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


class AndroidAuthRedirect(unittest.TestCase):
    def test_new_and_legacy_recovery_schemes_target_the_main_activity(self):
        manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
        activity = manifest.find("application/activity[@" + ANDROID + "name='.MainActivity']")
        self.assertIsNotNone(activity)
        targets = set()
        for intent in activity.findall('intent-filter'):
            actions = {a.get(ANDROID + 'name') for a in intent.findall('action')}
            categories = {c.get(ANDROID + 'name') for c in intent.findall('category')}
            if 'android.intent.action.VIEW' not in actions or not {
                'android.intent.category.DEFAULT', 'android.intent.category.BROWSABLE'
            } <= categories:
                continue
            targets.update((d.get(ANDROID + 'scheme'), d.get(ANDROID + 'host'))
                           for d in intent.findall('data'))
        self.assertIn(('space.freelan.app', 'login-callback'), targets)
        self.assertIn(('io.supabase.growthcircle', 'login-callback'), targets)


if __name__ == '__main__':
    unittest.main()
