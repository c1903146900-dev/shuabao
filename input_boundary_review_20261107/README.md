# Menu release synchronization candidate

Status: accepted as motion_combo10 after focused boundaries, native menu release/held protection, shared UI and full 12-room regression. motion_combo09 is preserved. Accepted runtime and pack are byte-identical to tested input_boundary_draft01.

Actual first-room native keyboard/mouse observation on combo09 found normal held movement/basic attacks, dash attacks followed by basics, E1 action-lock recovery and rejected cooldown presses continuous. No mechanism change justified there.

A separate reproducible menu boundary defect was found: hold attack while the menu opens, release inside the menu, resume with Esc, then click again. The router retained its old left-down flag because the room is disabled while the menu owns input. The first new click was rejected as duplicate_physical_down. The next click recovered.

The candidate only forwards genuine left-button release events from the entry filter to a release-only Host method, including releases consumed by the menu fence. This reuses the existing router release branch. Presses are not forwarded; suppression is never lifted. Normal RUN releases may reach the idempotent release branch twice. No damage, skill, aim, timing, movement, buffering, duplicate-down rule or held-fire boundary rule changes. It does not claim to fix Alt-Tab; release delivery there is platform dependent and unverified.

Build: python3 -I -B rebuild_20261106/build_input_boundary.py NEW_DIRECTORY
Base: rebuild_20261106/motion_combo09/runtime. This public checkpoint contains safe source overlays, builder, observers and summaries only. Original private runtime assets and recovery inputs are still required. It is not a standalone playable public build.
Candidate pack SHA256: 8d2b8df5645e1205cd791708a176d2434d620c251f50c51a926585581e7005c8.

Tests use unchanged owned runtime protection. Native pointer presses/releases are real. The observer's F8 schedules the normal menu button callback 250ms after the native press to reproducibly open while held; F7 also schedules the normal resume callback. Thus this is source-button-assisted boundary testing, not a claim of completely native keyboard menu activation.

- continuitymanual01: combo09 real first-room movement/basic, dash/basic, E1/held and cooldown-refusal observation, no new ordinary continuity defect.
- menureleasebefore01: confirmed old duplicate_physical_down on first resumed click, next click accepted.
- menureleaseafter01: first resumed click reached the real cooldown gate rather than stale duplicate gate. It was too soon for an attack; this alone is not an attack-success result.
- menuholdafter01: held native mouse for 1.9s across menu/resume, no extra attack despite elapsed cooldown. Release then first new click accepted. Second cycle released inside menu, resumed with Esc, moved for 1.1s, first new click accepted. No automatic attack after either menu return.
- menureleaseui01: all 11 shared UI checks passed; guard max gap 0.09796s, clean exit.
- Independent actual-diff review passed: only entry, host and generated sealing files differ. Double release is idempotent; no press forwarding or movement/pending clearing occurs.

Final checks: releasemethod01 passed press/other-button rejection, unchanged duplicate-down protection and idempotent release without clearing movement, issuing actions or changing the observed empty pending buffer. Nonempty pending preservation is source-reviewed, not separately seeded in a runtime test. Guard gap 0.0550s, exit 0.

releasefloor01 completed all 12 rooms including Boss through normal source combat and route navigation: simulation 241.684595s, HP 329.6984, gold 395, 9 potions bought and 5 used. Q3 starts/launched/expired 22, contacts 29. Guard wall 253.899816s, maximum sample gap 0.09838008s, exit 0, complete owned cleanup. No retry was required. This is script-assisted normal play, not human playtesting or Windows release acceptance.

All 243 manifest entries verified. Only entry, host and generated seals differ from combo09. Boss motion remains separate and is not included. No claim that Alt-Tab was reproduced or fixed.
