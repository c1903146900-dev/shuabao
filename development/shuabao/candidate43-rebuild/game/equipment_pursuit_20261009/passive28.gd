extends RefCounted
## PURE SPECIFICATION HELPER, not an authenticator or a runtime consumer.
## Every witness must be constructed by a future PRIVATE real-source bridge.
## Public kill events, matching strings, or these booleans do not prove a kill.
const ITEM_ID := "final:B02"
const PASSIVE_ID := "passive:28"
const EVIDENCE_SCHEMA := "b02_internal_verified_death_v1"
const BUFF_SCHEMA := "b02_prepared_buff_v1"
const STEADY_BOUNDARY := "same_room_uninterrupted_ownership"
const WITNESS_FLAGS := ["private_bridge_call_verified", "original_target_identity_verified", "original_owner_identity_verified", "committed_death_verified", "owner_participation_verified", "scope_current_verified", "owner_clock_verified", "ownership_continuity_verified"]
const PENDING_BOUNDARIES := ["last_copy_sale", "rebuy_after_sale", "undo_after_sale", "room_transition", "death", "rest", "new_run"]

static func valid_tuning(tuning: Dictionary) -> bool:
 if tuning.size() != 3: return false
 for key: String in ["move_bonus", "attack_speed_bonus"]:
  if not _number(tuning.get(key)) or float(tuning[key]) < 0.0 or float(tuning[key]) > 100.0: return false
 return _number(tuning.get("duration")) and float(tuning.duration) > 0.0

static func select_unique(inventory: Array, prepared_definitions: Dictionary) -> Dictionary:
 var result: Dictionary = _empty_selection()
 var definition: Variant = prepared_definitions.get(ITEM_ID)
 if not definition is Dictionary or not _enabled(definition.get("mechanism_prepared")) or definition.get("passives") != [PASSIVE_ID]: return result
 if not definition.get("passive28") is Dictionary or not valid_tuning(definition.passive28): return result
 var seen: Dictionary = {}
 for held: Variant in inventory:
  if not held is Dictionary: return _empty_selection()
  if held.get("id") != ITEM_ID: continue
  if not held.get("uid") is int or int(held.uid) < 0 or not held.get("count") is int or int(held.count) <= 0 or seen.has(held.uid): return _empty_selection()
  seen[held.uid] = true
  if int(result.owned_copies) > 9223372036854775807 - int(held.count): return _empty_selection()
  result.owned_copies += int(held.count)
  result.equipped = true
  result.tuning = definition.passive28.duplicate(true)
 return result

static func propose_verified_kill(selection: Dictionary, previous_buff: Dictionary, claims: Dictionary, context: Dictionary, now: Variant, evidence: Dictionary) -> Dictionary:
 var boundary: Dictionary = _check_context(context)
 if not boundary.is_empty(): return boundary
 if not _enabled(context.owner_alive): return _deny("dead_owner_cannot_trigger")
 if not _valid_selection(selection): return _deny("b02_not_equipped_or_invalid_selection")
 if not _number(now) or float(now) < 0.0: return _deny("invalid_owner_clock_now")
 var scope: Dictionary = context.scope
 var prior: Dictionary = _check_previous(previous_buff, context, float(now))
 if not prior.is_empty(): return prior
 if not _valid_claims(claims, scope): return _deny("invalid_or_stale_claim_scope")
 if evidence.get("schema") != EVIDENCE_SCHEMA: return _deny("internal_verified_death_required")
 if not evidence.get("scope") is Dictionary or not _scope_matches(evidence.scope, scope): return _deny("evidence_scope_mismatch")
 var commit: Variant = evidence.get("death_commit")
 var witness: Variant = evidence.get("witness")
 if not commit is Dictionary or not witness is Dictionary: return _deny("internal_commit_and_witness_required")
 for flag: String in WITNESS_FLAGS:
  if not _enabled(witness.get(flag)): return _deny("bridge_verification_required:" + flag)
 if not witness.get("scope") is Dictionary or not _scope_matches(witness.scope, scope): return _deny("witness_scope_mismatch")
 if witness.get("continuity_id") != context.continuity_id: return _deny("ownership_continuity_mismatch")
 if witness.get("clock") != "owner_actor_time" or not _number(witness.get("now")) or float(witness.now) != float(now): return _deny("owner_clock_witness_mismatch")
 if not _enabled(commit.get("dead")) or not _number(commit.get("hp_after")) or float(commit.hp_after) != 0.0: return _deny("committed_death_required")
 for field: String in ["target_id", "death_commit_id", "source"]:
  if not _text(commit.get(field)) or witness.get(field) != commit[field]: return _deny("commit_identity_mismatch:" + field)
 # No Q/E-only filter: source attribution belongs to the authentic bridge.
 # One corpse cannot refresh via another notification or changed receipt ID.
 if claims.by_target.has(commit.target_id): return _deny("target_death_already_claimed")
 if claims.by_target.values().has(commit.death_commit_id): return _deny("death_commit_already_claimed")
 var expiry: float = float(now) + float(selection.tuning.duration)
 if not _number(expiry) or expiry <= float(now): return _deny("unrepresentable_expiry")
 var buff: Dictionary = {"schema":BUFF_SCHEMA, "passive_id":PASSIVE_ID, "scope":scope.duplicate(true), "continuity_id":context.continuity_id,
  "granted_at":float(now), "expires_at":expiry, "move_fraction":float(selection.tuning.move_bonus) / 100.0,
  "attack_speed_fraction":float(selection.tuning.attack_speed_bonus) / 100.0,
  "duration":float(selection.tuning.duration), "last_death_commit_id":commit.death_commit_id}
 # The future caller must atomically commit this single buff and claim, then
 # refresh existing derived stats before observers. No state is changed here.
 return {"eligible":true, "reason":"prepared_only", "prepared_only":true, "runtime_complete":false, "shop_admitted":false,
  "source_bridge_required":true, "consume_claim":true, "claim_to_add":{"target_id":commit.target_id, "death_commit_id":commit.death_commit_id},
  "buff_proposal":buff, "refreshes_existing":not previous_buff.is_empty()}

