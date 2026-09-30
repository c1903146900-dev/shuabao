#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
export XDG_CACHE_HOME="$PWD/.local/qa-cache"
export XDG_CONFIG_HOME="$PWD/.local/qa-config"
export XDG_DATA_HOME="$PWD/.local/qa-data"
# ledger/progression probes read the exact sibling checkout; never copy its implementation.
godot --headless --path . --script tests/qa/combat_probe.gd
godot --headless --path . --script tests/qa/progression_probe.gd
godot --headless --path . --script tests/qa/ledger_probe.gd
