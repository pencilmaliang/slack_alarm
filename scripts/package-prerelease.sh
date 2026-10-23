#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUTPUT="${RELEASE_OUTPUT:-$ROOT/release-assets}"
mkdir -p "$OUTPUT"
OUTPUT=$(cd "$OUTPUT" && pwd)
STAGING=$(mktemp -d /private/tmp/SlackAlarm-prerelease.XXXXXX)
trap 'rm -rf "$STAGING"' EXIT
# Explicitly use ad-hoc signing: this script does not use certificates or notarization.
SIGN_IDENTITY=- DIST_ROOT="$STAGING/dist" ./scripts/build.sh
python3 - "$ROOT" "$STAGING" "$OUTPUT" <<'PY'
from pathlib import Path
import hashlib, os, plistlib, subprocess, sys, zipfile
root, staging, output = map(Path, sys.argv[1:])
info = plistlib.loads((root / 'Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
assert version == '1.1.2', 'Update release docs and beta version before packaging a new app version.'
release = version + '-beta.1'
app = staging / 'dist/Slack Alarm.app'
binary = app / 'Contents/MacOS/SlackAlarm'
arch = subprocess.check_output(['/usr/bin/lipo', '-archs', str(binary)], text=True).strip()
assert arch == 'arm64', 'This release is documented as arm64 only; update packaging and docs for another architecture.'
archive = output / f'SlackAlarm-{release}-macOS-arm64.zip'
with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for p in sorted(app.rglob('*')):
        if p.is_file():
            z.write(p, Path(app.name) / p.relative_to(app))
    z.write(root / 'docs/INSTALL.md', 'INSTALL.md')
    z.write(root / 'LICENSE', 'LICENSE')
check = staging / 'archive-check'
subprocess.run(['/usr/bin/unzip', '-q', str(archive), '-d', str(check)], check=True)
subprocess.run(['/usr/bin/codesign', '--verify', '--strict', str(check / app.name)], check=True)
assert os.access(check / app.name / 'Contents/MacOS/SlackAlarm', os.X_OK)
source = output / f'SlackAlarm-{release}-source.zip'
with zipfile.ZipFile(source, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for name in ['Sources', 'Tests', 'scripts', 'Assets', 'docs', '.github',
                 'Package.swift', 'Info.plist', 'README.md', 'README.zh-CN.md',
                 'LICENSE', '.gitignore', 'CHANGELOG.md']:
        item = root / name
        for p in sorted(item.rglob('*')) if item.is_dir() else [item]:
            if p.is_file() and p.name != '.DS_Store':
                z.write(p, Path('Slack Alarm') / p.relative_to(root))
digest = hashlib.sha256(archive.read_bytes()).hexdigest()
(output / 'SHA256SUMS.txt').write_text(f'{digest}  {archive.name}\n')
print(f'App: {archive}\nSource: {source}\nChecksum: {output / "SHA256SUMS.txt"}')
PY
