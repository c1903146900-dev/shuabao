#!/usr/bin/env bash
# Actual exports, not MCP export command generation. No deployment or server networking.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p .local/cache .local/data .local/config .local/export-evidence build/windows build/linux
export XDG_CACHE_HOME="$PWD/.local/cache" XDG_DATA_HOME="$PWD/.local/data" XDG_CONFIG_HOME="$PWD/.local/config"
godot --headless --editor --path . --quit > .local/export-evidence/import.log 2>&1
godot --headless --path . --export-release 'Windows Smoke' > .local/export-evidence/windows-export.log 2>&1
godot --headless --path . --export-release 'Linux Headless Smoke' > .local/export-evidence/linux-export.log 2>&1
for artifact in build/windows/shuabao-smoke.exe build/windows/shuabao-smoke.pck build/linux/shuabao-headless.x86_64 build/linux/shuabao-headless.pck; do test -s "$artifact"; done
file build/windows/shuabao-smoke.exe build/linux/shuabao-headless.x86_64 > .local/export-evidence/file-types.txt
# Run from outside the source tree with no display and no explicit --headless;
# the dedicated_server feature in the Linux export must select headless itself.
app_path="$PWD/build/linux/shuabao-headless.x86_64"
(cd /tmp && env -u DISPLAY -u WAYLAND_DISPLAY "$app_path" --quit-after 10) > .local/export-evidence/linux-boot.log 2>&1
grep -q 'SHUABAO_INTEGRATION_READY checkpoint=1' .local/export-evidence/linux-boot.log
if grep -Eq 'SCRIPT ERROR:|ERROR:' .local/export-evidence/linux-boot.log; then cat .local/export-evidence/linux-boot.log; exit 1; fi
sha256sum build/windows/shuabao-smoke.exe build/windows/shuabao-smoke.pck build/linux/shuabao-headless.x86_64 build/linux/shuabao-headless.pck > .local/export-evidence/SHA256SUMS
python3 scripts/export/audit.py
printf '%s\n' 'PASS: two real exports, PE/ELF inspection and standalone Linux boot. Windows execution NOT RUN.'
