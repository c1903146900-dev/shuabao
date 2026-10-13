# Continuous original zero-resource route through r09 — frozen preparation

This independent preparation replays one fresh original run through r01a → r02a → r03a → r04a → r05a → r06a → r07a → r08a → r09a. It does not restore a checkpoint. It copies the verified r06 GUI04 observer and safe-step04 driver and adds only the three connected original nodes after r06. Production, first-room, r03 and r06 files are unchanged.

Preparation only: no Godot process, engine parser or GUI was started. No r09 combat or route pass is claimed. `static_check_result.json` records source-level checks, not engine syntax or gameplay validation.

## Frozen baseline

- Production source binding: `da26defba5cbdcf2ca2b0a7e51d03ed0345f2525336d3543598df5090c001360`.
- Original r06 observer: `69aa48269d746c4321a10053d2aa4ba02eab39242292f472bf31b3eb001d845e`.
- Original r06 safe-step04 driver: `20441c2960f5f2d1edaddc888f86a78dba65ad26142a352cd9c430d0bd97f34f`.
- All 1,550 production `runtime_map` files match the sealed binding. Formal equipment43 and training12 are not edited.
- The prior GUI04 report is `../../evidence/natural_route_r06_gui04/report.json` relative to this preparation directory. Its r06 evidence is context only and is never loaded as gameplay state by this replay. That run ended at Lv4, XP88, 1SP, gold525, Q1rank3 and HP446.4, with its one purchased potion unused. These are not required or assigned values for the new run.

## Exact new actions

1. Run the unchanged initial zero-gold, zero-XP, Lv1, original1SP preparation and the verified r01–r06 sequence. Keep the inherited first two battles, original r03 rest, earned Q1rank3 request, one original200g potion purchase if affordable, r04 training inspection/skip, r05 elite fight and r06 training inspection/skip.
2. Verify the complete original r06 success gate before any new action. Preserve its observation and existing evidence file.
3. Resolve any actual mandatory visible Hex offer through the unchanged original HUD route. If current Q1rank3 and at least1 earnedSP are present, use the existing visible, enabled growth-button/HUD-adapter route to request rank4. Otherwise record the optional upgrade as skipped. Preserve actual `upgraded`, before/after rank, SP and original result; no success is inferred from a fixed level.
4. Select and enter original r07a, which has four minions. Keep the exact r06 current-visible-body WASD/BASIC/Q1 policy, input interval, camera/ground/wall visibility and actual hero-radius geometry.
5. After original r07 victory and its four scoped rewards are verified, resolve any actual mandatory visible Hex offer. If current Q1rank4 and at least1 earnedSP are present, request rank5 through that same original legal path. Record an unavailable optional upgrade as skipped. An actual rejected request or required authority failure stops the replay red.
6. Enter original r08a, which has two armored enemies and two minions. Retain each room's original roster, generation, room ID, deaths, accepted reward IDs and source terminal independently.
7. Enter original r09a rest and press the original visible Continue through its existing Host route. Verify the original RestService receipt against the exact committed entry, run and room, HP/actual-heal receipt, all six cleared cooldowns, unchanged progression resources and unchanged r03 settlement. Stop while still in that original rest area, at readiness.

The driver file has exactly one change from r06: row9 joins `[3,4,6]` as an original service row. The observer's inherited functions other than `run` and `finish` are byte-for-byte unchanged. Its three added functions report later earned upgrades, summarize observed potion effects and verify r09 completion. Diffs include all changes.

## Player-input and time boundaries

Only the original HUD/Controller/Session/Router player-input paths are used. The original Host remains the sole owner of source ticks and held-basic updates. No extra simulation tick, direct damage/heal/potion-consumer call, HP/economy/enemy/AI/RNG/clock/rank write, training payment/selection, world-state restore or alternate fixture is added.

Target selection still reads only rendered enemy views that pass actual current camera, ground and wall visibility. The unchanged local eight-direction WASD choice considers visible steps of1m and nearby visible openings no farther than2m. An original `hero_too_close_to_next_spawn` refusal only allows the unchanged next visible1m WASD step toward the visible center, followed by a new original Session preflight. There is no hidden enemy lookup, future enemy prediction or global path search.

