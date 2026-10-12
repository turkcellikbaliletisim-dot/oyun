#!/usr/bin/env bash
set -euo pipefail
destan_install_dir="${1:-/workspace/tools/godot-4.6.3}"
mkdir -p "$destan_install_dir"
destan_archive="$destan_install_dir/Godot_v4.6.3-stable_linux.x86_64.zip"
curl --fail --location --retry 3 --output "$destan_archive" https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip
printf '%s  %s\n' 'a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c' "$destan_archive" | sha512sum --check
unzip -o "$destan_archive" -d "$destan_install_dir"
mv "$destan_install_dir/Godot_v4.6.3-stable_linux.x86_64" "$destan_install_dir/godot"
chmod +x "$destan_install_dir/godot"
rm "$destan_archive"
mkdir -p "$destan_install_dir/cache"
XDG_CACHE_HOME="$destan_install_dir/cache" "$destan_install_dir/godot" --headless --version
