"""Exercise project bundle installation using synthetic native artifacts."""
from pathlib import Path
import tempfile, subprocess
workspace = tempfile.TemporaryDirectory(prefix='windows-install-')
root=Path(workspace.name) / 'project with spaces'
root.mkdir()
(root/'CMakeLists.txt').write_text((Path(__file__).resolve().parents[1] / 'windows/CMakeLists.txt').read_text())
for p in ['flutter','runner','fixtures','appbuild/native_assets/windows','appbuild/flutter_assets']:(root/p).mkdir(parents=True)
for name in ['engine.dll','icudtl.dat','plugin one.dll','plugin two.dll','app.so']:(root/'fixtures'/name).write_text('fixture')
(root/'appbuild/flutter_assets/AssetManifest.bin').write_text('assets')
(root/'flutter/CMakeLists.txt').write_text('''set(FLUTTER_LIBRARY "${CMAKE_SOURCE_DIR}/fixtures/engine.dll" PARENT_SCOPE)
set(FLUTTER_ICU_DATA_FILE "${CMAKE_SOURCE_DIR}/fixtures/icudtl.dat" PARENT_SCOPE)
set(PROJECT_BUILD_DIR "${CMAKE_SOURCE_DIR}/appbuild/" PARENT_SCOPE)
set(AOT_LIBRARY "${CMAKE_SOURCE_DIR}/fixtures/app.so" PARENT_SCOPE)
''')
(root/'runner/CMakeLists.txt').write_text('add_executable(${BINARY_NAME} main.cpp)\n')
(root/'runner/main.cpp').write_text('int main() { return 0; }')
(root/'flutter/generated_plugins.cmake').write_text('set(PLUGIN_BUNDLED_LIBRARIES "${CMAKE_SOURCE_DIR}/fixtures/plugin one.dll;${CMAKE_SOURCE_DIR}/fixtures/plugin two.dll")\n')
old_prefix = root / 'old Program Files/freelan_space'
new_prefix = root / 'build/runner/Release'
commands = [
    ['cmake', '-S', str(root), '-B', str(root/'build'), '-DCMAKE_BUILD_TYPE=Release', f'-DCMAKE_INSTALL_PREFIX:PATH={old_prefix}'],
    ['cmake', '-S', str(root), '-B', str(root/'build'), f'-DCMAKE_INSTALL_PREFIX:PATH={new_prefix}'],
    ['cmake', '--build', str(root/'build')],
    ['cmake', '--install', str(root/'build'), '--config', 'Release'],
]
for command in commands:
    subprocess.run(command, check=True, stdout=subprocess.DEVNULL)
for name in ['engine.dll', 'plugin one.dll', 'plugin two.dll', 'data/app.so', 'data/flutter_assets/AssetManifest.bin']:
    assert (new_prefix/name).is_file(), name
assert not old_prefix.exists()
print('CMake cached-prefix repair and installation with multiple plugin libraries passed')
workspace.cleanup()
