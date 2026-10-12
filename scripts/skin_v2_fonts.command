#!/bin/sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
CACHE_ROOT=${XDG_CACHE_HOME:-"$HOME/.cache"}
ENV_DIR="$CACHE_ROOT/destan-diyarlari-font-tools-v2"
if ! command -v python3 >/dev/null 2>&1; then
  printf '%s\n' 'Python 3 is required to install the fonts.' >&2
  exit 1
fi
if [ ! -x "$ENV_DIR/bin/python" ]; then
  python3 -m venv "$ENV_DIR"
fi
"$ENV_DIR/bin/python" -m pip install --disable-pip-version-check 'fonttools>=4.60,<5'
"$ENV_DIR/bin/python" "$SCRIPT_DIR/skin_v2_fonts.py" "$@"
