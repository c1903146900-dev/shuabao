# Isolated 4112 flow-repair trio, static only

This combines three previously backed-up patches without adding enemy, attack, hex or progression changes. It is NOT an admitted release and has never been engine-tested as a combination.

Fixed inputs in c1903146900-dev/shuabao:
- session_fault_latch_20261114 at ca028f1f6381dae89af24cda44aac269cf23f538
- selected_entry_retry_20261114 at 5d3c5ae6d323414422a4877b523837d57ac0a79f
- objective_priority_20261116 at dc996eeb2dd6f02fb382be242344316f44220d5f

The recovered 4112 baseline remains unchanged. All three target files have compatible original contents. Selected-entry patches have blank file headers; the builder supplies only their documented host/session filenames. Original hunk text is preserved. Recovery tools/611 input chain and two original private archives are still required; this checkpoint does not contain them or grant public access to them.

## Rebuild layout

Create a recovery root with `source/rebuild_20261106/dash_trail01` containing the verified 4112 runtime and boot, `source/rebuild_20261106/boot234`, and the existing trusted `tools/rebuild_late.py`. Put the three exact public input directories above under `review_inputs`. Keep their FILE_HASHES manifests intact. Run `python3 build_flow_trio.py --recovery ROOT --output NEW_DIRECTORY`. The output must not exist. The builder validates the input hashes/bindings, applies only the three patches, uses the existing seal routine, checks exact changed paths and runs only independent Python models/source comparisons. It never runs an engine or fetches network data.

Expected PCK: 2c552be19883c8473d72717b9ccfcf2d4ce34155f3e12cfa962205aec4efe346. Both baseline and candidate have 257 bindings. Only host.gd, session.gd, flow_guidance.gd and the required manifest/generation seals differ. QA.json contains summarized static results, not raw runtime logs.

## Remaining admission checks

Run actual-host fault persistence and input clearing; pre-commit room rejection and same-node retry without double commerce commit; wrong-node rejection; interrupted/repeated map clicks; notice expiry and death/map/fault priority; return-to-menu/new-run reset; normal selected 12-node route through Boss. No GDScript parser, engine, whole-floor, visual, audio or Windows result is claimed. Original runtime safeguards remain unchanged and the denied diagnostic was not retried. Keep the baseline and isolated candidate separate until admission is justified.
