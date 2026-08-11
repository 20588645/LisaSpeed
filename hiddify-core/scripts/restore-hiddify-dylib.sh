#!/bin/bash
set -euo pipefail
BACKUP_DIR="$HOME/Library/Application Support/hiddify-macos-tun-backup"
APP="/Applications/Hiddify.app"
LATEST=$(ls -t "$BACKUP_DIR"/hiddify-core.dylib.* 2>/dev/null | head -1)
if [[ -z "${LATEST:-}" ]]; then
  echo "No backup found in $BACKUP_DIR"; exit 1
fi
killall Hiddify 2>/dev/null || true
sleep 1
cp -f "$LATEST" "$APP/Contents/Frameworks/hiddify-core.dylib"
rm -f "$APP/Contents/MacOS/HiddifyCli"
codesign --force --sign - "$APP/Contents/Frameworks/hiddify-core.dylib"
codesign --force --deep --sign - "$APP"
echo "Restored from $LATEST"
