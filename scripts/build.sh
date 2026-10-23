#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
BUILD_ROOT="${BUILD_ROOT:-$ROOT/.build-local}"
DIST_ROOT="${DIST_ROOT:-$ROOT/dist}"
export CLANG_MODULE_CACHE_PATH="$BUILD_ROOT/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$BUILD_ROOT/module-cache"
mkdir -p "$BUILD_ROOT/module-cache"
swift build --disable-sandbox --scratch-path "$BUILD_ROOT/swift" -c release
BIN=$(swift build --disable-sandbox --scratch-path "$BUILD_ROOT/swift" -c release --show-bin-path)
mkdir -p "$DIST_ROOT"
STAGING=$(mktemp -d "$DIST_ROOT/.SlackAlarm-build.XXXXXX")
trap 'rm -rf "$STAGING"' EXIT
APP="$STAGING/Slack Alarm.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -X "$BIN/SlackAlarm" "$APP/Contents/MacOS/SlackAlarm"
cp -X "$BIN/SlackAlarmProbe" "$DIST_ROOT/SlackAlarmProbe"
cp -X "$ROOT/Info.plist" "$APP/Contents/Info.plist"
# Generate a 1.2-second stereo-independent mono alarm locally with Python's stdlib.
python3 - "$APP/Contents/Resources/Alarm.wav" <<'PY'
import math,struct,wave,sys
rate=44100
with wave.open(sys.argv[1],'wb') as f:
 f.setparams((1,2,rate,0,'NONE','not compressed'))
 frames=[]
 for i in range(int(rate*1.2)):
  t=i/rate; phase=t%0.6
  envelope=min(1,phase/0.015,max(0,(0.42-phase)/0.025)) if phase<0.42 else 0
  v=(math.sin(2*math.pi*880*t)+0.35*math.sin(2*math.pi*1320*t))*0.35*envelope
  frames.append(struct.pack('<h',int(32767*v)))
 f.writeframes(b''.join(frames))
PY
# Render vector artwork at every macOS icon size without a GUI session.
swiftc -parse-as-library -module-cache-path "$CLANG_MODULE_CACHE_PATH" Sources/SlackAlarm/IconArtwork.swift scripts/GenerateIcons.swift -o "$BUILD_ROOT/GenerateIcons"
"$BUILD_ROOT/GenerateIcons" "$ROOT/Assets"
cp -X "$ROOT/Assets/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# Remove only signing-incompatible Finder metadata from this newly staged bundle.
# Preserve quarantine/provenance and never change attributes on source files.
python3 - "$APP" <<'PYATTR'
import os, sys, subprocess
for directory, subdirs, files in os.walk(sys.argv[1]):
 for path in [directory] + [os.path.join(directory, name) for name in files]:
  attributes = subprocess.check_output(['/usr/bin/xattr', path], text=True).splitlines()
  for attribute in ('com.apple.FinderInfo', 'com.apple.ResourceFork'):
   if attribute in attributes:
    subprocess.run(['/usr/bin/xattr', '-d', attribute, path], check=True)
PYATTR
# Override SIGN_IDENTITY with your stable local/Developer ID certificate.
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
codesign --verify --strict "$APP"
# Never overwrite a signed/running Mach-O inode in place.
FINAL_APP="$DIST_ROOT/Slack Alarm.app"
if [ -d "$FINAL_APP" ]; then
    mv "$FINAL_APP" "$BUILD_ROOT/previous-SlackAlarm-$(date +%Y%m%d-%H%M%S)-$$.app"
fi
mv "$APP" "$FINAL_APP"
codesign --verify --strict "$FINAL_APP"
echo "Built: $FINAL_APP"
