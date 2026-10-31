#!/usr/bin/env bash
# Build and inspect a disposable iOS host; no application checkout is modified.
set -euo pipefail

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'The iOS host check requires macOS and Xcode.' >&2
  exit 1
fi

package_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
for command_name in flutter python3 xcodebuild xcrun; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command is missing: $command_name" >&2
    exit 1
  fi
done

python3 - <<'PY'
import re
import subprocess

xcode = subprocess.check_output(['xcodebuild', '-version'], text=True)
sdk = subprocess.check_output(
    ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], text=True,
).strip()
version = re.search(r'^Xcode (\d+)\.(\d+)', xcode, re.MULTILINE)
sdk_version = re.match(r'^(\d+)\.(\d+)', sdk)
if not version or tuple(map(int, version.groups())) < (27, 1):
    raise SystemExit('Xcode 27.1 or newer is required for verticalBarEdge.')
if not sdk_version or tuple(map(int, sdk_version.groups())) < (27, 1):
    raise SystemExit('The iOS Simulator SDK must be 27.1 or newer.')
print(xcode.strip())
print(f'iOS Simulator SDK {sdk}')
PY

duo_host_tmp="$(mktemp -d "${TMPDIR:-/tmp}/duo-rail-kit-host.XXXXXX")"
cleanup() {
  rm -rf -- "$duo_host_tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
host_root="$duo_host_tmp/host"

flutter create --empty --no-pub --platforms=ios \
  --project-name duo_rail_kit_host --org com.example "$host_root"

python3 - "$package_root" "$host_root" <<'PY'
import json
from pathlib import Path
import shutil
import sys

package_root = Path(sys.argv[1])
host_root = Path(sys.argv[2])
# A JSON string is also a YAML scalar; paths with spaces remain valid.
dependency_path = json.dumps(str(package_root))
(host_root / 'pubspec.yaml').write_text(f'''name: duo_rail_kit_host
publish_to: 'none'
version: 1.0.0+1
environment:
  sdk: ^3.12.0
dependencies:
  duo_rail_kit:
    path: {dependency_path}
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
  config:
    enable-swift-package-manager: true
''')
shutil.copytree(package_root / 'example/lib', host_root / 'lib', dirs_exist_ok=True)
PY

(
  cd "$host_root"
  flutter pub get
  flutter build ios --simulator --debug --no-codesign
)

python3 - "$host_root" <<'PY'
from pathlib import Path
import re
import subprocess
import sys

host_root = Path(sys.argv[1])
registrant = (host_root / 'ios/Runner/GeneratedPluginRegistrant.m').read_text()
registration = re.compile(
    r'\[DuoRailKitPlugin\s+registerWithRegistrar:\s*'
    r'\[registry\s+registrarForPlugin:@"DuoRailKitPlugin"\]\s*\]',
)
if not registration.search(registrant):
    raise SystemExit('GeneratedPluginRegistrant does not register DuoRailKitPlugin.')

manifest = host_root / 'ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift'
if not manifest.is_file() or '.product(name: "duo-rail-kit", package: "duo_rail_kit")' not in manifest.read_text():
    raise SystemExit('The generated Flutter SPM manifest does not link duo-rail-kit.')

app = host_root / 'build/ios/iphonesimulator/Runner.app'
if not app.is_dir():
    raise SystemExit('The simulator app bundle is missing.')

# Xcode may place app code in Runner.debug.dylib instead of the Runner launcher.
# -U excludes undefined references, so merely mentioning the class is not enough.
symbols = []
for candidate in (app / 'Runner', *app.rglob('*.dylib'), *app.glob('Frameworks/*.framework/*')):
    if not candidate.is_file():
        continue
    result = subprocess.run(['xcrun', 'nm', '-gU', str(candidate)], text=True, capture_output=True)
    if result.returncode == 0:
        symbols.extend(result.stdout.splitlines())
plugin_symbols = [line for line in symbols if 'DuoRailKitPlugin' in line]
if not any('OBJC_CLASS' in line for line in plugin_symbols):
    raise SystemExit('The built app has no defined DuoRailKitPlugin Objective-C class.')
if not any('register' in line for line in plugin_symbols):
    raise SystemExit('The built app has no defined DuoRailKitPlugin registration method.')
print('PASS: generated SPM dependency and plugin registration are present.')
print('PASS: the built simulator app defines the plugin class and registration method.')
print('This checks compilation/linking; it does not exercise device UI or native events.')
PY
