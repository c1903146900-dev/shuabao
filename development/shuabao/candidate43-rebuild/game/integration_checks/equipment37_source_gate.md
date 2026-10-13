# Equipment 37 / G06 actual-damage source gate

Status: prepared source only. The author did not run Godot, a GUI, or this test. Execution and pass status require the parent's reviewed candidate08 result JSON. This gate never writes production code or reseals the source binding.

Parent execution02: **not passed**, 1029 checks. Six groups passed, including real Q1/P1, actual Session sale/rebuy/undo retention, fractional evolution, real Model callback ordering, and all three-level source-verifier fixtures. The evolved checkpoint commerce group is blocked because the inherited `tests/ink_shop_ledger_bridge_20261004/fix01/ink_shop_run_model.gd:174` overrides `restore()` to return false unconditionally. The expected whole-suite completion assertion therefore also fails. This is an existing checkpoint-import prohibition, not a rounding failure. Neither production restore nor the failing assertion has been changed to claim a pass. Results: `../../equipment37_source02.json` in the parent work folder; first-run script retained as `equipment37_source_gate.before_fixture_fix01.gd`.

Entry: `res://integration_checks/equipment37_source_gate.gd`

Run only from the parent-approved, sealed candidate08, with engines kept serial:

```sh
godot --headless --path /workspace/scratch/73ebae91a474/loot_resume_1115/candidate08 --script res://integration_checks/equipment37_source_gate.gd -- --equipment-result=/tmp/equipment37_source_gate.json
```

The executable name may differ in the parent's environment. Default output is `user://equipment37_source_gate.json`. A pass requires `passed: true`, every required group in order, and no failed assertions. Missing output, a parse failure, or an incomplete group list is not a pass. Exit codes are 0 for a pass, 1 for assertion failure, and 2 for output failure.

## Original authorities and fixture boundaries

The main cases inherit equipment36 → equipment35 → the original post-Boss/floor gate. The exact Model chain adds only:

`equipment_elite_damage → equipment_kill → equipment_distance → equipment_expansion → postboss_model → frozen content01`.

The original Host constructs the actual Sim, Session, router, clock and Director. Original seven-owner identity checks, exact Sim/Session/Bridge paths, binding admission, frozen Model SHA, zero-gold/zero-XP/Lv1/1SP startup, mandatory initial Hex choice and genuine one-SP Q1 learning remain intact. The Host is used as a factory, not added as a GUI scene.

Declared fixtures:

- Each main fixture records the inherited explicit 60000-gold testwallet. This is the only direct Model field assignment in the gate. It is not earned money or a production default.
- Equipment uses the original purchase, sale and undo commands. No task progress, completion, evolution, SP, inventory, rank, HP, damage claim, roster, actor position, AI flag or source clock is assigned by the test.
- Packet cases call the existing `damage_enemy` API. They exercise real outgoing multipliers, defence, HP capping, damage emission and synchronous Session/Model observation. They are source API fixtures, not actual Q/E gestures.
- High-HP and low-HP extra actors use the existing `spawn_enemy(kind, position, hp_override)` API. Original entered actors retain their authored HP. The test advances the original clock through both original and added actors' spawn grace; AI and automatic terminal ownership remain enabled.
- Extra actors are never treated as entered route actors. The low-HP overkill fixture's real death must be refused by the original Session with `enemy_not_in_entered_roster`, and must earn no gold/SP/reward receipt. Added-actor cases are disposed while the original combat remains live. They do not fabricate room completion or return to a shop.
- The original-route case uses only original actors. Explicit inherited lethal packets complete original rows to earn Lv2/P1 and, later, return from row5 to the actual safe shop. That is source progression coverage, not natural combat or natural acquisition.

## Seven groups

