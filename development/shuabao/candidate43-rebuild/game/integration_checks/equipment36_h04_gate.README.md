# B01 / actual original H04 source gate

Status: PREPARED ONLY. No Godot process, GUI, or gameplay test was run while authoring these two new files. This is an independent extension of `equipment36_source_gate.gd`; it does not modify or replace the existing 1390-check result, gameplay code, or binding seal.

Entry: `res://integration_checks/equipment36_h04_gate.gd`.

After the parent authorizes a serialized engine window against the reviewed, sealed candidate07:

```sh
godot --headless --path /workspace/scratch/73ebae91a474/loot_resume_1115/candidate07 --script res://integration_checks/equipment36_h04_gate.gd -- --equipment-result=/tmp/equipment36_h04_gate.json
```

The executable may have a different name in the parent environment. Default output is `user://equipment36_h04_gate.json`; exit codes are 0/pass, 1/assertion failure, 2/output failure. Only a complete actual result with `passed: true`, all three groups, and no raw engine errors establishes coverage. Static inspection is not Godot parsing or runtime validation.

## Actual default-seed route to H04

The existing Host's original Model construction uses default seed1. Its first Lv1 offer is expected to be `[G01,G24,H01,H06]` (slots0..3). Ordinary refresh commands, each used once in the order **0 → 3 → 1 → 2**, produce:

1. `[G05,G24,H01,H06]`
2. `[G05,G24,H01,H03]`
3. `[G05,G06,H01,H03]`
4. `[G05,G06,H04,H03]`

Select actual slot2 to own H04. Spend the original initial1SP through Model `learn(Q,Q2,expected_rank=0)`, then the existing Session/stat consumer projects rank1 Q2 and makes H04 active. Neither RNG nor offers, selected Hexes, ranks, XP or SP are injected. The expected sequence was derived by a separate static reproduction of the original weighted allocator and current admitted12-effect pool; the executable gate checks every actual Model offer and RNG value rather than accepting that derivation as execution evidence. If the real sequence differs, the gate stops and reports the difference. No alternate seed or fabricated prerequisite is substituted.

## Genuine Q2 and H04 source path

The inherited original Host factories provide the real Sim, Session, router, Model, clock and Director; exact binding admission, frozen base-Model SHA and all seven identities remain checked. The inherited explicit60000-gold testwallet funds two actual B01 purchases through original commerce. No extra AP or other equipment effects are added.

The original connected node `r01c` provides its unchanged six-actor roster. Spawn grace and AI advance through original fixed steps. The fixture waits at most400 steps for two original minions to approach within2.8m of the hero and0.5..2m of each other. It records their actual positions and uses them as A/B; no actor position, AI state, HP or damageable state is assigned. If the geometry does not occur while the hero remains alive, the test fails with actual state diagnostics.

Fresh synthetic Q-down/Q-up and left-down/left-up events go through the **actual factory input router** for each Q2 point. A must retain the original cast without starting CD. B must complete the same cast into one real two-point river, start the authored rank1 cooldown, and snapshot the legally owned H04. The source-generated river must already have touched both selected original enemies, and both must survive. The base river's original once-per-enemy hit ledger then prevents it stealing either later H04 kill.

Only after those original birth contacts and cooldown start, an explicitly labeled **non-Q/E, cast0, nonlethal true-damage source-API fixture** reduces each selected enemy to1HP. It uses `damage_enemy`, `no_reactions` and `snapshot_final`; it does not assign HP or generate a kill/award. The fixture checks that B01 task, claims and CD remain unchanged. Subsequent lethal damage is generated solely by ordinary fixed stepping of the actual H04 sunset sampler. No manually constructed positive H04 packet, fake sample, explicit `_q2_damage` dispatch, or invented `original_q2_hex_receipt_verified` input is used.

## Required proof

- Exactly two intended original actors die with `source=hex_yanguizhou_h04`, both carrying the same actual Q2 cast ID.
- During each actual kill callback, the original `_b01_damage_frames` and `_river_hex_packet_frames` contain the same target identity. The original strict `_river_hex_original_packet` and `verify_b01_kill_attribution` must independently succeed on the live stack.
- The test copies the real metadata/receipt from that stack for evidence. River, cast, target, room, generation, tick, source time and original Hex/area/active-skill provenance are checked. The schedule remains born-time plus0.5s×tick, ticks1..8.
- First H04 kill refunds35% of its current nonzero Q CD. Second original enemy increases task progress1→2 while its before/after CD is unchanged. Two purchased copies still create exactly one per-cast refund claim and event.
- Both kills produce authentic original reward receipts, with no Session fault or event authentication errors. Replaying each actual saved event is reward/task/refund-idempotent. The copied H04 metadata and kill event fail attribution outside their original live source stack.
- The original witness stacks unwind, and AI, auto-finish, original owners and living hero are retained.

The report labels the wallet and non-Q/E pre-damage fixtures separately from actual Q2 router input and actual source-generated H04 damage. It makes no natural-play, natural-full-floor, native GUI, P1 supplement, art/audio, balance or production-readiness claim. Its final `h04_original_packet_case_covered` becomes true only when this dedicated executed gate passes.
