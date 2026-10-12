#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v node >/dev/null; then
  echo "Node.js 22 veya üstünü kurup yeniden çalıştır."
  exit 1
fi
node --input-type=module -e 'if(Number(process.versions.node.split(".")[0])<22)process.exit(1)'
destan_godot_bin="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
if [ ! -x "$destan_godot_bin" ]; then
  echo "Godot 4.6.x uygulamasını /Applications/Godot.app konumuna koy veya GODOT_BIN yolunu ayarla."
  exit 1
fi
destan_server_pid=""
cleanup() {
  if [ -n "$destan_server_pid" ]; then
    kill "$destan_server_pid" 2>/dev/null || true
    wait "$destan_server_pid" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM
if ! node --input-type=module -e 'try{const r=await fetch("http://127.0.0.1:8080/api/health");const d=await r.json();if(!r.ok||d.ready!==true||d.version!=="0.2")process.exit(1)}catch{process.exit(1)}'; then
  node server/http.js &
  destan_server_pid=$!
  for destan_attempt in 1 2 3 4 5; do
    if node --input-type=module -e 'try{const r=await fetch("http://127.0.0.1:8080/api/health");const d=await r.json();if(!r.ok||d.ready!==true||d.version!=="0.2")process.exit(1)}catch{process.exit(1)}'; then
      break
    fi
    if ! kill -0 "$destan_server_pid" 2>/dev/null; then
      echo "Sunucu başlayamadı. 8080 portunu ve .data kaydını kontrol et."
      exit 1
    fi
    sleep 1
  done
fi
if ! node --input-type=module -e 'try{const r=await fetch("http://127.0.0.1:8080/api/health");const d=await r.json();if(!r.ok||d.ready!==true||d.version!=="0.2")process.exit(1)}catch{process.exit(1)}'; then
  echo "Destan sunucusu hazır değil. Terminaldeki sunucu mesajını kontrol et."
  exit 1
fi
"$destan_godot_bin" --editor --path "$PWD"
