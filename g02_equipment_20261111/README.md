# G02 修业徽章 vertical slice

This checkpoint extends the equipment capability-filter baseline (c4f2d0d), not the isolated warning UI. It preserves authored price, recipe, statistics, 500 weighted-kill threshold and once-per-run +1 skill point reward. G17/G21 remain unavailable because their complete dependencies are not implemented.

## Rebuild
1. Recover the exact equipment_hex01 runtime using the prior public recovery chain and the two owner-held original archives. Confirm SOURCE_HASHES before values.
2. Apply g02.patch to a separate runtime copy. New files are included in the patch.
3. Run g02_reencode_portable.py with the unchanged before-runtime, g02_definition.json, the patched route sim.gd, and a fresh output directory. Overlay its three outputs on the candidate. This produces the template without publishing the private binary or documents.
4. Rebuild the manifest, pack and release descriptor through the existing verified chain. Compare all after hashes.

## Scope
See QA.json for exact acceptance and remaining blockers. Funding and near-threshold fixtures are explicit, not natural economic progression. Native mouse covers shop transactions, while subsequent route/combat control is scripted. No Windows execution, real audio listening, multiplayer or human full-floor acceptance is claimed. Existing guard rules are unchanged and required for all engine runs. No private assets, binaries or raw logs are included.
