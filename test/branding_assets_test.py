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

    def test_launch_logo_is_selected_for_both_android_splash_apis(self):
        resources = ROOT / 'android/app/src/main/res'
        manifest = ET.parse(ROOT / 'android/app/src/main/AndroidManifest.xml').getroot()
        activity = manifest.find("application/activity[@" + ANDROID + "name='.MainActivity']")
        self.assertEqual(activity.get(ANDROID + 'theme'), '@style/LaunchTheme')
        for qualifier in ('values', 'values-night'):
            styles = ET.parse(resources / qualifier / 'styles.xml').getroot()
            launch = styles.find("style[@name='LaunchTheme']")
            base = styles.find("style[@name='LaunchThemeBase']")
            self.assertEqual(launch.get('parent'), 'LaunchThemeBase')
            self.assertEqual(base.find("item[@name='android:windowBackground']").text,
                             '@drawable/launch_background')
        for qualifier in ('drawable', 'drawable-v21'):
            layers = ET.parse(resources / qualifier / 'launch_background.xml').getroot().findall('item')
            self.assertEqual(layers[0].get(ANDROID + 'drawable'), '@color/launch_background')
            self.assertEqual(layers[1].get(ANDROID + 'drawable'), '@drawable/ic_freelan_launcher')
            self.assertEqual(layers[1].get(ANDROID + 'gravity'), 'center')
        for qualifier in ('values-v31', 'values-night-v31'):
            launch = ET.parse(resources / qualifier / 'styles.xml').getroot().find("style[@name='LaunchTheme']")
            self.assertEqual(launch.get('parent'), 'LaunchThemeBase')
            items = {item.get('name'): item.text for item in launch.findall('item')}
            self.assertEqual(items['android:windowSplashScreenBackground'], '@color/launch_background')
            self.assertEqual(items['android:windowSplashScreenAnimatedIcon'], '@drawable/ic_freelan_splash')
        # Match the existing brand and keep it within the Android 12 circular safe zone.
        launcher = ET.parse(resources / 'drawable/ic_freelan_launcher.xml').getroot()
        splash = ET.parse(resources / 'drawable/ic_freelan_splash.xml').getroot()
        group = splash.find('group')
        self.assertEqual([path.attrib for path in launcher.findall('path')],
                         [path.attrib for path in group.findall('path')])
        self.assertEqual((splash.get(ANDROID + 'viewportWidth'), splash.get(ANDROID + 'viewportHeight')), ('288', '288'))
        self.assertEqual((group.get(ANDROID + 'translateX'), group.get(ANDROID + 'translateY'),
                          group.get(ANDROID + 'scaleX'), group.get(ANDROID + 'scaleY')), ('72', '72', '3', '3'))

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
