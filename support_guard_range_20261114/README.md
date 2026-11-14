# Isolated eight-metre support guard query

Independent child of the 875 combination. Only enemy_director._closest_guard is edited, plus required generation/manifest seals. Original _nearby, combat values, other enemy logic, hero controls and earlier candidates remain unchanged. Query bounds use sim._cell(position +/- 8m), inspect all covered spatial buckets, then preserve the original strict distance <8m comparison, alive armored filter and nearest selection. Exactly 8m remains excluded; no gameplay range expansion was introduced.

Existing mixed-room placement puts support at (1,-5) and armored at (1,-1). If the armored actor advances to (1,0), it remains five metres away but lies outside the old adjacent-cell search. The Python model reproduces that miss and the new coverage. 241 cases pass, including negative/grid boundaries, nearest, dead, wrong kind, exactly eight metres/outside and more than twelve nearby non-guards. This is an independent spatial model, NOT execution of GDScript.

Both runtime binding sets pass 260 entries. build.py asserts the original source is recovered exactly after replacing only _closest_guard. No engine launch, parser validation or full-floor acceptance is claimed. The existing per-step spatial-index timing remains unchanged; moving-actor integration, tied-distance ordering and query cost need controlled runtime checks before admission. Equal-distance candidates retain first-encountered behavior, though expanding the scanned grid may change tied ordering. No stun logic was modified.

Current pack is pinned in BUILD.json. Preserve original 875 and all independent candidates. Work is local-only and vulnerable to reset; no upload attempted.

## Reconstruction
Apply guard_range.patch to a fresh exact 875 runtime after checking SOURCE_HASHES.json. Verify the patched source hash, then use the existing trusted sealing procedure to regenerate manifest, generation, PCK and descriptor. BUILD.json pins the expected package hash. This source-only checkpoint contains no playable binary, assets, private archives, raw logs or other pending/rejected batches. Run python3 test_model.py to repeat the independent 241-case model; it does not execute GDScript.
