#!/bin/bash
# Screenshot a prototype page with headless Chrome (offline-safe).
# usage: ./shoot.sh <src-html> <out-png> [inline-js] [query]
#   query example: "?conn=connected&appearance=light&page=nodes"
set -euo pipefail
SRC="$1"; OUT="$2"; JS="${3:-}"; QUERY="${4:-}"
DIR="$(cd "$(dirname "$0")" && pwd)"
SHOTS="$DIR/../.shots"
mkdir -p "$SHOTS"
TMP="$SHOTS/_tmp_shot.html"

python3 - "$SRC" "$TMP" "$JS" <<'PY'
import sys, re, pathlib
src, tmp = sys.argv[1], sys.argv[2]
js = sys.argv[3] if len(sys.argv) > 3 else ""
p = pathlib.Path(src).resolve()
html = p.read_text(encoding="utf-8")
# Strip remote font links so offline shots never stall on the network.
html = re.sub(r'\s*<link[^>]*fonts\.(googleapis|gstatic)\.com[^>]*/>', "", html)
base = p.parent
html = html.replace('href="css/', f'href="{base}/css/')
html = html.replace('src="../shared/', f'src="{base.parent}/shared/')
if js:
    html = html.replace("</body>", f"<script>{js}</script></body>")
pathlib.Path(tmp).write_text(html, encoding="utf-8")
PY

# This Chrome build finishes the screenshot but never exits, so run it in
# the background and reap it once the PNG lands.
rm -f "$OUT"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars --no-first-run \
  --user-data-dir="$SHOTS/_profile" --window-size=1280,880 \
  --virtual-time-budget=6000 --timeout=15000 \
  --screenshot="$OUT" "file://$TMP$QUERY" >/dev/null 2>&1 &
CHROME_PID=$!
for _ in $(seq 1 60); do
  [ -s "$OUT" ] && break
  sleep 0.5
done
sleep 1
kill "$CHROME_PID" 2>/dev/null || true
wait "$CHROME_PID" 2>/dev/null || true
ls -la "$OUT"
