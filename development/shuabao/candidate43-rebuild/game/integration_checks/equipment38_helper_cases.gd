extends RefCounted
## Prepared GDScript gates. NOT executed in this preparation task.
## A later engine harness can call run(numeric, equipment_source).
const Passive08 = preload("res://equipment_basic_cycle_20261009/passive08.gd")
const Adapter = preload("res://equipment_basic_cycle_20261009/source_adapter.gd")

static func run(numeric: Dictionary, equipment_source: Dictionary) -> Dictionary:
 var prepared: Dictionary = Adapter.build(numeric, equipment_source)
 assert(prepared.accepted and not prepared.runtime_complete and not prepared.shop_admitted)
 assert(not prepared.has("definitions"))
 var definitions: Dictionary = prepared.prepared_definitions
 assert(not definitions["final:B04"].supported)
 assert(definitions["final:B04"].recipe.full_price == 3000)
 assert(definitions["final:B04"].recipe.combine_fee == 550)
 var selection: Dictionary = Passive08.select_unique([{"id":"final:B04", "uid":1, "count":1}], definitions)
 var double_selection: Dictionary = Passive08.select_unique([{"id":"final:B04", "uid":1, "count":1}, {"id":"final:B04", "uid":2, "count":1}], definitions)
 assert(selection.equipped and double_selection.equipped and double_selection.owned_copies == 2)
 assert(not Passive08.select_unique([{"id":"intermediate:I13", "uid":3, "count":1}], definitions).equipped)
 assert(not Passive08.select_unique([{"id":"final:B04", "uid":1, "count":1}, {"id":"final:B04", "uid":1, "count":1}], definitions).equipped)
 var scope: Dictionary = {"run_id":"gate-run", "generation":7, "room_id":"gate-room"}
 var identities: Dictionary = {"scope":scope.duplicate(true), "by_cast":{}}
 var cds: Dictionary = {"q":20.0, "e":7.0}
 var evidence: Dictionary = _evidence(scope, 1)
 var before: Array = [selection.duplicate(true), identities.duplicate(true), scope.duplicate(true), cds.duplicate(true), evidence.duplicate(true)]
 var fifth: Dictionary = Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, evidence)
 assert(fifth.eligible and fifth.triggered and fifth.remainder_after == 0)
 assert(is_equal_approx(fifth.cooldowns_after.q, 18.0) and is_equal_approx(fifth.cooldowns_after.e, 6.3))
 assert([selection, identities, scope, cds, evidence] == before)
 var twice: Dictionary = Passive08.evaluate_verified_completion(double_selection, 4, identities, scope, cds, evidence)
 assert(twice.cooldowns_after == fifth.cooldowns_after)
 identities.by_cast[fifth.claim_to_add.cast_id] = fifth.claim_to_add.wave_id
 var replay: Dictionary = evidence.duplicate(true)
 replay.event.hit_target_ids = ["other-target", "third-target"]
 assert(not Passive08.evaluate_verified_completion(selection, 0, identities, scope, cds, replay).eligible)
 var sixth: Dictionary = Passive08.evaluate_verified_completion(selection, 0, identities, scope, fifth.cooldowns_after, _evidence(scope, 2))
 assert(sixth.eligible and not sixth.triggered and sixth.remainder_after == 1 and sixth.cooldowns_after == fifth.cooldowns_after)
 for reason: String in ["path_end", "blocked", "contact"]:
  var natural: Dictionary = _evidence(scope, 3)
  natural.event.reason = reason
  natural.event.hit_target_ids = []
  assert(Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, natural).eligible)
 var zero: Dictionary = Passive08.evaluate_verified_completion(selection, 4, identities, scope, {"q":0.0, "e":0.0}, _evidence(scope, 4))
 assert(zero.eligible and zero.triggered and zero.remainder_after == 0 and zero.consume_claim)
 assert(zero.cooldowns_after == {"q":0.0, "e":0.0})
 var one_zero: Dictionary = Passive08.evaluate_verified_completion(selection, 4, identities, scope, {"q":0.0, "e":10.0}, _evidence(scope, 5))
 assert(one_zero.cooldowns_after == {"q":0.0, "e":9.0})
 var cancelled: Dictionary = _evidence(scope, 6)
 cancelled.original_cast.cancelled = true
 assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, cancelled).eligible)
 for kind: String in ["damage", "ink_basic_released", "basic_completed"]:
  var wrong_kind: Dictionary = _evidence(scope, 6)
  wrong_kind.event.kind = kind
  assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, wrong_kind).eligible)
 var q1: Dictionary = _evidence(scope, 6)
 q1.event.source = "q1"
 q1.witness.source = "q1"
 assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, q1).eligible)
 var stale: Dictionary = _evidence(scope, 6)
 stale.event.generation = 6
 assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, stale).eligible)
 var wrong_run: Dictionary = scope.duplicate(true)
 wrong_run.run_id = "other-run"
 assert(not Passive08.evaluate_verified_completion(selection, 4, identities, wrong_run, cds, evidence).eligible)
 for field: String in Passive08.WITNESS_FLAGS:
  var missing: Dictionary = _evidence(scope, 7)
  missing.witness.erase(field)
  assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, missing).eligible)
 for field: String in ["finished", "cancelled", "slot"]:
  var missing: Dictionary = _evidence(scope, 8)
  missing.original_cast.erase(field)
  assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, cds, missing).eligible)
 for count: Variant in [-1, 5, 4.0, true, "4"]:
  assert(not Passive08.evaluate_verified_completion(selection, count, identities, scope, cds, evidence).eligible)
 for bad: Variant in [-1.0, INF, NAN, "10", true]:
  assert(not Passive08.evaluate_verified_completion(selection, 4, identities, scope, {"q":bad, "e":1.0}, evidence).eligible)
 var wrong_unit: Dictionary = numeric.duplicate(true)
 wrong_unit.parameters["passive:08.remaining_cooldown_reduction"].unit = "seconds"
 assert(not Adapter.build(wrong_unit, equipment_source).accepted)
 var wrong_count: Dictionary = numeric.duplicate(true)
 wrong_count.parameters["passive:08.attack_interval"].value = 4.5
 assert(not Adapter.build(wrong_count, equipment_source).accepted)
 return {"accepted":true, "kind":"pure_helper_gate_only", "real_source_bridge_tested":false, "runtime_complete":false}

static func _evidence(scope: Dictionary, cast_id: int) -> Dictionary:
 var wave_id: String = "%d:%s:motion:%d" % [scope.generation, scope.room_id, cast_id]
 # Test fixture ONLY: these booleans are not a source bridge implementation.
 var witness: Dictionary = scope.duplicate(true)
 witness.merge({"cast_id":cast_id, "wave_id":wave_id, "source":"attack"}, true)
 for flag: String in Passive08.WITNESS_FLAGS: witness[flag] = true
 return {"schema":Passive08.EVIDENCE_SCHEMA,
  "event":{"kind":"ink_basic_finished", "cast_id":cast_id, "wave_id":wave_id, "source":"attack", "generation":scope.generation, "room_id":scope.room_id, "released_at":1.0, "finished_at":2.0, "settled_at":2.0, "reason":"contact", "hit_target_ids":["first-target"]},
  "original_cast":{"generation":scope.generation, "room_id":scope.room_id, "slot":"attack", "finished":true, "cancelled":false},
  "witness":witness}
