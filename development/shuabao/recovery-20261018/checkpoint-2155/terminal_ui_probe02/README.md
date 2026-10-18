# Terminal summary probe02

This is a new fixture revision built from the exact full_floor07 runner and driver. It is not an exact restoration of the lost terminal runner or its binding. The existing terminal summary and Presenter were recovered byte-for-byte and are unchanged.

## Bound source

- Original worldFX03 source: 3046 files, inventory SHA-256 `c8bc6934c99fcb55ae60a765e4b59019142fcf16e64ed83f45839138d1a78b64`.
- Standalone terminal candidate: 3047 files, expected inventory SHA-256 `c74a9b93954f5f30abeb0721979d4d5600c02f74e1931ae3f03cd36cabc85436`.
- Only the Presenter changes and one `result_summary.gd` is added to that worldFX03 parent. The Entry has no additional delta. Original Host, Sim, Model and Session bytes remain bound.
- This fixture binds all 3047 production files plus the exact route driver and passive summary helper. It cannot run against the earlier 3044 or a future hero/Q1 combination without a separately reviewed binding and inventory.

## Fresh-stage contract

The stage must contain the standalone candidate, the verified 98-file imported-resource cache, and these four fixture files. The expected total is 3149 files; actual stage sealing must establish the final count and hashes. Do not overwrite a sealed source or a previous evidence directory.

Entry: `res://yan_terminal_full_floor_20261018c/runner.gd`.

Required user argument: `--full-floor-evidence=/absolute/nonexistent/evidence_directory`.

Optional argument: `--terminal-outcome=victory` (default) or `--terminal-outcome=defeat`. These are independent invocations; the fixture never starts a second run inside an invocation.

Both modes retain the independent 470-second signal watchdog, 480-second absolute process-frame deadline, at most three screenshots, and 16 MiB of raw image data. Engine launch and external process containment are separate responsibilities. This package has not launched an engine.

## Victory coverage required

The inherited normal Q1 learning and earned upgrades, original 12-node route, combat rewards and unique receipts, Boss settlement, service/rest receipts, shop undo/current-visit boundary, asynchronous four-choice Hex protocol, and cancelled hero-change confirmation are retained. The original pending-Hex, completed status, 12 actual rows, and disabled-next-node checks remain. Only the old English/header spelling assertion changes to the real Presenter wording `首层已完成`.

Additional hard gates:

1. Observe the actual final mandatory Hex while the summary card and reopen control yield; do not bypass or auto-clear it.
2. After its real selection and post-draw refresh, compare actual labels with frozen settlement gold balance, level, remaining level XP, and accepted run-scoped kill receipts.
3. Check card and close control viewport reachability and the layer being below the original Hex layer.
4. Exercise only the summary's display-only close/reopen signals; require original Host/Sim/Session/Model identities, state and receipt hashes, settlement, clock, pause/modal state and return-button connections to remain identical.
5. Use the existing P shortcut and original shop-close control, observe summary yielding, then verify its return and account/settlement conservation.
6. Use the inherited chooser/confirmation-cancel/resume path, observe the summary hidden with the suspended room and shown after returning to the same run. No confirmed new hero run is executed.

## Defeat coverage

The original entry and initial Hex are used, then the first original combat node is entered normally. No combat inputs are supplied after entry. The fixture waits for original enemies to cause true death and the existing Session to produce a defeat settlement. HP, enemies, positions, clocks, rewards and progression are never seeded. If natural defeat is not reached in the budget, the invocation fails with that limitation; it does not fabricate a terminal state. The actual defeat card and four values must pass, including close/reopen source conservation. This mode does not claim the 12-room/Boss/shop/chooser checks.

## Evidence limits

All interactions are synthetic calls into original input or visible-button handlers; native operating-system clicks are not proven. Display labels and source values are checked after drawing. Screenshots still require visual review. No art acceptance, all-skill coverage, front animation acceptance, or unobserved mode PASS is inherited from previous runs. GDScript parse and native runtime checks remain pending.
