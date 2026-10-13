# Continuous natural route through r03 rest — preparation only

The two code files are frozen for review. No Godot, parser, GUI or combat run was started during this preparation. No production file or previously verified first-room replay file was changed.

This starts a complete fresh original run at 0 gold, 0 XP, Lv1, one SP. It does not load, restore or copy a gameplay checkpoint. The route is r01a → r02a → r03a using the same entry, Host, Sim, Session, ledger, model, hero, common runtime, clock and director identities throughout. This is synthetic player input selected from rendered actors and actual camera/room geometry; it is not pixel recognition or native manual play.

## Exact stage

1. Reuse the verified initial visible Hex slot1 selection and original one-SP Q1 learning through the real HUD adapter/Controller. Enter and naturally fight r01a with four original minions.
2. Verify and archive r01a's original source terminal, four scoped damage/death records, Session kill receipts and Model reward receipts before entering another room.
3. If actual earned progression has at least one SP and Q1 rank1, open the real growth panel with `Host._toggle_growth` and request the original Q1 upgrade with expected_rank1. Verify rank2/SP cost without gold/XP/level changes. If actual progression does not permit this optional upgrade, record `upgraded=false`; a route pass does not itself assert an upgrade happened.
4. Select connected r02a and enter with original Host and Session preflight. Fight its original two armored enemies and two minions. The same visible-enemy control policy is reused; its Q1 length check now reads the player's actual rank.
5. Verify and archive the second room's own terminal and four deaths/rewards by room ID and generation. Resolve any actual mandatory Hex through its real visible four-card offer before proceeding.
6. Select and enter r03a. The original RestSession itself applies the legitimate rest effect on successful committed entry. The replay never calls the healing, cooldown-reset or rest-settlement implementation. Then invoke the original visible Continue callback to mark the service ready while remaining in the rest area.
7. Verify exactly two combat terminals, three connected original row completions, one original rest receipt for this same run/room/entry, observed HP changes, original Q/E/R/Shift cooldowns zero, and unchanged gold/XP/level/SP/equipment/training/selected Hex across rest. Actual values are retained, without fixed reward totals.

No purchases are required or attempted. If a real shop panel is already open, it is closed with `Host._shop(false)` and its original receipt is checked. No modal, visibility or pause flags are directly assigned.

## Original legal interfaces and boundary checks

- `scripts/progression/model.gd:3,112–131`: Q rank upgrades each cost one SP; Q has no extra hero-level gate. The explicit Lv6 gate is for initially learning R. The original model remains authoritative.
- `tests/ink_first_floor_user_route_20261005/native_host01/host.gd:24–55`: legal growth visibility and toggle. Lines38–43 automatically close the growth panel on entering combat. The retained Host's normal refresh reaches this code.
- `tests/ink_initial_hex_ui_20261004/hex_hud.gd:55`: gameplay is blocked by a required Hex or visible Hex draft, not by an already collapsed growth panel.
- `tests/ink_first_floor_user_route_20261005/runtime01/first_floor.json`: r01a connects to r02a, which connects to r03a; r02a uses ordinary_b, with2 armored and2 minion actors; r03a is rest.
- `tests/ink_first_floor_user_route_20261005/runtime01/host.gd:114–131`: original select, enter and complete-service callbacks, retaining Session and enemy-art preflight.
- `tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd:122`: the precise safe-entry rejection is `hero_too_close_to_next_spawn`.
- `tests/ink_rest_service_20261006/candidate01/floor_session.gd:7–19`: original successful rest entry owns settlement and exposes original receipts in the Session snapshot.
- `tests/ink_rest_service_20261006/candidate01/rest_service.gd:11–48`: original run/entry identity, health and cooldown authority; merely inspected, never called directly by this replay.
- `tests/ink_first_floor_user_route_20261005/runtime01/floor_session.gd:248–270`: original Continue records service readiness; it does not imply physical departure.

Only the exact `hero_too_close_to_next_spawn` refusal permits bounded safe-area movement: send original WASD toward the currently camera-visible central floor point, after the same geometry checks. This does not inspect future enemy positions, teleport, change movement intent directly or introduce pathfinding. Other refusals are reported immediately. If the center is not visible, the local path is blocked, the original owner pauses/ends, or the unchanged deadline is reached, the stage is incomplete.

The original Host remains the only owner of held BASIC and simulation steps. The driver only supplies the same original pointer-observer/router events, original HUD requests and normal Host callbacks. Its first-room visibility and control code remains identical except for reading the actual learned Q1 rank in the conservative length limit.

## Files and deferred execution

- `natural_route_replay.gd`: continuous observer/orchestrator; external entry script.
- `visible_route_replay.gd`: adjacent input driver; both files must stay together.
- Each `.gd.diff` compares to the unchanged, previously verified first-room source.
- `preparation_manifest.json`: frozen SHA256s, baseline SHA256s, static checks and not-run status.

The original100-second total wall observation begins at script initialization and is never reset at room boundaries. The parent's original110-second external guard remains unchanged. A death, refusal, fault, budget exhaustion or missing final report remains failure/incomplete. No whole-floor/Boss claim is made.

When separately authorized, run the external script against the same sealed training12 PCK using the parent's existing guarded GUI launcher and a fresh absolute `--natural-evidence` directory. This document does not grant engine authorization. It has not been parsed or run in this preparation.

Additional evidence includes row1/row2 roster and reward files, `route_preparations.json`, archived combat records and `original_rest_evidence.json`. A report with `passed=true` establishes this bounded continuous route only; Q1 upgrade must additionally be read from its `upgraded` result and actual final rank.
