# Q3 fix01: restore the real parent initializer

The preserved source binding 041a5b5bea1c0797308e6a06cbddf4bd27d1bf0bb6d90ee7e99cdeb2fefb1795
ran its first real main-owned Q3 gate at 20:56. It failed at first raise admission,
then produced empty-state cascades. It is not a mechanic pass. Source verification
had not detected this runtime initialization defect.

`ink_q3_sim.gd` is the complete preserved source with exactly one inserted line:
`super._init()` before the existing director replacement. This calls the genuine
inherited Ink initializer, restoring identity, all source/tuning stats, source
rules binding, the original Ink damage bridge, and ranged context. No shared
protection, action admission, source numbers, cooldown, collision, proc or
mechanic implementation is changed in this repair. The original remains intact.

The diagnostic runs old a79fc Q1, preserved bad Q3, fixed Q1 and fixed Q3. It
records actual initialization and action replies, including the original reason
which was only inferred before this gate. The known bad must still be rejected;
no manually assigned HP/hash or forced admission is used. Old/fixed Q1 replies,
actor state and event stream are compared before proceeding to full mechanics.
A narrow additional check covers ordinary BASIC retaining the same mountain and
expiry through continued WASD movement; existing Shift checks are not duplicated.

All six existing finite gates are copied with only new Sim/Bridge/binding/result
paths. `minimal_fix.patch` records the one runtime line and every path rebinding.
No assertion is weakened and no later cascade symptom is repaired here.

## Main-owned execution, with no art reimport

1. `python .../fix01/verify_source.py --write` initially freezes; without the flag
   verifies the exact source candidate
2. `python .../fix01/prepare_stage.py --stage <existing-2055-stage>` verifies the
   original 041a5b stage and adds only the new fix01 subtree; no existing stage
   source is overwritten and no engine is started
3. Main first runs `res://tests/ink_q3_foundation_20261004/fix01/diagnostic_gate.gd`
4. Only after that result, run the unchanged `q3_gate.gd` and its five retained
   gates from the fix01 directory under the normal serial resource guard
5. `inspect_engine_results.py --stage ... --runs ...` audits all seven actual
   logs/results; earlier failed source and original actual records stay separate

All engine work remains owned by main. This author performed source/byte checks
only. Neither the fix nor diagnostic is a complete-hero, floor, ordinary-input,
visual, balance or user-acceptance claim.
