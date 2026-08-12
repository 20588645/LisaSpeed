#!/bin/bash
set -euo pipefail
SRC="${PROJECT_DIR}/../hiddify-core/bin/HiddifyCli"
DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/MacOS/HiddifyCli"
if [[ -f "$SRC" ]]; then
  cp -f "$SRC" "$DEST"
  chmod +x "$DEST"
  echo "Copied HiddifyCli -> $DEST"
else
  echo "warning: HiddifyCli not found at $SRC (VPN tunnel helper will be missing)" >&2
fi
