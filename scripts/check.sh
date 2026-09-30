#!/usr/bin/env bash
# Godot CLI smoke checks only; this is not an MCP or visual acceptance test.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .local/cache .local/data .local/config .local/checks
export XDG_CACHE_HOME="$PWD/.local/cache"
export XDG_DATA_HOME="$PWD/.local/data"
export XDG_CONFIG_HOME="$PWD/.local/config"
engine="${GODOT_BIN:-godot}"
"$engine" --headless --version
"$engine" --headless --editor --path . --quit > .local/checks/import.log 2>&1
cat .local/checks/import.log
if grep -Eq 'SCRIPT ERROR:|ERROR:' .local/checks/import.log; then exit 1; fi
"$engine" --headless --path . --quit-after 10 > .local/checks/boot.log 2>&1
cat .local/checks/boot.log
if grep -Eq 'SCRIPT ERROR:|ERROR:' .local/checks/boot.log; then exit 1; fi
if grep -q 'run/main_scene="res://scenes/integration/room.tscn"' project.godot; then
  grep -q '^SHUABAO_INTEGRATION_READY checkpoint=1$' .local/checks/boot.log
else
  grep -q '^SHUABAO_BOOT_OK$' .local/checks/boot.log
fi
printf '%s\n' 'PASS: Godot import and headless boot (not visual/MCP/export validation).'
