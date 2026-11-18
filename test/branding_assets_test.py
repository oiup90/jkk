"""Check the native resources used to display the Freelan Space brand."""

from pathlib import Path
import struct
import unittest
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
ANDROID = '{http://schemas.android.com/apk/res/android}'


class BrandingAssets(unittest.TestCase):
    def test_android_launcher_and_notifications_use_freelan_resources(self):
        android = ROOT / 'android/app/src/main'
        manifest = ET.parse(android / 'AndroidManifest.xml').getroot()
        application = manifest.find('application')
        self.assertEqual(application.get(ANDROID + 'label'), 'Freelan Space')
        self.assertEqual(application.get(ANDROID + 'icon'), '@drawable/ic_freelan_launcher')
        metadata = {m.get(ANDROID + 'name'): m.get(ANDROID + 'resource')
                    for m in application.findall('meta-data')}
        self.assertEqual(metadata['com.google.firebase.messaging.default_notification_icon'],
                         '@drawable/ic_freelan_notification')
        activity = (android / 'kotlin/space/freelan/app/MainActivity.kt').read_text()
        self.assertIn('setSmallIcon(R.drawable.ic_freelan_notification)', activity)
        icon = ET.parse(android / 'res/drawable/ic_freelan_notification.xml').getroot()
        fills = {path.get(ANDROID + 'fillColor') for path in icon.findall('path')}
        self.assertEqual(fills, {'#FFFFFFFF', '@android:color/transparent'})

    def test_windows_icon_contains_standard_png_sizes(self):
        data = (ROOT / 'windows/runner/resources/app_icon.ico').read_bytes()
        reserved, kind, count = struct.unpack_from('<HHH', data)
        self.assertEqual((reserved, kind), (0, 1))
        sizes = set()
        for index in range(count):
            width, height, _, _, _, _, length, offset = struct.unpack_from(
                '<BBBBHHII', data, 6 + index * 16)
            sizes.add((width or 256, height or 256))
            self.assertLessEqual(offset + length, len(data))
            self.assertEqual(data[offset:offset + 8], b'\x89PNG\r\n\x1a\n')
        self.assertTrue({(16, 16), (32, 32), (48, 48), (256, 256)} <= sizes)


if __name__ == '__main__':
    unittest.main()
