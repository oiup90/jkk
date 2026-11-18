"""Exercise build orchestration with a fake Flutter executable and temporary files.

Run with Python 3 and PowerShell available as `pwsh`. Native Windows .cmd,
Flutter compilation and real signing need separate target-environment checks.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PWSH = shutil.which('pwsh')


class WindowsWorkflow(unittest.TestCase):
    def test_admin_artifact_enables_auth_captcha(self):
        workflow = (ROOT / '.github/workflows/windows-admin.yml').read_text()
        builds = [line.strip() for line in workflow.splitlines()
                  if line.strip().startswith('- run: flutter build windows ')]
        self.assertEqual(len(builds), 1)
        self.assertIn('--dart-define=AUTH_CAPTCHA_ENABLED=true', builds[0].split())
        self.assertIn('lib/admin_main.dart', builds[0].split())


@unittest.skipUnless(PWSH and os.name != 'nt', 'PowerShell and a Unix fake Flutter executable are required')
class BuildScripts(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'project with spaces'
        shutil.copytree(ROOT / 'scripts', self.root / 'scripts')
        for name in ['config/production.json', 'android/app/google-services.json', 'android/key.properties']:
            file = self.root / name
            file.parent.mkdir(parents=True, exist_ok=True)
            file.write_text('{}')
        self.log = Path(self.temp.name) / 'calls.jsonl'
        bin_dir = Path(self.temp.name) / 'bin'
        bin_dir.mkdir()
        fake = bin_dir / 'flutter'
        fake.write_text('''#!/usr/bin/env python3
import json,os,pathlib,sys
with open(os.environ['BUILD_TEST_LOG'],'a') as f: f.write(json.dumps({'args':sys.argv[1:],'cwd':os.getcwd()})+'\\n')
args=sys.argv[1:]
if args == ['--version','--machine']:
 print(json.dumps({'frameworkVersion':os.environ.get('BUILD_TEST_VERSION','3.47.9')}));sys.exit(0)
if os.environ.get('BUILD_TEST_FAIL') and args[0] == os.environ['BUILD_TEST_FAIL']:
 sys.exit(9)
if args[:2] == ['build','apk']:
 p=pathlib.Path('build/app/outputs/flutter-apk/app-release.apk');p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b'new apk')
 if not os.environ.get('BUILD_TEST_NO_SYMBOLS'):
  symbols=next(a.split('=',1)[1] for a in args if a.startswith('--split-debug-info='))
  for arch in ('arm','arm64','x64'):
   if arch != os.environ.get('BUILD_TEST_MISSING_ARCH'):
    (pathlib.Path(symbols)/f'app.android-{arch}.symbols').write_bytes(b'symbols')
if args[:2] == ['build','windows']:
 p=pathlib.Path('build/windows/x64/runner/Release');p.mkdir(parents=True,exist_ok=True)
 exe=p/'freelan_space_admin.exe';exe.write_text('#!/bin/sh\\n/bin/pwd > "$BUILD_TEST_RUN_LOG"\\n');exe.chmod(0o755)
 (p/'flutter_windows.dll').write_bytes(b'engine')
 data=p/'data';data.mkdir(exist_ok=True);(data/'app.so').write_bytes(b'app')
''')
        fake.chmod(0o755)
        self.env = dict(os.environ, PATH=str(bin_dir) + os.pathsep + os.environ['PATH'], BUILD_TEST_LOG=str(self.log), BUILD_TEST_RUN_LOG=str(Path(self.temp.name) / 'started.txt'))

    def run_script(self, name, *args):
        return subprocess.run([PWSH, '-NoProfile', '-File', str(self.root / 'scripts' / name), *args],
                              cwd=self.temp.name, env=self.env, capture_output=True, text=True)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()]

    def test_user_build_uses_public_config_and_optional_version(self):
        p = self.run_script('build-user-apk.ps1', '-BuildNumber', '18', '-BuildName', '1.2.0')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        calls = self.calls()
        self.assertTrue(all(call['cwd'] == str(self.root) for call in calls))
        self.assertEqual(calls[1]['args'], ['pub', 'get', '--enforce-lockfile'])
        args = calls[2]['args']
        self.assertEqual(args[:7], ['build', 'apk', '--release', '--no-pub', '--dart-define-from-file=config/production.json', '--dart-define=AUTH_CAPTCHA_ENABLED=true', '--obfuscate'])
        self.assertTrue(args[7].startswith('--split-debug-info='))
        symbols = Path(args[7].split('=', 1)[1])
        self.assertEqual(symbols.parent, self.root / 'release-symbols')
        self.assertTrue((symbols / 'app.android-arm64.symbols').is_file())
        self.assertEqual(args[8:], ['--build-number=18', '--build-name=1.2.0'])
        self.assertEqual((self.root / 'build/app/outputs/flutter-apk/app-release.apk').read_bytes(), b'new apk')

    def test_default_user_build_uses_pubspec_version(self):
        p = self.run_script('build-user-apk.ps1')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertFalse(any(a.startswith('--build-number=') for a in self.calls()[2]['args']))

    def test_user_builds_keep_separate_symbols(self):
        for _ in range(2):
            p = self.run_script('build-user-apk.ps1')
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        symbol_args = [a for call in self.calls() for a in call['args'] if a.startswith('--split-debug-info=')]
        self.assertEqual(len(set(symbol_args)), 2)
        self.assertTrue(all((Path(a.split('=', 1)[1]) / 'app.android-arm64.symbols').exists() for a in symbol_args))

    def test_user_build_requires_symbols(self):
        self.env['BUILD_TEST_MISSING_ARCH'] = 'x64'
        p = self.run_script('build-user-apk.ps1')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('Dart symbols were not found', p.stderr)
        self.assertIn('app.android-x64.symbols', p.stderr)

    def test_admin_zip_includes_entire_release_directory(self):
        old_zip = self.root / 'build/freelan-space-admin-windows.zip'
        old_zip.parent.mkdir(parents=True)
        old_zip.write_bytes(b'old archive')
        release = self.root / 'build/windows/x64/runner/Release'
        release.mkdir(parents=True)
        (release / 'growth_circle_admin.exe').write_bytes(b'old executable')
        (release / 'growth_circle_admin.pdb').write_bytes(b'old symbols')
        p = self.run_script('build-admin-windows.ps1')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertEqual(self.calls()[2]['args'], ['build', 'windows', '--release', '--no-pub', '-t', 'lib/admin_main.dart', '--dart-define=AUTH_CAPTCHA_ENABLED=true'])
        with zipfile.ZipFile(self.root / 'build/freelan-space-admin-windows.zip') as archive:
            self.assertEqual(set(archive.namelist()), {'freelan_space_admin.exe', 'flutter_windows.dll', 'data/app.so'})
        self.assertEqual((release / 'growth_circle_admin.exe').read_bytes(), b'old executable')

    def test_admin_build_can_disable_captcha_for_other_projects(self):
        p = self.run_script('build-admin-windows.ps1', '-DisableCaptcha')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertNotIn('--dart-define=AUTH_CAPTCHA_ENABLED=true', self.calls()[2]['args'])

    def test_admin_run_uses_release_directory(self):
        p = self.run_script('build-admin-windows.ps1', '-Run')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        started = Path(self.env['BUILD_TEST_RUN_LOG'])
        deadline = time.monotonic() + 5
        while not started.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertTrue(started.exists(), 'admin process was not started')
        self.assertEqual(started.read_text().strip(), str(self.root / 'build/windows/x64/runner/Release'))

    def test_missing_signing_files_stop_before_build(self):
        (self.root / 'android/key.properties').unlink()
        p = self.run_script('build-user-apk.ps1')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('android/key.properties', p.stderr)
        self.assertFalse(self.log.exists())

    def test_failed_build_never_reports_stale_output(self):
        self.env['BUILD_TEST_FAIL'] = 'build'
        stale = self.root / 'build/freelan-space-admin-windows.zip'
        stale.parent.mkdir(parents=True)
        stale.write_bytes(b'previous zip')
        p = self.run_script('build-admin-windows.ps1')
        self.assertNotEqual(p.returncode, 0)
        self.assertNotIn('Admin ZIP (includes required files):', p.stdout)
        self.assertEqual(stale.read_bytes(), b'previous zip')
        self.assertIn('exit 9', p.stderr)

    def test_verbose_builds_forward_flag(self):
        for name in ('build-user-apk.ps1', 'build-admin-windows.ps1'):
            p = self.run_script(name, '-VerboseBuild')
            self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
            self.assertIn('--verbose', self.calls()[-1]['args'])

    def test_install_diagnostic_requires_existing_build(self):
        p = self.run_script('build-admin-windows.ps1', '-DiagnoseInstall')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('CMake cache not found', p.stderr)
        self.assertFalse(self.log.exists())

    def test_install_diagnostic_uses_cached_cmake_and_propagates_errors(self):
        native = self.root / 'build/windows/x64'
        native.mkdir(parents=True)
        cmake = Path(self.temp.name) / 'cmake with spaces'
        cmake.write_text('''#!/usr/bin/env python3
import json, os, pathlib, sys
pathlib.Path(os.environ['BUILD_TEST_RUN_LOG']).write_text(json.dumps({'cwd':os.getcwd(),'args':sys.argv[1:]}))
print('synthetic install error', file=sys.stderr)
sys.exit(7)
''')
        cmake.chmod(0o755)
        (native / 'CMakeCache.txt').write_text(f'CMAKE_COMMAND:INTERNAL={cmake}\n')
        p = self.run_script('build-admin-windows.ps1', '-DiagnoseInstall')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('synthetic install error', p.stderr)
        self.assertIn('exit 7', p.stderr)
        call = json.loads(Path(self.env['BUILD_TEST_RUN_LOG']).read_text())
        self.assertEqual(call['cwd'], str(native))
        self.assertEqual(call['args'], ['-DBUILD_TYPE=Release', '-P', 'cmake_install.cmake'])
        self.assertFalse(self.log.exists())
        self.assertFalse((self.root / 'build/freelan-space-admin-windows.zip').exists())
        cmake.write_text(cmake.read_text().replace('sys.exit(7)', 'sys.exit(0)'))
        p = self.run_script('build-admin-windows.ps1', '-DiagnoseInstall')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn('CMake install succeeded', p.stdout)
        self.assertFalse(self.log.exists())
        self.assertFalse((self.root / 'build/freelan-space-admin-windows.zip').exists())

    def test_wrong_flutter_version_stops_build(self):
        self.env['BUILD_TEST_VERSION'] = '3.40.0'
        p = self.run_script('build-user-apk.ps1')
        self.assertNotEqual(p.returncode, 0)
        self.assertIn('3.47.9', p.stderr)
        self.assertEqual(len(self.calls()), 1)


if __name__ == '__main__':
    unittest.main()
