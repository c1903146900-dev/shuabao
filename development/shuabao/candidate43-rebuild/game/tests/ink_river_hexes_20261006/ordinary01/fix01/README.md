# ordinary01 fixture-only accepted-time fix01

SOURCE ONLY until this exact binding runs. The runtime Sim, H04 projection/view, Host/Session, fixed-step loop, EPS and the current default entries are unchanged. The original133-check/four-group two-red result and prefix diagnostic remain frozen.

The author directly read `loot_recovery_1041/river_ordinary_time_diagnostic01_actual/verified.json` and `COMPLETED.json`. The original first request was0.25 seconds once. Actual source/world time advanced0→0.24, core/clock counters advanced12, and0.01 remained in `real_accumulator`. H04 reported born0, source0.24, remaining3.76, radius3.35 and phase0.48. The original expected3.34375/0.5 assertions failed because they treated requested real time as already accepted source time. The diagnostic is a prefix observation, not a whole-group or candidate pass.

The fixture still requests `step(0.25)`, then the same pause/`step(0.3)`/resume/`step(0.25)` in the same order. No step was added or resized. Instead of replacing bad constants with observed3.35/0.48, it now:

- Records actual before/after source/world clocks, core/clock steps and accumulator
- Independently checks complete20ms budget admission and conservation of the unadmitted remainder
- Computes source age from the actual snapshot `source_time − born_at`
- Checks the formal radius as `3.5 − (3.5 − 1) × age / 4`, and phase as the fractional part of `age / 0.5`; also checks remaining duration
- Verifies pause preserves the already queued remainder and resume consumes it together with the unchanged second request

These are additional fixture assertions/readbacks only. The near helper and its tolerance are unchanged. `verify_source.py` reverses the exact replacement block and report identity fields, then requires the entire original finite script byte-for-byte; it also requires all `sim.step(...)` calls in the same sequence.

The original four groups remain, with146 checks expected for the unchanged allocator seeds. The local strict gate additionally requires the recorded accepted-time evidence and verifies budget conservation. Ordinary native UI, natural clear, full floor, final art/audio and real multiplayer are still unverified; no default cutover is authorized.

Coordinator-owned commands:

`python3 tests/ink_river_hexes_20261006/ordinary01/fix01/stage_delta.py --dest <current-ordinary01-stage> --apply --receipt <stage.json>`

`godot --headless --audio-driver Dummy --path <stage> --script res://tests/ink_river_hexes_20261006/ordinary01/fix01/parse_gate.gd`

`godot --headless --audio-driver Dummy --path <stage> --script res://tests/ink_river_hexes_20261006/ordinary01/fix01/finite_gate.gd -- --river-ordinary-result=<result.json>`

Use this directory's `raw_error_gate.py` with the unchanged binding/parse-raw/parse-exit/finite-raw/finite-exit/finite-report/output argument contract. Existing serialized resource controls remain in force. The author has not started software.
