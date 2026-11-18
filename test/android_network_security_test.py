"""Android cleartext restrictions must apply to every build variant."""
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'android/app/src'
ANDROID = '{http://schemas.android.com/apk/res/android}'


class AndroidNetworkSecurity(unittest.TestCase):
    def test_all_variants_inherit_a_cleartext_disabled_policy(self):
        app = ET.parse(ROOT / 'main/AndroidManifest.xml').getroot().find('application')
        self.assertEqual(app.get(ANDROID + 'usesCleartextTraffic'), 'false')
        self.assertEqual(app.get(ANDROID + 'networkSecurityConfig'), '@xml/network_security_config')
        config = ET.parse(ROOT / 'main/res/xml/network_security_config.xml').getroot()
        self.assertEqual(config.find('base-config').get('cleartextTrafficPermitted'), 'false')
        for element in config.iter():
            self.assertNotEqual(element.get('cleartextTrafficPermitted'), 'true')
        for variant in ('debug', 'profile'):
            manifest = ET.parse(ROOT / variant / 'AndroidManifest.xml').getroot()
            for application in manifest.findall('application'):
                self.assertNotIn(ANDROID + 'usesCleartextTraffic', application.attrib)
                self.assertNotIn(ANDROID + 'networkSecurityConfig', application.attrib)


if __name__ == '__main__':
    unittest.main()
