# Held movement across HUD clicks

Source-only control_continuity01 overlay on the complete lob_cues01 baseline. Apply host.gd and input_router.gd at their relative runtime paths, retaining preceding overlays and assets and refreshing binding metadata. Earlier versions remain unchanged. This is not a standalone project.

Runtime SHA256: 85f4c29d69d9e1467fb9a37d1742b179a572535e858170e645cd06d5be437236. Source hashes are in CHANGE_PINS.json.

A HUD click could clear held WASD even when the game was not paused and no modal opened. The fix separates pointer-only rejection from true blocking: it clears pending combat, suppresses held attacks and consumes the click while preserving held movement. Pause, modal, focus loss, generation boundaries and key releases still clear or update input appropriately. Leaving the HUD does not automatically replay an attack; a fresh mouse down is required. No combat rules, simulation, animation, audio, enemy data or Shift direction changes are included.

Fresh checks: production parsing and 171 focused checks passed. Valid before/after event sequences each recorded 16 chronological frames: the old version cleared movement and stopped; the new version preserved forward movement, then handled reversal and release. An eight-second normal-source combat sample recorded 60 frames and exited cleanly. All four valid test runs passed their runtime checks, exited with code 0 and completed cleanup. Existing boot NUL diagnostics remain.

Earlier invalid test fixtures and a wall-confounded reproduction are not counted as acceptance evidence. Correcting those fixtures did not change production code. Input sequences are script-assisted real boot/UI events, not human playthroughs; sampled frames are not frame-rate evidence. Fresh regression of this exact runtime passed all 12 selected nodes and the Boss, plus 11 key-UI checks; see [combined flow results](FLOW_QA.md). This remains script-assisted testing, not a human playthrough. Windows and user acceptance are unverified.

Only code, tests, hashes and this summary are included. Screenshots, recording fixtures, raw logs, internal reports, assets and runtime packages are excluded.
