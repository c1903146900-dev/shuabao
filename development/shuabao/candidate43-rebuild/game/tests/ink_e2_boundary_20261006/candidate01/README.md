# E2 room-boundary parking candidate01 (source only)

This independent **base E2** successor extends `tests/ink_e2_ordinary_20261005/fix01/sim.gd`. It preserves that exact callback-pause continuation and the queued E input's original-boat ownership. It does not extend, replace, or enable the current P1/R1/E1 ordinary chain. H09/H10 remain locked. Nothing in this directory is an engine, ordinary-entry, native-input or art/audio acceptance result.

## Source and exact geometry

Authority: `docs/source_decisions/20261006-ink-five-resolutions.json`, SHA256 `861528d850389b2b4be2ce7a9ad4461531bbbfbd33de113870f9955b721f3e39`, plus the preserved 10-05 solid-wall/precise-landing decision. Original E2 is DOCX paragraph 75 (all-document paragraph enumeration) and XLSX `晏归舟技能!E45:J57`. Readback confirms all six ranks have front width 1.1m; speed, lifetime, damage and cooldown still come exclusively from the unchanged tuning table.

The shared room is the closed XZ square `[-arena_half_extent,+arena_half_extent]`, default half extent 22m. The core's hero-center box `half_extent - hero_radius` (default radius .65m) is a separate landing constraint, **not** the room's physical edge. E2 has no independently specified boat-body collider; its existing gameplay geometry is a moving full-width front. This candidate therefore parks at the first contact of either end of that real 1.1m front with the physical square. Per axis, front-center bounds are `half_extent - abs(side_axis)*width/2`, with no added EPS and no inward gap. This is the explicitly recorded implementation convention, not a new quoted source dimension.

A cardinal boat center can reach the physical edge; a diagonal front reaches it with its tip first. The trajectory never slides after first contact. An initial front already outside the room is rejected as `initial_boat_front_outside_room`, consumes no root/cooldown and is never projected inward. The fresh-launch path no longer uses projected full-route rejection. An inherited historical helper containing `arena_route_outside_fixture` remains untouched in the frozen ancestor; this leaf does not call that path for a valid fresh E2 launch.

Exact hero landing stays inherited and independent: an edge point with no room for the hero is rejected as `illegal_current_boat_landing`, preserving the same boat and hero position. The boat can cross solid walls; a current point inside a wall rejects boarding while a later legal current point can still be boarded. No boat parking coordinate is changed to make boarding convenient.

## Time, contact and pause seam

`boat_boundary.gd` provides a pure front/room plan. `sim.gd` installs it before the launched callback, and modifies only fresh-launch geometry, outward position advancement, completed-outward time reconciliation, and the public boundary fields.

The plan's `motion_until` is the real spatial arrival time. The original `voyage_until` is unchanged. If a tick reaches the boundary early, the sweep's `work.end` is the actual arrival time, preserving each contact's source timestamp. `state.boundary_clock_target` separately preserves the entire already-admitted source interval. `_e2_outward_finished` consumes that clock target after the final old contact drains, including the parent's pause/resume path, before fix01 resolves a queued E. No extra world/core tick runs during local drainage.

While parked, the inherited stationary-front query, dynamic enemy-motion observer and one-hit-per-target ledger remain. Repeated parked frames cannot farm the same outward hit. No new periodic damage, early burst, cooldown restart, lifetime reset, or indefinite persistence is introduced. At the original deadline, the inherited original natural burst occurs at the actual parked endpoint. Global pause freezes the existing source/CD clocks; callback pause retains already admitted work and time.

## Limited gates and later integration

`parse_gate.gd` loads only the new helper, sim and finite gate. `finite_gate.gd` authors five focused groups: four edges/corner/oblique first contact; invalid initial front and exact legal/illegal wall boarding; parked dynamic contact/once-per-target/clock/CD/expiry; final partial-sweep callback pauses and queued-E ownership; paused natural settlement and H09/H10 locks. It does not rerun the historical full E2 matrix or promote its historical 112+46 checks.

Future composition must deliberately transplant these geometry/time seams onto the then-current P1/R1/E1 chain, retain that chain's completion metadata and pause ownership, and run affected combined gates before ordinary E2 admission. H09 may later consume only `traveled_route`; H10 may later replace the original deadline branch at the actual parked point. Neither personal Hex is implemented or admitted here.

The room-size mutation diagnostic remains inherited and outside this fixed-room candidate. Native E input, UI feedback for illegal landing, rendering, sound, current ordinary chain and H09/H10 need separate verification. No AGENTS.md was found in the project or its applicable workspace ancestors.

## Stage and validation

`source_binding.json` pins authoring files, original sources, decisions, exact selected ancestors and current production sentinels. `stage_manifest.json` explicitly maps each logical runtime path to its source and SHA256; frozen ancestor mappings are resolved as source mappings, not by assuming the target's current repository bytes. `prepare_stage.py` audits before copying to a fresh separate stage, verifies every copied file, and never runs an engine. `source_audit.py` verifies Python syntax, bindings and the resource closure; it does not parse GDScript.

Coordinator-only sequence after reviewing the source:

1. Run `python3 tests/ink_e2_boundary_20261006/candidate01/source_audit.py`
2. Run `python3 tests/ink_e2_boundary_20261006/candidate01/prepare_stage.py --stage <fresh-separate-stage>`
3. In the stage, run `parse_gate.gd` under the approved supervised Godot wrapper
4. If clean, run `finite_gate.gd` with `-- --boundary-result=<fresh-result.json>`
5. Require clean raw engine/process logs, successful exit, exact source/stage binding, and the new finite result; do not accept a printed PASS alone

Author-side engine parse, finite runtime, Godot, Blender, CUA and uploads: **NOT RUN**. Author-side checks are source-only.
