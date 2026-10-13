# First-room visible-target source-input replay — preparation only

No Godot process, parser, import, GUI, combat run or production edit was performed for this preparation. This is a finite synthetic player-input replay, not native OS/CUA input and not a manual clear. It has no combat result yet.

## Scope and authority

- Start the exact original visual entry and call its original `request_start("yanguizhou")` once. The initial observer requires 0 gold, 0 XP, Lv1, one SP, no equipment/training/selected Hex, all skill ranks zero, original AI enabled, and preparation auto-finish false.
- Await the actual visible initial four-card Hex offer. Select the second offered card (zero-based slot1) through the original HUD adapter. Its ID/name/description are recorded from the visible projection; no guaranteed Hex ID, refresh or RNG change is used. In the current offers this is commonly 轻装上阵, but the code does not assume it.
- Require the real Q1 learning button to be visible and enabled, then submit its original HUD request. Verify original one-SP learning produced Q1 rank1, SP0, still 0 gold/0 XP/Lv1, empty equipment and training.
- Call the original Host route-selection and room-entry callbacks for r01a. Their Session and enemy-art preflight are retained. No later room selection or earned-level learning is automated.
- Every 120 wall milliseconds, choose only currently visible enemy bodies, use WASD to circle the nearest at normal attack distance, maintain original held BASIC, and use a short Q1 stroke through up to two current visible enemies when the player's actual Q cooldown and action lock allow an attempt. Rejections are retained; source cooldown, damage, collision and release rules remain authoritative.
- Q1 is a real input sequence across updates: release ordinary LMB, pointer motion, Q-down, fresh LMB-down, motion, LMB-up, Q-up. If a targeted body leaves the visible set, cancel with the original Escape input and release the held keys. No future enemy state or projectile prediction, hidden target selection, whole-room path planner, Shift, Space pause or F10 is automated.

## Exact original interfaces

- `scripts/ui/hud_adapter.gd:18`: request identity/revision and `request_emitted`.
- `tests/ink_q3_input_growth_20261004/controller.gd:11`: original Session boundary for learning; parent `scripts/ui/progression_controller.gd:85` dispatches legal model commands and its completion signal projects them back to the original Session.
- `tests/ink_first_floor_user_route_20261005/runtime01/host.gd:114` / `:117`: original `_select_row` and `_request_next_room` callbacks, including Session and enemy-art preflight.
- `tests/ink_style_specimen_20261004/revision03/inputfix02/mouse_aim_state.gd:18`: original pointer `observe` receives synthetic viewport-local mouse events.
- `tests/ink_q3_input_growth_20261004/input_adapter.gd:17`: original `route_event` resolves current event coordinates and rejects GUI-blocked input. The production River router inherits this path for BASIC/Q1/WASD.
- `tests/ink_q1_foundation_20261004/revision02/scripts/ink_input_adapter.gd:24`: original WASD mapping, Q-down/up, LMB-down/up and motion. This router is the only writer of movement intent used by the replay.
- `tests/ink_style_specimen_20261004/revision03/inputfix02/host.gd:61`: retained Host loop alone calls `update_held_basic(_current_pointer_ground())` and `sim.step(delta)` at lines70–71. The replay calls neither. Pointer observation lets this existing held-attack loop use the synthetic current aim, preserving shared source cadence.
- `tests/ink_first_floor_enemy_views_20261004/fix01/roster_presenter.gd:107`: actual rendered actor view map. The driver never calls sim.enemies/living/enemy_by_id.
- `tests/ink_first_floor_room_art_20261004/stage.gd:132` / `:138`: actual current camera and original screen-to-ground projection, with original follow and zoom unchanged.

`integration_checks/source_visual_replay.gd` was reviewed but is not loaded: its `_command`/learning path is legal, whereas its unrelated R preparation intentionally injects lethal damage. This replay instead uses the original HUD adapter and contains no fixture branch.

## Visibility and modest movement policy

The driver first checks each rendered body's actual visible-in-tree state and ground position against the real camera frustum and viewport, with a24px edge margin. It rejects points under blocking GUI controls, failed camera-ground round trips, outside the arena or within original obstacle footprints. It conservatively checks both foot-ground and torso sight lines against the authored room's solid boxes using each solid's maximum visual height and includes the closed gates. It also rejects hero-to-target ground paths blocked by original source obstacle footprints. Only after these gates does it inspect the body's already-presented alive/cleanup/clip sample. It never reads source enemy arrays or hidden HP/AI state to choose inputs.

Movement uses a nearest-enemy radial/tangent direction, one local one-meter collision check and one tangent reversal. A blocked reversal stops movement. An empty visible set releases LMB and WASD and waits. These checks only constrain input choice; they do not replace or modify source collision. Conservative visibility can omit a partly visible actor and can stall this simple policy. A stall or death remains a failed/incomplete result, not a reason to change balance, add resources or expand observation time.

The original observer still reads the full roster to verify source identity, death and rewards. None of those observer snapshots is passed into the input policy. This read-only accounting is distinct from target selection.

## Preserved observation and result contract

`natural_first_room_replay.gd` is the original approved observer (SHA2af6fe81082486e5a28ce42d7638b463763372f5328b8b69dda46f675a6017df) plus the small driver hookup and accurate synthetic-input labels. `observer_minimal.diff` records those changes. The whole original `verify_first_room_success` function is byte-for-byte unchanged.

Success still requires the same original owners and four original r01a minions, actual positive damage and one source death per actor, four original Session kill receipts, four accepted original Model rewards, one original terminal victory, and exactly one completed r01a row settled to `between_rooms` while the hero lives. Actual gold/XP/level are observed, without assuming fixed totals. Death, fault, wrong route, identity loss, missing evidence or the100-second boundary is not success. No full-floor or native-input claim is made.

Evidence adds `replay_preparation.json`, `replay_input_receipts.json`, actual synthetic action receipts and visibility samples. The normal original initial/roster/checkpoint/reward/pre-exit/final reports remain. `source_input_injection=true` means disclosed player-input injection only; `wallet_HP_AI_enemy_clock_fixtures=false`, `extra_sim_steps=false`, `input_replay=true`, `native_input=false` are explicit.

## Deferred execution, not authorization

The original100-second observation limit is measured from script initialization and is never reset. The parent's existing110-second external guard remains unchanged. Use a fresh evidence directory and the parent's same previously approved launch arguments/guard; this preparation does not authorize starting Godot.

When separately authorized, the entry script is:

`/workspace/scratch/73ebae91a474/loot_resume_1115/candidate15/natural_first_room_replay_prepare/natural_first_room_replay.gd`

It dynamically loads its adjacent `visible_player_replay.gd`, so both files must remain adjacent. It can be given as an external `--script` against the sealed training12 pack, retaining `--natural-evidence=<absolute-new-directory>`. The source binding must be `da26defba5cbdcf2ca2b0a7e51d03ed0345f2525336d3543598df5090c001360`; the pack is `../pack_training12_01/游戏.pck`, SHA2934333a98a9add2ecd608cd401f27319809a318551c69c593eb49471b369dee. The original GUI renderer is required for actual camera/presentation visibility, even though inputs are synthetic.

Static checks covered forbidden mutator calls and assignments, no hidden-source enemy reads in the driver, unchanged success verification, constant100s, unchanged source binding and original monitor SHA. No GDScript parser is installed outside Godot; engine parsing and actual execution remain NOT RUN. Independent review should precede any authorized engine window.
