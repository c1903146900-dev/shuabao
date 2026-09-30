#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export XDG_CACHE_HOME="$PWD/.local/cache"
export XDG_CONFIG_HOME="$PWD/.local/config"
export XDG_DATA_HOME="$PWD/.local/data"
mkdir -p .local/combat-checks
godot --headless --path . --script tests/combat/runner.gd | tee .local/combat-checks/tests.log
godot --headless --path . --script tests/combat/qa002_run.gd | tee .local/combat-checks/room-callbacks.log
