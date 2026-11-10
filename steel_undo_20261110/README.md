# Steel equipment-sale undo correction (2026-11-10)

This checkpoint contains only a new three-file correction as a zero-context patch, a new isolated regression probe, and source hashes. It is not a complete project or a backup of earlier recovered overlays. The patch requires the matching before hashes in SOURCE_HASHES.json; do not apply to a different baseline. Use a patch tool supporting zero-context unified diffs, then verify every after hash and regenerate the project's binding manifest and generation seal through the existing build pipeline.

Steel preserves the current-health ratio when maximum HP changes. The correction prevents this proportional reduction from also being refunded as equipment-clamp loss during undo. Ordinary non-steel clamp restitution remains in place.

Observed original regression in an independent fixture: HP 322 -> 241.5 -> 402.5 after sale and undo, failing the expected return to 322. The new candidate passed four isolated actual-commerce cases: non-steel full/half HP and steel full/half HP (18, 18, 20, 20 checks). Steel half HP now returns 322 -> 241.5 -> 322. Eleven scripted shared-UI checks also passed.

Tested candidate runtime SHA-256: 30fc86491e3b1b407016770f3040bd7f8be09237660d60220e3f563e8ed289e6. No runtime pack or assets are included. All four final fixture runs and the UI run exited 0 and completed owned-process cleanup. An earlier draft stopped before testing because required resource evidence was invalid; a later lifecycle attempt also stopped at startup. Neither is counted as a pass.

The fixture deliberately funds a separate commerce model and seeds its HP; it does not establish normal shop UI/economy acceptance. Full five-elixir lifecycle, repeated undo/replay, near-zero HP, full-floor, Windows and human acceptance remain unverified on this candidate. Audio used Dummy, not verified audible output.

The public probe changes only output handling to user://steel_undo_probe, with an optional --observer-output=user://... override. Select --case=control_half, control_full, steel_half or steel_full, and use a fresh output directory for each invocation. The public-output adaptation has not itself been rerun in-engine. Run only within the project's existing owned-process resource safeguards. Keep normal player saves and resources separate.