static func inspect_same_scope(buff: Dictionary, context: Dictionary, now: Variant) -> Dictionary:
 var boundary: Dictionary = _check_context(context)
 if not boundary.is_empty(): return boundary
 # Raw-stat cleanup on death is not inferred from common.hero_died().
 if not _enabled(context.owner_alive): return _pending("death_projection_and_cleanup")
 if not _number(now) or float(now) < 0.0: return _deny("invalid_owner_clock_now")
 var previous: Dictionary = _check_previous(buff, context, float(now))
 if not previous.is_empty(): return previous
 if buff.is_empty(): return {"eligible":true, "active":false, "reason":"no_buff", "prepared_only":true, "runtime_complete":false, "shop_admitted":false}
 var active: bool = float(now) < float(buff.expires_at)
 return {"eligible":true, "active":active, "reason":"within_scope_only", "prepared_only":true, "runtime_complete":false, "shop_admitted":false,
  "move_fraction":float(buff.move_fraction) if active else 0.0, "attack_speed_fraction":float(buff.attack_speed_fraction) if active else 0.0,
  "remaining":maxf(0.0, float(buff.expires_at) - float(now))}

static func _check_context(context: Dictionary) -> Dictionary:
 if context.get("boundary") != STEADY_BOUNDARY:
  return _pending(str(context.get("boundary", "missing_boundary_contract")))
 if not context.get("scope") is Dictionary or not _valid_scope(context.scope) or not _text(context.get("continuity_id")) or not context.get("owner_alive") is bool: return _deny("invalid_current_context")
 return {}

static func _check_previous(buff: Dictionary, context: Dictionary, now: float) -> Dictionary:
 if buff.is_empty(): return {}
 if not _valid_buff(buff): return _deny("invalid_previous_buff")
 if buff.scope.run_id != context.scope.run_id or buff.scope.owner_token != context.scope.owner_token: return _deny("prior_buff_owner_or_run_mismatch")
 # A pending boundary yields no modifiers, active flag, claim, or buff action.
 if not _scope_matches(buff.scope, context.scope): return _pending("room_transition_expiry")
 if buff.continuity_id != context.continuity_id: return _pending("sale_rebuy_or_undo_continuity")
 if now < float(buff.granted_at): return _deny("owner_clock_before_grant")
 return {}

static func _valid_buff(buff: Dictionary) -> bool:
 if buff.get("schema") != BUFF_SCHEMA or buff.get("passive_id") != PASSIVE_ID or not buff.get("scope") is Dictionary or not _valid_scope(buff.scope) or not _text(buff.get("continuity_id")) or not _text(buff.get("last_death_commit_id")): return false
 for key: String in ["granted_at", "expires_at", "move_fraction", "attack_speed_fraction", "duration"]:
  if not _number(buff.get(key)) or float(buff[key]) < 0.0: return false
 if float(buff.duration) <= 0.0 or float(buff.expires_at) <= float(buff.granted_at) or float(buff.expires_at) != float(buff.granted_at) + float(buff.duration): return false
 return float(buff.move_fraction) <= 1.0 and float(buff.attack_speed_fraction) <= 1.0

static func _valid_selection(selection: Dictionary) -> bool:
 return _enabled(selection.get("equipped")) and selection.get("item_id") == ITEM_ID and selection.get("passive_id") == PASSIVE_ID and selection.get("owned_copies") is int and int(selection.owned_copies) > 0 and selection.get("tuning") is Dictionary and valid_tuning(selection.tuning)

static func _valid_claims(claims: Dictionary, scope: Dictionary) -> bool:
 if claims.size() != 2 or not claims.get("scope") is Dictionary or not _scope_matches(claims.scope, scope) or not claims.get("by_target") is Dictionary: return false
 var ids: Dictionary = {}
 for target: Variant in claims.by_target:
  var id: Variant = claims.by_target[target]
  if not _text(target) or not _text(id) or ids.has(id): return false
  ids[id] = true
 return true

static func _valid_scope(scope: Dictionary) -> bool:
 return scope.size() == 4 and _text(scope.get("run_id")) and _text(scope.get("owner_token")) and _text(scope.get("room_id")) and scope.get("generation") is int and int(scope.generation) >= 0

static func _scope_matches(a: Dictionary, b: Dictionary) -> bool:
 return _valid_scope(a) and _valid_scope(b) and a == b

static func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

static func _text(value: Variant) -> bool:
 return value is String and not str(value).strip_edges().is_empty()

static func _enabled(value: Variant) -> bool:
 return value is bool and value

static func _empty_selection() -> Dictionary:
 return {"equipped":false, "item_id":ITEM_ID, "passive_id":PASSIVE_ID, "owned_copies":0, "tuning":{}}

static func _deny(reason: String) -> Dictionary:
 return {"eligible":false, "reason":reason, "prepared_only":true, "runtime_complete":false, "shop_admitted":false, "source_bridge_required":true, "consume_claim":false}

static func _pending(boundary: String) -> Dictionary:
 var result: Dictionary = _deny("pending_lifecycle:" + boundary)
 result["pending_lifecycle"] = true
 return result
