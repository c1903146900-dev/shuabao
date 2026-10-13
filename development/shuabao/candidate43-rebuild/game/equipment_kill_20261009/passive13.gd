extends RefCounted
## Pure selection and refund proposal. Inert until source bridge connected.
## Never authenticates an event, changes Sim/CD, owns claims, or grants task/SP.
## The trusted source bridge must verify the real kill and original cast first.
const ITEM_ID := "final:B01"
const PASSIVE_ID := "passive:13"
const TUNING_KEYS := ["cooldown_refund"]
const DIRECT_SKILLS := {"q1":"q", "q2":"q", "q3":"q", "e1":"e", "e2":"e", "e3":"e"}

static func valid_tuning(tuning: Dictionary) -> bool:
 if tuning.size() != 1 or not tuning.has("cooldown_refund"): return false
 var value: Variant = tuning.cooldown_refund
 return _number(value) and float(value) >= 0.0 and float(value) <= 100.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var result: Dictionary = {"equipped":false, "item_id":ITEM_ID, "passive_id":PASSIVE_ID, "uid":-1, "owned_copies":0, "tuning":{}}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or definition.get("supported") != true: return result
 if not definition.get("passives") is Array or definition.passives != [PASSIVE_ID]: return result
 var tuning: Variant = definition.get("passive13")
 if not tuning is Dictionary or not valid_tuning(tuning): return result
 var seen: Dictionary = {}
 for held: Variant in inventory:
  if not held is Dictionary or held.get("id") != ITEM_ID: continue
  var uid: Variant = held.get("uid")
  var count: Variant = held.get("count")
  if not uid is int or int(uid) < 0 or not count is int or int(count) <= 0 or seen.has(uid): continue
  seen[uid] = true
  if not result.equipped:
   result.equipped = true
   result.uid = int(uid)
   result.tuning = tuning.duplicate(true)
  result.owned_copies += int(count)
 return result

static func evaluate_verified_kill(selection: Dictionary, verified_kill: Dictionary, source_casts: Dictionary, current_scope: Dictionary, current_cooldown: Variant, refunded_casts: Dictionary) -> Dictionary:
 # These explicit flags are a caller contract, never evidence manufactured by
 # this helper. Public emit_event data cannot be promoted into a verified kill.
 if not _enabled(verified_kill.get("source_bridge_connected")): return _inert("source_bridge_not_connected")
 if not _enabled(verified_kill.get("attribution_verified")): return _inert("kill_attribution_not_verified")
 if not _valid_selection(selection): return _inert("b01_not_equipped_or_invalid_selection")
 if verified_kill.get("kind") != "kill": return _inert("actual_kill_required")
 if not _valid_scope(current_scope) or not _scope_matches(verified_kill, current_scope): return _inert("kill_scope_mismatch")
 var target: Variant = verified_kill.get("target")
 if not target is String or str(target).is_empty(): return _inert("kill_target_missing")
 var cast_id: Variant = verified_kill.get("cast_id")
 if not cast_id is int or int(cast_id) <= 0: return _inert("original_cast_id_required")
 var original: Variant = source_casts.get(cast_id)
 if not original is Dictionary or not _scope_matches(original, current_scope): return _inert("original_cast_scope_mismatch")
 if not original.get("cancelled") is bool or original.cancelled: return _inert("original_cast_cancelled_or_invalid")
 if not original.get("finished") is bool: return _inert("original_cast_finished_state_missing")
 var slot: Variant = original.get("slot")
 if slot not in ["q", "e"]: return _inert("original_cast_not_qe")
 var source: Variant = verified_kill.get("source")
 var credited_skill: Variant = verified_kill.get("parent_skill") if source == "yanguizhou_p1" else source
 if source == "hex_yanguizhou_h04":
  # The existing Q2 ownership source verifies its ORIGINAL live H04 packet.
  # A cast_id or this source name alone can never establish that ownership.
  if not _enabled(verified_kill.get("original_q2_hex_receipt_verified")) or verified_kill.get("parent_skill") != "q2" or slot != "q":
   return _inert("original_q2_hex_receipt_not_verified")
  credited_skill = "q2"
 if not credited_skill is String or not DIRECT_SKILLS.has(credited_skill) or DIRECT_SKILLS[credited_skill] != slot:
  return _inert("verified_skill_does_not_match_original_cast")
 # A finished original cast may settle a legitimate P1 supplement. Its source
 # slot/scope still owns it; never mint a new cast for this supplemental kill.
 var key: String = "%d:%s:%d" % [int(current_scope.generation), str(current_scope.room_id), int(cast_id)]
 if refunded_casts.has(key): return _inert("original_cast_already_claimed")
 if not _number(current_cooldown) or float(current_cooldown) < 0.0: return _inert("invalid_current_cooldown")
 var cooldown: float = float(current_cooldown)
 var refund: float = cooldown * (float(selection.tuning.cooldown_refund) / 100.0)
 var after: float = cooldown - refund
 if not is_finite(refund) or not is_finite(after) or after < 0.0: return _inert("invalid_refund_result")
 # Even zero-CD/zero-percent qualifying kills consume the once-per-cast claim.
 # The bridge commits this claim before observers, even when refund == 0.
 return {"eligible":true, "reason":"", "slot":str(slot), "cast_id":int(cast_id), "claim_key":key, "refund":refund, "cooldown_before":cooldown, "cooldown_after":after, "consume_claim":true, "passive_id":PASSIVE_ID, "source_bridge_required":true}

static func _valid_selection(selection: Dictionary) -> bool:
 if not _enabled(selection.get("equipped")) or selection.get("item_id") != ITEM_ID or selection.get("passive_id") != PASSIVE_ID: return false
 var uid: Variant = selection.get("uid")
 var copies: Variant = selection.get("owned_copies")
 if not uid is int or int(uid) < 0 or not copies is int or int(copies) <= 0: return false
 var tuning: Variant = selection.get("tuning")
 return tuning is Dictionary and valid_tuning(tuning)

static func _valid_scope(scope: Dictionary) -> bool:
 var generation: Variant = scope.get("generation")
 var room: Variant = scope.get("room_id")
 return generation is int and int(generation) >= 0 and room is String and not str(room).is_empty()

static func _scope_matches(value: Dictionary, scope: Dictionary) -> bool:
 return _valid_scope(value) and value.generation == scope.generation and value.room_id == scope.room_id

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _enabled(value: Variant) -> bool:
 return value is bool and value

static func _inert(reason: String) -> Dictionary:
 return {"eligible":false, "reason":reason, "slot":"", "cast_id":0, "claim_key":"", "refund":0.0, "cooldown_before":0.0, "cooldown_after":0.0, "consume_claim":false, "passive_id":PASSIVE_ID, "source_bridge_required":true}
