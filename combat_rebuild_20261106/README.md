# Combat rebuild checkpoint: 2026-11-06

Source-only incremental backup with limited verification completed. This reconstructed motion/input/effect checkpoint is not a release and does not replace the repository root project.

The four scripts under `changes/fengli_route_20261024/` cover presentation, input buffering, puppet motion, and skill effects. The sibling `rebuild_20261106/build.py` applies them to the separately restored runtime using relative paths. Required runtime assets and dependencies are not included here.

`tests/check_motion.gd` contains focused motion/input assertions using a mock source. `tests/specimen.gd` draws a source-art motion contact sheet. Both require the restored runtime and boot scene; they are not standalone tests. The public specimen copy writes `user://combat_rebuild_specimen.png` instead of an executor-specific absolute path.

The limited fresh verification below does not establish full gameplay, Windows, audio, or user visual acceptance. `SOURCE_HASHES.json` records the exact backed-up script bytes. No private references, internal plans, logs, binaries, or generated art are included.

## Fresh verification

The four production scripts remain byte-identical to the initial backed-up checkpoint. Earlier results for lost candidates do not apply.

- Production script loading/instantiation, input-buffer expiry and boundary handling, plus 101 arm-angle samples: 115 checks passed. Runtime guard passed and the process tree exited and was cleaned up.
- A 12-phase attack/dash contact sheet rendered successfully; the production presentation parsed and image save returned success. Visual inspection found intact face/blade poses and distinct planted, travel, and landing phases. The boot menu overlaps part of the chart header. This is limited pose inspection, not user visual acceptance.
- A short Linux desktop-window smoke test covered menu/new game, initial selection, E2 learning, closing/reopening the map, entering the first room, two basic attacks and Shift, Esc pause/resume, E2 use, movement, and F10 exit. Guard duration: 95.4707 seconds; exit code 0 and complete process cleanup. Action logs confirm basic casts 1/2 and dash cast 3. No SCRIPT ERROR was recorded in this short smoke test.

Known diagnostics: existing boot-time Unicode/NUL parsing messages remain. The specimen run also logged an XServer BadValue error, despite successfully saving the image and exiting with code 0. The runs are not claimed to be free of all diagnostics.

Fresh script-assisted normal-combat full-floor regression subsequently passed all 12 rows including the Boss; see [the combined status](../rebuild_20261106/STATUS.md). Windows execution, audio verification, and human full-floor/user acceptance remain pending. These basic attacks faced away from nearby enemies, so hit-spark quality is not accepted by this smoke test. Raw logs, screenshots, and art are not included in this public status update.
