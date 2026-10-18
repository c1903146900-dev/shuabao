# Recovery checkpoint index (2026-10-18)

This branch preserves historical source fragments and newly reimplemented drafts. It does not contain a recovered complete latest Yan/P3 game. Remote contents of each checkpoint were read back exactly after publication. No new runtime or release acceptance follows from backup.

| Checkpoint | Commit | Contents |
|---|---|---|
| 0924 | 1e34b0e565ca22339b7d9071b055f87a34c9d39c | restore_base.py; recovered UI presenter; manifest |
| 0926 | f95b7328337165d5480e5122bd4542e66e1c2caf | recovered WorldFX Entry, combined UI Entry, UI status; historical guard components |
| 0927 | 18d75333b0bae4b1b732ae0f680164b0d15084db | WorldFX scene/observer; UI plan/diffs/inventory; restore_priority.py; P3 rule draft |
| 0928 | 468983ae2d2e37497dc9b1a02161f67d7c33f025 | complete three-file P3 core01 reimplementation/test/manifest draft |
| 0929 | 45678d924b802853f8f2023c7777cb6d1f526def | recovered hero2D capture; reimplemented guard wrapper/CODE_PINS/pure tests |
| 0930 | 6fda4e241f8d0ba3e8117d65ef6486c09a1160dd | historical WorldFX runner01 and public recovery boundary |
| 0931 | this commit | guard README_RUNTIME/CANDIDATE_PINS; hero2D recovery/art plan; this index |

## Assembly map (copy into a fresh isolated destination)

- Historical base: original candidate43 at 708454b99a631adac381417f820aabe6798c148c, development/shuabao/candidate43-rebuild/. Verify all 3031 manifest entries, 216204684 bytes. Do not call it the lost current game.
- Restore helpers: put checkpoint-0924/restore_base.py and checkpoint-0927/restore_priority.py alongside each other. Validate their checkpoint manifest hashes first. These helpers require a fresh trusted directory and normal Python assertions; priority retrieval is not complete base restoration.
- UI: overlay/yan_trial_ui_20261018/presenter.gd comes from checkpoint-0924/ui_draft/yan_trial_ui_20261018/presenter.gd. integration/shared_entry_with_ui.gd and RECOVERY_STATUS.json come from checkpoint-0926/ui_recovered/. REVIEW_PLAN.md, both diffs and RECOVERY_INVENTORY.json come from checkpoint-0927/ui_recovered/. Verify the inventory and real base before any application.
- WorldFX: payload/yan_visual_attach_20261018/entry.gd comes from checkpoint-0926/worldfx_recovered/. payload/scenes/hero_entry.tscn and fixture/.../observer.gd come from checkpoint-0927/worldfx_recovered/. historical_runner01/.../runner.gd comes from checkpoint-0930/worldfx_recovered/. The public status is a redacted derivative, not the original status hash. Original runner is not cleared to run.
- Guard: copy runtime_support files from checkpoint-0926 then the additional wrapper/CODE_PINS/tests from checkpoint-0929 and README_RUNTIME/CANDIDATE_PINS from checkpoint-0931. Verify all CANDIDATE_PINS entries. Historical LEGACY_PINS additionally lists an intentionally omitted old README; it is not a runtime dependency. No independent/native acceptance is asserted.
- P3: use the complete core01 subdirectory in checkpoint-0928 rather than the initial isolated draft in 0927. Original Catalog/Tuning dependencies remain required. No Sim authentication or Model integration is provided by core01.
- Hero2D: capture.gd in checkpoint-0929 plus plan in checkpoint-0931. Reducer, completed renderer integration and finished art are not present in this snapshot. Private reference footage is excluded.

Never overlay these fragments blindly on a production game. File identity, dependency restoration, independent code review, engine validation and playable-release acceptance are separate steps.
