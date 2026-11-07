# Opposite wave and active-release lifecycle observer

Prepared source only: `observe_wave_lifecycle.gd`. It targets the isolated Boss candidate that includes the Boss body receipt and release cache. The accepted combo13 baseline alone does not contain those additions. No engine, GUI, production source, pack or guard was changed by this preparation.

## Single bounded route

The nine input, route, H08 draft, growth and potion helpers are preserved from the previously live-tested strict cancellation observer. Boss-phase input stops player attacks. The observer uses normal movement keys and enabled UI button signals through existing input/UI handlers, not OS input, restored fixtures or simulation writes.

The actual session resets room entry to (0,0,10), and the authored Boss roster starts at (0,0,-10). Preparation movement cannot set the Boss approach position. The original direct side target at (5.8,0,10) was inside the southeast parapet. The revised observer first walks 1.8 units forward through the central opening, then sideways 5.8 units. It checks both intended segments against current source geometry and logs the live positions. This is navigation only: the moving Boss may warn before either waypoint is reached, and an actually qualifying horizontal warning is accepted immediately. At most one early nonhorizontal wave and its mandatory sweep may be used for positioning, with their own ordered source evidence and no mirror/pose credit. A second nonhorizontal candidate fails. Later horizontal destinations and sweep waypoints are chosen from a finite set of current geometry-checked clear points/segments. If none is reachable by that bounded plan, the observer reports the positions and stops instead of steering indefinitely into an obstacle. No route is restarted.

0. If the first warning is nonhorizontal, retain its actual warning, release, positive advance and finish under a separate uncredited record. Dodge normally, allow and record its required sweep warning/impact, and reposition. These events cannot satisfy any credited wave or capture requirement.
1. Wave 1 must have a genuine current-scope enemy_warning with boss_cast_id and at least 4 projected pixels of horizontal direction per world unit. Walk to that cast's existing escape destination with normal controls. Require the matching boss_wave_released, positive boss_wave_advanced, actual current front in the post-draw receipt, correct signed warning/release poses, neutral settle, and boss_wave_finished.
2. Allow the source-mandated intervening cone sweep. Require its own warning and later enemy_impact, including a legitimate miss. During its warning/recovery, walk around a lateral waypoint to the opposite side. The observer does not alter force_sweep or cadence.
3. Wave 2 must have the opposite projected horizontal sign, its own cast identity, real release and positive front movement. Require warning and actual release captures with the expected opposite lean and shared squash/stretch values. This proves both directions for waves, not merely a sweep in the other direction.
4. Immediately after the second wave's validated post-draw release capture, press the real Return to Menu button while release age is below 0.28 world seconds. Menu must hide/suspend the same room, retain that same cache record, keep combat open, and freeze world time. Menu is not expected to clear the cache.
5. Use the actual Start New Run button and then the actual confirmation button. Require the old source encounter_finished with result host_closed, status aborted, and an empty Boss cache at that terminal event. Require the old host, sim, session and presentation weak references to expire. On the new run, require all four new identities, a fresh run/scope, visible initial draft, empty Boss cache and no old Boss pose/front/warning in two distinct post-draw frames.

## Bounds and output

One route, no restarts; at most one optional uncredited positioning wave/sweep, then exactly two credited waves and their intervening sweep. Total timeout 550 seconds, Boss section 50 seconds, lifecycle section 20 seconds. At most seven saved images: wave1 windup/release/settled, wave2 windup/release, paused menu, fresh initial UI. Per-image capture requests are bounded. Source logs retain warnings/releases, first positive advances, wave1 finish, intervening sweep, and actual retirement evidence, not every frame or wave advance. Runtime output is created under the game's user data directory; source artifacts contain no private fixture, log or image content.

Success marker: BOSS_WAVE_DIRECTIONS_LIFECYCLE_PASS. Failure marker: BOSS_WAVE_FAIL with the precise incomplete stage/evidence. Static source checks are in `wave_lifecycle_static.json`; they are not a GDScript parser or a live pass. The parent must parse and run the exact frozen script with the existing guard unchanged.

## Preserved failed attempt

The original observer SHA-256 097d3c957f0d946846c94570c7f92abd4d46bb6289bacd377fe1bfa029affec8 reached the Boss but exited 9 on first_warning_before_lateral_approach_completed. It produced no wave/capture evidence. The guard stayed within its limit (maximum gap about 0.0561 seconds); this was an observer failure, not an environmental failure. The initial warning direction was not recorded, so the run does not establish a nonhorizontal direction failure. Its frozen source remains with that run; no claim is upgraded by this revision.

The corrected source removes that navigation-completion gate, adds real warning diagnostics before direction classification, routes around the identified obstacle, and permits one strictly uncredited positioning cycle. The two credited signed wave poses, actual source/front identities, settle, active-release timing and new-run cleanup conditions remain unchanged. No further run was launched here.

## Coverage limits

This run intentionally aborts the old Boss fight to test active-release cleanup. It does not prove a Boss kill/full-floor win, cancellation, menu resume, OS input, exact pixel picking, damage correctness, all attack directions, or the second wave's completed trajectory/settle. The first wave must finish and settle; the second is deliberately retired while active. It may fail from ordinary route survival, navigation, a missed direction/window, source drift, parse/runtime errors, or unchanged external guard limits. A failure is not a production defect without inspecting the evidence.

## Source references

- `__clean_fengli/entry.gd`: open_menu/_finish_open_menu suspend the same room; request_start shows CONFIRM; confirm_new_run/_launch_fresh close and free the old room before adding a fresh one.
- `fengli_route_20261024/host.gd`: frontdoor_can_suspend checks the native transaction boundary; frontdoor_close_run delegates to session.close_run.
- `fengli_route_20261024/session.gd`: room arrival reset and normal authored roster admission; close_run delegates to the coordinator.
- `tests/ink_first_floor_flow_20261004/floor_coordinator.gd`: close_run sets aborted before source end_encounter(host_closed).
- `scripts/combat/hero_combat_core.gd`: end_encounter invalidates transients and emits the actual terminal event.
- `fengli_route_20261024/boss_wave.gd`: warning/release/advance/finish/cancel identities, real escape destination, and forced sweep interleave.

Warning snapshot timing was reviewed directly: boss_wave.commit assigns _casts and _owners, sets the warning state and geometry, then emits enemy_warning. The observer reads that already-registered source snapshot; it does not manufacture a cast or defer until a guessed state.
