# Equipment 35 source gate

Prepared source only. This authoring task does not launch Godot or any other engine. Run only after the parent task has sealed and admitted the exact candidate06 sources; run engines serially.

Entry: `res://integration_checks/equipment35_source_gate.gd`

Output: `user://equipment35_source_gate.json`, or the exact path supplied by `--equipment-result=...`.

The gate extends the existing post-Boss factory gate. It retains actual Host factory construction, strict binding admission, original Sim/Session/Bridge paths, fresh zero-start assertions and all seven original owner checks. Its only factory-check override requires the precise four-layer Model ancestry: distance → equipment33 → terminal boundary → frozen content01, including the unchanged content01 SHA.

## Declared fixtures

- The original ledger's gold is set to 60000 only as an explicit testwallet after original initial choices. Every use records before/after and run identity. Production starting gold remains checked as zero.
- All equipment enters or leaves through original Session purchase/sell/undo commands and original commerce tokens. No inventory, stats, HP, actor position, AI flag, Hex selection or damage-claim storage is directly assigned.
- Each independent damage case creates exactly fifteen additional source actors, using the original `spawn_enemy` API and explicit 10000 target HP argument. The original room and Director remain present. All targets undergo real spawn grace with AI enabled. The gate stops at the first available contact tick, verifies there was no actor movement or spawn clipping, and then applies declared source damage packets. It never settles an augmented room for rewards.
- Lifesteal observation creates a 40-point nonlethal wound through the original `damage_hero` API. Reaction-enabled ordinary damage then heals through the original damage/heal path without an intervening regeneration tick.

## Assertions

1. Frozen B03 values: base AD 45, HP 320, CDR 12%; unique final-damage bonus 12% at distance ≤4.5 m; constant additional lifesteal 5%.
2. Frozen C06 values: base AP 90, penetration 18, movement speed 10%; unique final-damage bonus 15% at distance ≥9 m; constant additional penetration 12.
3. One/two copies add base stats per copy while each constant bonus appears once in `equipment_effects`, `aggregate_effects` and the current original Sim stats. Repeated projection cannot accumulate bonuses.
4. Original sale of one/last copy, undo of sales and undo of purchases preserve/remove/restore those contributions immediately. Independent real-combat cases prove sold/undone items leave no stale damage multiplier.
5. Per-target actual HP deltas and authenticated source damage events at 3, 4.499, 4.5, 4.501, 6, 8.999, 9, 9.001 and 11 m. Additional elite/Boss targets at 4.5, 6 and 9 m verify rank composition and retained A05 behavior. One/two copies produce the same unique damage multiplier.
6. Nontrue damage against the original Boss defence (38) verifies actual penetration mitigation. With one C06, penetration 18+12 gives a remaining defence of 8 before any preexisting baseline stats; the expected value is computed from the frozen item values and original baseline, not the candidate's displayed penetration.
7. Reaction-enabled ordinary contacts at 4.5, 6 and 9 m verify actual lifesteal healing from the same constant rate, including duplicate-copy cases. Zero-owned cases also check for stale healing.
8. One shared effect ID can contact separate near/far targets with distinct correct multipliers; a same-target retry emits no extra damage receipt and changes no HP.
9. `snapshot_final`, `replay` and both flags together pass already-final amounts unchanged through the original damage pipeline, including A05 plus both distance passives.

## Coverage limits

G18 remains unsupported in the real catalog and absent from the admitted capabilities and selected Hexes. The gate does not enable it, weaken its checks, inject it or claim actual G18 recorder/playback acceptance. Replay assertions cover only finalized packet metadata at the original damage pipeline. The gate does not claim natural play, native GUI input, artwork acceptance, route reward completion or an engine pass until the parent actually runs and reviews the emitted results.
