# Q3 fix02: fixture corrections and separate G22 batch repair

Original 041a5b and fix01 9ea60f sources/results stay immutable. Main proved fix01
initialization in 78 actual checks. Its subsequent original Q3 gate ran 323
checks but failed five assertions and one downstream empty-dictionary access;
that run remains FAILED, and its five retained gates were not run in that batch.

## A. Test-only correction, no weakened game guard

The hitstop movement helper retains RIGHT intent. The old lifetime fixture then
walked five actor seconds to x21.35 but tried to raise again at x4, beyond the
actual source range 9m even after CD reset. `fixture_diagnostic_gate.gd` records
real position, intent, distance, zero cooldown and rejection reason before
recovering through normal D-key-up and a legal target. The corrected full gate
uses the existing input adapter's key-up after its hitstop observation and also
asserts the real shared CD reset is zero before its original second cast.

The callback does fire, but synchronous begin_encounter during request_action's
transaction is correctly rejected with invalid_phase. The diagnostic and fixed
fixture capture that actual callback/result, then reopen the room only after the
original action returns. Existing callback cleanup and all original assertions
remain; no reentrant room capability, range increase, CD edit or core change.
`fixture_only.patch` records these fixture changes and explicit binding paths.

## B. Actual isolated mechanic fix: G22 simultaneous area batch

Q3 had snapshotted its targets and damage amount but had not supplied the three
existing Wind R1 impact fields. `g22_runtime_only.patch` independently records
this local runtime change: take the live-set mode, penetration and lifesteal
snapshot before the first raise/collapse packet, then supply g22_mode_snapshot,
impact_penetration and impact_lifesteal_rate to the existing damage pipeline.
The next independent raise/collapse call obtains a new snapshot. Shared runtime,
Ink damage guard, original catalog and all source numbers remain untouched.

`g22_batch_gate.gd` compares preserved fix01 and fix02 for both raise and collapse:
two actual contacts, first enemy really killed, none→single-elite and
8-enemy-horde→7 live transitions. It proves same-batch damage/penetration/lifesteal
stay on the pre-hit mode and a later independent segment re-evaluates the live
set. No all-30-Hex, future E/R, ordinary-entry or visual claim is made.

## Main-only actual execution

- Run verify_source.py --write once, then without --write to verify frozen source
- prepare_stage.py --stage <existing-2055-stage> appends only fix02 files, verifying
  existing original+fix01 hashes; no original file overwrite or art reimport
- First run fix02/fixture_diagnostic_gate.gd, then q3_gate.gd and g22_batch_gate.gd
- Run diagnostic_gate.gd plus the five retained gates from fix02; their assertions
  are unchanged apart from exact candidate/result/binding paths
- inspect_engine_results.py audits all nine actual logs and matching results

Author ran source/byte checks only. Actual parse/mechanics/results remain owned
by main; the preserved failed runs cannot become green by static verification.
