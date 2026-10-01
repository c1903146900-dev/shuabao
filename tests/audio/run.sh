#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export XDG_CACHE_HOME="$PWD/.local/cache"
export XDG_CONFIG_HOME="$PWD/.local/config"
export XDG_DATA_HOME="$PWD/.local/data"
mkdir -p tests/audio/evidence "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME"
python3 tests/audio/analyze.py
# Isolated minimal project: avoid generating unrelated source import sidecars.
python3 - <<'PY'
from pathlib import Path
import shutil
root=Path.cwd(); target=root/'.local/audio-headless'
target.mkdir(parents=True,exist_ok=True)
for folder in ['assets/audio','scripts/audio','scenes/audio','tests/audio']:
    shutil.copytree(root/folder,target/folder,dirs_exist_ok=True,ignore=shutil.ignore_patterns('evidence','__pycache__'))
(target/'project.godot').write_text('config_version=5\n[application]\nconfig/name="Combat audio checks"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
PY
godot --headless --editor --path .local/audio-headless --import > tests/audio/evidence/import.log 2>&1
godot --headless --path .local/audio-headless --audio-driver Dummy --script res://tests/audio/runner.gd 2>&1 | tee tests/audio/evidence/runtime.log
