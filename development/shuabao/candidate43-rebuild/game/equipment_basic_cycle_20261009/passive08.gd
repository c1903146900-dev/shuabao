extends RefCounted
## Pure B04 proposal; no Sim access, counters, ownership changes or CD writes.
## This trusts an INTERNAL bridge contract, never public event contents alone.
const ITEM_ID := "final:B04"
const PASSIVE_ID := "passive:08"
const EVIDENCE_SCHEMA := "b04_verified_basic_completion_v1"
const WITNESS_FLAGS := ["source_bridge_connected", "original_state_identity_verified", "terminal_frame_verified", "first_terminal_verified", "cast_lookup_verified", "scope_current_verified", "state_retired"]

static func valid_tuning(tuning: Dictionary) -> bool:
 if tuning.size() != 2 or not tuning.has("attack_interval") or not tuning.has("remaining_cooldown_reduction"): return false
 var interval: Variant = tuning.attack_interval
 var reduction: Variant = tuning.remaining_cooldown_reduction
 return interval is int and int(interval) > 0 and _number(reduction) and float(reduction) >= 0.0 and float(reduction) <= 100.0

static func select_unique(inventory: Array, prepared_definitions: Dictionary) -> Dictionary:
 var result: Dictionary = {"equipped":false, "item_id":ITEM_ID, "passive_id":PASSIVE_ID, "uid":-1, "owned_copies":0, "tuning":{}}
 var definition: Variant = prepared_definitions.get(ITEM_ID)
 if not definition is Dictionary or not _enabled(definition.get("mechanism_prepared")): return result
 if definition.get("passives") != [PASSIVE_ID]: return result
 var tuning: Variant = definition.get("passive08")
 if not tuning is Dictionary or not valid_tuning(tuning): return result
 var seen: Dictionary = {}
 for held: Variant in inventory:
  if not held is Dictionary: return _empty_selection()
  if held.get("id") != ITEM_ID: continue
  var uid: Variant = held.get("uid")
  var count: Variant = held.get("count")
  if not uid is int or int(uid) < 0 or not count is int or int(count) <= 0: return _empty_selection()
  # A repeated UID is ambiguous ownership, never a second copy or a free pass.
  if seen.has(uid): return _empty_selection()
  seen[uid] = true
  if not result.equipped:
   result.equipped = true
   result.uid = int(uid)
   result.tuning = tuning.duplicate(true)
  if int(result.owned_copies) > 9223372036854775807 - int(count): return _empty_selection()
  result.owned_copies += int(count)
 return result

