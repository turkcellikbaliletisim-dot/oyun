#!/bin/bash
set -euo pipefail
# Finder does not always inherit Homebrew's PATH.
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")/.."
destan_godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$destan_godot_bin" ]; then
  echo "Godot uygulamasını /Applications/Godot.app konumuna koy veya GODOT_BIN yolunu ayarla."
  exit 1
fi
if ! command -v node >/dev/null; then
  echo "Node.js 22 veya üstünü kurup yeniden çalıştır."
  exit 1
fi
node --input-type=module -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)'
destan_health() {
  node --input-type=module -e 'try{const r=await fetch("http://127.0.0.1:8080/api/health",{signal:AbortSignal.timeout(1500)});const d=await r.json();if(!r.ok||d.ready!==true||d.version!=="0.2")process.exit(1)}catch{process.exit(1)}'
}
if ! destan_health; then
  if command -v docker >/dev/null && docker info >/dev/null 2>&1; then
    docker compose up --build -d --wait server
  else
    mkdir -p .data
    nohup node server/http.js >> .data/server.log 2>&1 < /dev/null &
  fi
fi
for destan_attempt in {1..20}; do
  if destan_health; then break; fi
  sleep 1
done
if ! destan_health; then
  echo "Oyun sunucusu başlayamadı. Docker günlüklerini veya .data/server.log dosyasını kontrol et."
  exit 1
fi
# Every F5 game launched from this editor inherits the stable address.
# The server keeps running after the editor or Terminal closes.
export DESTAN_SERVER_URL="http://127.0.0.1:8080"
if [ "${1:-}" = "--mobile" ]; then
  "$destan_godot_bin" --path "$PWD" --resolution 1024x576
else
  "$destan_godot_bin" --editor --path "$PWD"
fi
