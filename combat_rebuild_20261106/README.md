# Combat rebuild checkpoint: 2026-11-06

Unverified source-only incremental backup. This reconstructed motion/input/effect checkpoint is not a tested release and does not replace the repository root project.

The four scripts under `changes/fengli_route_20261024/` cover presentation, input buffering, puppet motion, and skill effects. The sibling `rebuild_20261106/build.py` applies them to the separately restored runtime using relative paths. Required runtime assets and dependencies are not included here.

`tests/check_motion.gd` contains focused motion/input assertions using a mock source. `tests/specimen.gd` draws a source-art motion contact sheet. Both require the restored runtime and boot scene; they are not standalone tests. The public specimen copy writes `user://combat_rebuild_specimen.png` instead of an executor-specific absolute path.

No successful engine run, visual acceptance, full gameplay regression, or test pass is claimed by this checkpoint. `SOURCE_HASHES.json` records the exact backed-up script bytes. No private references, internal plans, logs, binaries, or generated art are included.