static func evaluate_verified_completion(selection: Dictionary, previous_remainder: Variant, completed_identities: Dictionary, current_scope: Dictionary, current_cooldowns: Dictionary, evidence: Dictionary) -> Dictionary:
 if not _valid_selection(selection): return _deny("b04_not_equipped_or_invalid_selection")
 if not _valid_scope(current_scope): return _deny("invalid_current_scope")
 var interval: int = int(selection.tuning.attack_interval)
 if not previous_remainder is int or int(previous_remainder) < 0 or int(previous_remainder) >= interval: return _deny("invalid_previous_remainder")
 if not _valid_claims(completed_identities, current_scope): return _deny("invalid_current_scope_identity_set")
 if current_cooldowns.size() != 2 or not current_cooldowns.has("q") or not current_cooldowns.has("e"): return _deny("exact_qe_cooldowns_required")
 for slot: String in ["q", "e"]:
  if not _number(current_cooldowns[slot]) or float(current_cooldowns[slot]) < 0.0: return _deny("invalid_current_cooldown:" + slot)
 if evidence.get("schema") != EVIDENCE_SCHEMA: return _deny("verified_completion_schema_required")
 var event: Variant = evidence.get("event")
 var original: Variant = evidence.get("original_cast")
 var witness: Variant = evidence.get("witness")
 if not event is Dictionary or not original is Dictionary or not witness is Dictionary: return _deny("verified_completion_records_required")
 for flag: String in WITNESS_FLAGS:
  if not _enabled(witness.get(flag)): return _deny("bridge_verification_required:" + flag)
 if not _scope_matches(witness, current_scope): return _deny("witness_scope_mismatch")
 if not _source_scope_matches(event, current_scope) or not _source_scope_matches(original, current_scope): return _deny("completion_scope_mismatch")
 if event.get("kind") != "ink_basic_finished": return _deny("ink_basic_finished_required")
 if event.get("source") not in ["attack", "dash_attack"]: return _deny("original_basic_source_required")
 if event.get("reason") not in ["contact", "path_end", "blocked"]: return _deny("natural_terminal_required")
 var cast_id: Variant = event.get("cast_id")
 var wave_id: Variant = event.get("wave_id")
 if not cast_id is int or int(cast_id) <= 0 or not _text(wave_id): return _deny("original_completion_identity_required")
 # _casts is indexed by cast_id; its record itself has no cast_id or wave_id.
 if witness.get("cast_id") != cast_id or not witness.get("cast_id") is int or witness.get("wave_id") != wave_id or witness.get("source") != event.source: return _deny("witness_identity_mismatch")
 if original.get("slot") != "attack": return _deny("original_cast_not_attack")
 if not original.get("cancelled") is bool or original.cancelled: return _deny("original_cast_cancelled_or_missing")
 if not _enabled(original.get("finished")): return _deny("original_cast_not_finished")
 for field: String in ["released_at", "finished_at", "settled_at"]:
  if not _number(event.get(field)) or float(event[field]) < 0.0: return _deny("invalid_terminal_time:" + field)
 if float(event.finished_at) < float(event.released_at): return _deny("terminal_before_release")
 if not event.get("hit_target_ids") is Array: return _deny("terminal_hit_list_required")
 for target: Variant in event.hit_target_ids:
  if not _text(target): return _deny("invalid_terminal_hit_identity")
 # An empty hit list is valid: path_end / blocked have no hit requirement.
 var claims: Dictionary = completed_identities.by_cast
 if claims.has(cast_id): return _deny("completion_already_claimed" if claims[cast_id] == wave_id else "cast_wave_identity_conflict")
 if claims.values().has(wave_id): return _deny("wave_already_claimed")
 var next_count: int = int(previous_remainder) + 1
 var triggered: bool = next_count == interval
 var after: Dictionary = {}
 var reductions: Dictionary = {}
 var multiplier: float = 1.0 - float(selection.tuning.remaining_cooldown_reduction) / 100.0 if triggered else 1.0
 for slot: String in ["q", "e"]:
  after[slot] = float(current_cooldowns[slot]) * multiplier
  reductions[slot] = float(current_cooldowns[slot]) - float(after[slot])
  if not _number(after[slot]) or float(after[slot]) < 0.0: return _deny("invalid_reduction_result")
 # Zero CD still consumes the fifth completion; no credit or deferred refund.
 # The caller atomically commits claim + remainder + BOTH CDs before observers.
 return {"eligible":true, "reason":"", "passive_id":PASSIVE_ID, "scope":current_scope.duplicate(true), "claim_to_add":{"cast_id":cast_id, "wave_id":wave_id}, "consume_claim":true, "remainder_before":int(previous_remainder), "remainder_after":0 if triggered else next_count, "triggered":triggered, "cooldowns_before":current_cooldowns.duplicate(true), "cooldowns_after":after, "reductions":reductions, "source_bridge_required":true, "runtime_complete":false}

static func _valid_selection(selection: Dictionary) -> bool:
 if not _enabled(selection.get("equipped")) or selection.get("item_id") != ITEM_ID or selection.get("passive_id") != PASSIVE_ID: return false
 if not selection.get("uid") is int or int(selection.uid) < 0 or not selection.get("owned_copies") is int or int(selection.owned_copies) <= 0: return false
 return selection.get("tuning") is Dictionary and valid_tuning(selection.tuning)

static func _valid_claims(completed: Dictionary, scope: Dictionary) -> bool:
 if completed.size() != 2 or not completed.get("scope") is Dictionary or not completed.get("by_cast") is Dictionary: return false
 if not _scope_matches(completed.scope, scope): return false
 var waves: Dictionary = {}
 for cast_id: Variant in completed.by_cast:
  var wave_id: Variant = completed.by_cast[cast_id]
  if not cast_id is int or int(cast_id) <= 0 or not _text(wave_id) or waves.has(wave_id): return false
  waves[wave_id] = true
 return true

static func _valid_scope(scope: Dictionary) -> bool:
 return _text(scope.get("run_id")) and scope.get("generation") is int and int(scope.generation) >= 0 and _text(scope.get("room_id"))

static func _source_scope_matches(value: Dictionary, scope: Dictionary) -> bool:
 return value.get("generation") is int and value.generation == scope.generation and _text(value.get("room_id")) and value.room_id == scope.room_id

static func _scope_matches(value: Dictionary, scope: Dictionary) -> bool:
 return _valid_scope(value) and value.run_id == scope.run_id and _source_scope_matches(value, scope)

static func _text(value: Variant) -> bool:
 return value is String and not str(value).strip_edges().is_empty()

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _enabled(value: Variant) -> bool:
 return value is bool and value

static func _empty_selection() -> Dictionary:
 return {"equipped":false, "item_id":ITEM_ID, "passive_id":PASSIVE_ID, "uid":-1, "owned_copies":0, "tuning":{}}

static func _deny(reason: String) -> Dictionary:
 return {"eligible":false, "reason":reason, "passive_id":PASSIVE_ID, "consume_claim":false, "source_bridge_required":true, "runtime_complete":false}
