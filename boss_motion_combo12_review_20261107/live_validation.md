# Boss candidate live validation, 2026-11-07

Status: isolated candidate, not accepted. Accepted development baseline remains motion_combo13.

Combo13 includes the accepted alternating basic returnstroke and combo12 ink material. Its presentation source is identical to combo12, so the additive Boss presentation overlay applies without losing the accepted changes. The isolated builder is rebuild_20261106/build_boss_combo13.py. Candidate pack SHA-256: e7832236116d2a85a724818c782c0bc14f5cdc41e3f2fd0e8b21ee43f88ba702. The only runtime differences from combo13 are presentation.gd and its two generated seal files; all 243 sealed entries verified.

The earlier combo12 isolated builder failed before producing output because Python isolated mode did not resolve its sibling helper. It now loads that helper explicitly by file location. The combo12 candidate built successfully and passed the short actual H08 refresh/select and E1 learning UI check. That UI check alone is not Boss evidence.

The strict observer traversed the ordinary first-floor route, acquired H08 and E1 through real enabled UI, and reached the Boss. It did not restore a fixture, edit simulation state, skip rooms or modify guard limits. It uses normal game input routing, not OS mouse/keyboard emulation.

Actual ordered event chain: wave warning; accepted E1; matching dagger damage against the Boss; H08 stun; matching E1 mark; matching wave cancellation for crowd control; matching attack cancellation. No wave release occurred between the warning and cancellation. Eleven fresh post-cancellation samples showed neutral attack pose and no stale attack release. Independent damage flash remains legitimate.

Next, a real cone warning released as enemy_impact with hit=false. Nine release samples and later neutral recovery were observed. The miss is a valid committed attack release, not a hit claim. Key post-draw captures were inspected: the Boss compresses in windup and extends on release; cancellation returns the attack pose to neutral. This demonstrates visible body timing, not an aesthetic sign-off. The projected direction was longitudinal, so horizontal lean was zero and opposite-facing behavior is not proven.

Guard passed: wall 170.484243 seconds; peak RSS plus swap 430911488 bytes; maximum sample gap 0.069008263 seconds against unchanged 0.2 limit. Exit code 0; owned process cleanup verified.

Not yet tested in this run: successful wave release, horizontal left/right directions, active-release menu/new-run cache cleanup, Boss kill and full-floor completion. No promotion to the accepted baseline. Next tests must preserve the normal route and existing protections. Raw runtime logs, screenshots, private inputs and assets are intentionally excluded from this public backup.

## Separate complete-floor regression

bossfull13a used the same unchanged ordinary-route observer as accepted combo13. It completed all 12 a-route nodes and defeated the Boss: simulation 241.247629 seconds, remaining HP 315.968393, gold 395, nine potions purchased and four used. Guard passed at wall 253.497132 seconds, peak RSS plus swap 428724224 bytes, maximum gap 0.116337676 seconds, exit 0 and owned cleanup verified. This is script-assisted normal-input/UI gameplay, not a human/OS-input acceptance test. It does not substitute for the separate opposite-direction and active-release lifecycle checks. The Boss candidate remains isolated pending those checks.
