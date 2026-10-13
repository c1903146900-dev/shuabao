# ownership01 fixture-only fix01

SOURCE ONLY until this binding is actually parsed and run. The ownership01 runtime Sim, P2 history contract, original134-check red evidence, diagnostic evidence, technical sampler/input and ordinary production entries remain unchanged.

## Observed cause, not an assumed cleanup bug

The author directly read `loot_recovery_1041/river_ownership01_diagnostic01_actual/result.json` and `verified.json`. The original live-combat `begin_encounter` returned `{accepted:false, reason:invalid_phase}`; generation stayed1, P2 use records stayed5, and P1 roots, pending splash work, H04 packet frames and P2 packet frames were all0. The diagnostic preserved the original0.5/0.02 steps and returned exit1 for the original assertion. It is diagnostic evidence, not a candidate PASS.

`hero_combat_core.gd:89` rejects beginning an encounter while phase is combat. The old fixture discarded that return value and asserted room retirement even though no transition occurred. P2 deliberately retains completed/cancelled use records after consumption; changing or clearing that history would corrupt its existing anti-repeat contract.

## Only the fixture changes

The four groups, runtime Sim preload, all existing mechanism cases and the final P2 pause/resume sequence remain identical. The old two-line invalid transition assertion is replaced by:

1. Keep the live-combat reopen attempt as an explicit rejection/no-state-change case, including full retained use-record equality
2. Call the real `end_encounter("cleared")`, as existing P2 mechanism fixtures do; check ended phase and old scope, then separately check roots, use history, pending splash and frame cleanup
3. Call `begin_encounter` after the real end; require acceptance and exactly one generation increment, then separately check every retired collection/stack

This is an encounter lifecycle fixture, not a fabricated victory or kill. There is no direct phase assignment, manual collection clear, extra step, runtime Sim change or P2 rule change. `scope_state` only reads fields. `verify_source.py` reconstructs the entire old finite script by undoing the precise fixture edit and read-only helper/report-binding changes, then compares it byte-for-byte to the frozen parent.

The original134-check red and the original diagnostic remain intact. The new four-group gate is expected to contain150 assertions, but no runtime pass is claimed until actual evidence exists.

## Coordinator-owned CLI

Stage only the additive fix files over the exact existing ownership01 stage:

`python3 tests/ink_river_hexes_20261006/ownership01/fix01/stage_delta.py --dest <current-stage> --apply --receipt <stage.json>`

Parse:

`godot --headless --audio-driver Dummy --path <current-stage> --script res://tests/ink_river_hexes_20261006/ownership01/fix01/parse_gate.gd`

Four groups:

`godot --headless --audio-driver Dummy --path <current-stage> --script res://tests/ink_river_hexes_20261006/ownership01/fix01/finite_gate.gd -- --river-ownership-result=<result.json>`

Run the local `raw_error_gate.py` with the same binding/parse-raw/parse-exit/finite-raw/finite-exit/finite-report/output arguments. It requires exact source binding, all groups, at least150 checks, zero raw errors, real exit-zero/reaped processes, and the actual rejected/accepted room-transition evidence. The existing serialized resource limits apply; the author started no software.

Ordinary Hex pool/Session/UI, native input, full floor, art/audio and real multiplayer remain outside this fix.
