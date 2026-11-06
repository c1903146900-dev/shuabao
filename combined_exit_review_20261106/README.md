# Isolated locomotion-exit candidate on Q2/E2/R1

Initial status: static-only. Subsequent bounded visual and UI checks passed; full-floor remains pending after a guard stop. See RUNTIME_QA.md. This reapplies the earlier locomotion selector fix to the newer r1_motion01 baseline without copying an outdated whole presentation implementation. It is not a runtime-tested replacement, and Q3 remains excluded. Original builds are preserved.

Only presentation.gd and generated manifest/seal differ from r1_motion01. Q2, E2 and R1 animation dispatch, deformation, clocks and mechanics remain byte-identical outside the three return-path changes and shared helper. The helper chooses the existing displacement-owned walk frame when already walking, otherwise idle. It does not advance movement or change facing/cast ownership.

Engine-free build and structural checks passed for all 243 manifest hashes and the shared selector's three call sites. No Godot parse, render, full-floor or user visual acceptance is claimed. Pack SHA256: e164fd2273c09e7d9b6fbec939cd8ceb502b2eb5db2159d55050d36a20f74b0e.

Rebuild the established r1_motion01 chain, then run rebuild_20261106/build_combined_exit.py with a fresh output name. Run check_static.py after producing combined_exit01, or update its candidate path for another output name. Private original inputs/artwork remain necessary.

Next: bounded actual walking-through-attack-recovery comparison against the unchanged baseline, plus stationary exit. Read existing draw receipts, not extra calls to the stateful _frame selector. See action_exit_continuity_20261106/COMBINATION_PLAN.md. Do not promote this candidate until guarded runtime and visual checks pass.

The original static-only scope above describes initial construction. Subsequent evidence is in RUNTIME_QA.md; the package hash is unchanged. Do not promote over the full-floor checked r1_motion01 baseline yet.