1. **Definitions and commerce.** Original36 definitions remain byte-deep equal; only G06 is added. Supported count37 and profile37; price3400; AD45/AP65/penetration20; one `passive:18`; threshold100000 actual damage; zero reward SP; evolution base15/cap25. Two copies' base stats stack. Repeated projection is idempotent. Original sale/undo operations and an unauthorized direct G06 progress command are checked. Real G18 remains unsupported.
2. **Unequipped/A05.** Actual elite damage with A05 and no G06 gives no G06 progress. A05 retains base12/cap20, 25% lost-HP floor steps and +2 per step. Real contacts cover full, 25%, 50% and 75% lost-HP tiers. Ordinary targets receive neither the elite multiplier nor task credit.
3. **Actual damage, replay and reentrancy.** One G06 against the unchanged Boss defence38 counts post-defence loss. An explicit7.25-HP elite counts only7.25 despite a999999 nominal packet. Ordinary damage is inert for the task. A callback emits a same-source/cast/target lookalike with a new sequence and the target's whole pre-hit HP: it cannot inflate a real1-point hit. Real nested3+2 damage counts5 once; re-emitting the parent after the child cannot borrow the child's HP delta. A separate observer injects the child before the original Session/Model observer sees the outer event: the newer child sequence is processed first and both real packets must still count. Authentic same-event replays, public new-sequence re-emits, and same-source-effect retries remain inert.
4. **Fractional threshold and evolution.** Two G06 plus A05 deal three0.375 packets. The authoritative Model retains1.125 while the commerce ledger stores `floor(total)`, not the sum of individually floored packets. A real source packet reaches99999.75 and remains incomplete. The crossing packet still uses the old12% multiplier; the next elite/Boss packet uses15% once. The task caps at100000, records one evolution stage/reward, grants no SP, and remains absent from G17's SP-task completion dictionaries. Original25%/+2 tiers remain active after evolution. All threshold amounts come from committed source damage, never task-state setup.
5. **Actual Q1/P1 and original shop.** Four original row1 minion rewards earn Lv2/1SP. The original learn command spends that point on P1. Original rows2–4 lead to an original row5 elite. The unchanged original AI first brings the elite inside the genuine9m placement radius; the gate records its positions and source ticks. Genuine Q1 arm/down/motion/release then creates a short single-target cast; its real whole-wave completion creates one atomic P1 receipt and one final supplement. Task progress must equal actual Q1+P1 HP loss, without applying giant-hunter twice to P1. Historical receipt replay/new-sequence emit cannot add progress. Original source packets then finish the unchanged row5 roster. Actual Session sale/rebuy/purchase-undo/sale-undo preserve earned unfinished progress. The original row6 service boundary preserves it again.
6. **Isolated evolved checkpoint commerce.** This case is deliberately separate from the live high-HP combat Session. The source Model's complete original `save()` checkpoint includes its actually earned evolution, state and command receipts. A new instance of the same Model script binds a separate original factory health Sim and the original commerce/runtime definitions, then restores that checkpoint through the original `restore()` API. The full restored save must equal the original Model’s exact `_canonical(checkpoint)` result. A second recursive field audit records every integral-float→equal-int type conversion and rejects all missing fields, changed values, or other type changes. A separately captured99999.75 unfinished checkpoint is restored first and must retain that exact fractional float without completing the task; the completed checkpoint is then restored for commerce. Only this clone receives the original `context(safe)` command, `begin_visit` and shop-open commands. Original sale/rebuy/undo operations must preserve the earned task, evolution, receipts and SP. Selling the last G06 falls back to A05's1.12 projection; buying or undoing back a G06 restores the single highest1.15 projection. The original live source Model's saved bytes must remain unchanged. This proves isolated commerce persistence; it does not claim the added-actor combat Session naturally reached a shop.
7. **Three-level source-verifier fixtures.** A gate-local subclass inherits the exact original Sim and overrides only `_hero_outgoing_damage` to inject additional calls to the inherited actual damage API. No G06 Model/equipment is bound, so factors remain1.0. Three explicit scenarios cover: three same-target levels; an other-target middle level surrounding same-target outer/inner damage; and a middle packet already emitting its callback when its child damages the same target while the outer packet has not emitted. Every case must authenticate the original1+2+4 packets once, match the actual per-target HP losses, and refuse verification after the frames return. These are isolated source-verifier fixtures, not exact Host/Session cases. Group3 separately checks the real Host/Session/Model's out-of-order callback handling.

## Evidence and limits

The result retains every assertion, wallet/spawn/source packet declaration, live attribution witness, before/after task/ledger/SP records, reentrancy event order, original P1 receipt, isolated commerce transactions and exact binding hash.

Progress comparisons use a fixed absolute tolerance of0.0000001. Relative approximate equality near100000 could wrongly accept a missing fraction or point, so it is not used for threshold adjudication assertions.

The authored20%/25% caps are checked as configuration/selection contracts. Ordinary living-target HP tiers cover what is naturally reachable from valid HP; the gate does not invent negative HP to reach a higher step.

No natural play, natural100000-damage accumulation, natural full floor, native GUI input, G18 runtime, real multiplayer, visual/audio acceptance, balance, or production readiness is claimed. This entry does not replace the parent's separate retained B01, P1/B01, H04, or terminal regression suites.
