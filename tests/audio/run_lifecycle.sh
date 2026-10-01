#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
bash tests/audio/run.sh
export XDG_CACHE_HOME="$PWD/.local/cache" XDG_CONFIG_HOME="$PWD/.local/config" XDG_DATA_HOME="$PWD/.local/data"
mkdir -p tests/audio/evidence/lifecycle
godot --headless --verbose --path .local/audio-headless --audio-driver Dummy --script res://tests/audio/native_exit_probe.gd > tests/audio/evidence/lifecycle/native-immediate.log 2>&1
godot --headless --verbose --path .local/audio-headless --audio-driver Dummy --script res://tests/audio/native_exit_probe.gd -- --drain > tests/audio/evidence/lifecycle/native-drained.log 2>&1
godot --headless --path .local/audio-headless --audio-driver Dummy --script res://tests/audio/lifecycle_runner.gd > tests/audio/evidence/lifecycle/cycles.log 2>&1
python3 tests/audio/verify_lifecycle.py