The observer keeps `WALL_MS=100000`, measured once at initialization. The parent's external guard remains110seconds. Completion must actually be observed before the100second deadline; screenshot/report I/O does not grant gameplay time. The prior r06 run consumed most of that budget, so the added rooms may time out. A timeout, natural death, fault, rejected required action, missing evidence or late completion remains incomplete/failure. No timeout increase, retry fixture or checkpoint continuation is included.

## Potion reporting

The inherited single original potionI purchase and at-most-one use attempt remain unchanged. The actual rendered, viewport-present, enabled `药I ×n` button is emitted only when actual HP is strictly below60% of actual maximum HP. It may remain unused. A rejected use is reported separately from accepted consumption.

Only the original consumer advances recovery on its source actor combat clock. Every changed consumer snapshot preserves actual `active.actual`, `active.left`, rate, effect ID, committed-effect count, hero time and actual HP. `potion_course` includes the final source-consumer snapshot and each effect's exact last observed active record.

The consumer removes an expired effect without exposing its terminal cumulative healing total. If an effect disappears, the report explicitly labels its stored `actual/left` as the last visible active sample. It does not set the remaining duration to zero, fill in the final healing increment, equate HP delta with healing, substitute theoretical20% recovery or claim the full course was observed. The same limitation applies if an effect disappears because the owner dies or is retired.

## Evidence and completion rules

Success requires nine connected original row completions under the same run and original owners, five combat scopes at rows1/2/5/7/8, exactly20 authenticated source deaths and20 distinct accepted original reward IDs, five original source victory terminals, the original r03 rest, both unchanged training skips, and the second exact original rest at r09. It separately verifies both later optional upgrade outcomes and their actual SP/rank accounting.

The final report contains the inherited first-stage evidence plus `r06_verified`, `r06_observation`, `later_upgrades`, `r09_rest_entry`, `r09_rest_completion`, `r09_rest_observation` and `potion_course`. Additional files include `r09_original_rest_evidence.json`, `r09_route_evidence.json` and `later_earned_upgrades.json`.

This remains synthetic source-input replay. It is not OS input, native CUA, manual-player evidence, full-floor completion or Boss completion.

## Authority files inspected

- `tests/ink_first_floor_user_route_20261005/runtime01/first_floor.json`: exact connected nodes, payload types and rosters.
- `tests/ink_first_floor_user_route_20261005/runtime01/host.gd`: `_select_row`, `_request_next_room`, `_complete_service`, original Controller refresh.
- `tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd`: original node preflight, entry, service readiness and snapshot identities.
- `tests/ink_first_floor_user_route_20261005/native_host01/host.gd`: `_learning_panel_allowed`, growth toggle and battle collapse.
- `tests/ink_q3_input_growth_20261004/growth_hud.gd`: real Q1 upgrade button,1SP cost, original rank ceiling and adapter request.
- `tests/ink_rest_service_20261006/candidate01/floor_session.gd` and `rest_service.gd`: exact committed rest entry, receipt, healing and cooldown cleanup.
- `tests/ink_equipment_live_20261008/content01/potion_model.gd` and `tests/ink_potion_recovery_20261008/candidate01/potion_consumer.gd`: original consumption, combat-clock recovery and active-only diagnostics.
- `visual_rework_20261009/runtime_host.gd`: retained original runtime/visual transition chain.

## Review and launch boundary

Keep `natural_route_r09.gd` beside `visible_route_r09.gd`; the observer dynamically loads its adjacent driver. `preparation_manifest.json` records frozen SHA256s, source pins and verification status. Two `.gd.diff` files compare directly with the verified r06 files. `protected_baseline.json` retains protected-file digests.

Run the read-only check with Python at `static_check.py` when reviewing. It verifies protected and production hashes, exact driver delta, inherited function preservation, original route/rosters, critical evidence gates, forbidden source mutations/calls and basic balanced delimiters. It is not a GDScript parser.

Only the parent may arrange a separately authorized original GUI window with the unchanged training12 production PCK/source binding, existing110second guard and a fresh absolute `--natural-evidence` directory. This preparation does not launch that window. Any post-freeze correction requires a disclosed new revision and fresh hashes; these files are not to be silently changed.
