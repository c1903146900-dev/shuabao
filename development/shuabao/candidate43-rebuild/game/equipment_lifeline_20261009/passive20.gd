extends RefCounted
## Pure proposal only. Original HP commit authority lives in the Sim hook.
const ITEM_ID := "final:D04"
const PASSIVE_ID := "passive:20"
const SHIELD_ID := "equipment_passive20"
const SCHEMA := "d04_original_hp_commit_v1"
const FLAGS := ["original_owner_verified","original_metadata_identity_verified","adjacent_hp_commit_verified","current_scope_verified","bound_model_verified"]

static func valid_tuning(tuning: Dictionary) -> bool:
 if tuning.size() != 3: return false
 for key: String in ["health_threshold","shield_ratio"]:
  if not _number(tuning.get(key)) or float(tuning[key]) <= 0.0 or float(tuning[key]) > 100.0: return false
 return _number(tuning.get("duration")) and float(tuning.duration) > 0.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = _empty_selection()
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or not _true(definition.get("mechanism_prepared")) or definition.get("passives") != [PASSIVE_ID]: return out
 if not definition.get("passive20") is Dictionary or not valid_tuning(definition.passive20): return out
 var seen: Dictionary = {}
 for held: Variant in inventory:
  if not held is Dictionary: return _empty_selection()
  if held.get("id") != ITEM_ID: continue
  if not held.get("uid") is int or int(held.uid) < 0 or not held.get("count") is int or int(held.count) <= 0 or seen.has(held.uid): return _empty_selection()
  if int(out.owned_copies) > 9223372036854775807-int(held.count): return _empty_selection()
  seen[held.uid] = true
  out.owned_copies += int(held.count);out.equipped = true
  out.tuning = definition.passive20.duplicate(true)
 return out

static func propose(selection: Dictionary, quota: Dictionary, scope: Dictionary, evidence: Dictionary) -> Dictionary:
 if not valid_scope(scope): return _deny("d04_valid_original_scope_required")
 if not _true(selection.get("equipped")) or selection.get("item_id") != ITEM_ID or selection.get("passive_id") != PASSIVE_ID or not selection.get("owned_copies") is int or int(selection.owned_copies) <= 0 or not selection.get("tuning") is Dictionary or not valid_tuning(selection.tuning): return _deny("d04_not_equipped")
 if quota.size() != 4 or quota.get("run_id") != scope.run_id or quota.get("actor_id") != scope.actor_id or quota.get("passive_id") != PASSIVE_ID or not quota.get("rooms") is Dictionary: return _deny("d04_original_run_quota_required")
 for room: Variant in quota.rooms:
  if not _text(room) or not _true(quota.rooms[room]): return _deny("d04_invalid_room_quota")
 if quota.rooms.has(scope.room_id): return _deny("d04_room_already_used")
 if evidence.get("schema") != SCHEMA or evidence.get("scope") != scope or not evidence.get("commit") is Dictionary or not evidence.get("witness") is Dictionary: return _deny("d04_original_hp_commit_required")
 for flag: String in FLAGS:
  if not _true(evidence.witness.get(flag)): return _deny("d04_source_witness_required:" + flag)
 var commit: Dictionary = evidence.commit
 if not commit.get("serial") is int or int(commit.serial) <= 0 or commit.get("kind") != "original_incoming_damage" or not _text(commit.get("source")): return _deny("d04_original_damage_required")
 for key: String in ["hp_before","hp_after","lost","packet","max_hp"]:
  if not _number(commit.get(key)): return _deny("d04_finite_hp_commit_required")
 if float(commit.max_hp) <= 0.0 or float(commit.hp_before) <= 0.0 or float(commit.hp_before) > float(commit.max_hp) or float(commit.hp_after) <= 0.0 or float(commit.lost) <= 0.0 or float(commit.packet) <= 0.0: return _deny("d04_nonlethal_actual_loss_required")
 if float(commit.hp_after) != maxf(0.0,float(commit.hp_before)-float(commit.packet)) or float(commit.lost) != minf(float(commit.hp_before),float(commit.packet)) or float(commit.hp_after) >= float(commit.hp_before): return _deny("d04_exact_hp_commit_required")
 # Low HP on entry is allowed; the first qualifying actual wound triggers.
 # Merely equipping, entering, or changing maxHP is never a wound.
 if float(commit.hp_after) >= float(commit.max_hp)*float(selection.tuning.health_threshold)*0.01: return _deny("d04_not_strictly_below_threshold")
 var amount: float = float(commit.max_hp)*float(selection.tuning.shield_ratio)*0.01
 if not is_finite(amount) or amount <= 0.0: return _deny("d04_invalid_shield_amount")
 return {"eligible":true,"reason":"","claim_room":scope.room_id,"shield_id":SHIELD_ID,"shield_amount":amount,"duration":float(selection.tuning.duration),"trigger_max_hp":float(commit.max_hp),"hp_after":float(commit.hp_after),"commit_serial":int(commit.serial)}

static func valid_scope(scope: Dictionary) -> bool:
 return scope.size() == 4 and _text(scope.get("run_id")) and _text(scope.get("actor_id")) and _text(scope.get("room_id")) and scope.get("generation") is int and int(scope.generation) >= 0
static func _empty_selection() -> Dictionary:
 return {"equipped":false,"owned_copies":0,"item_id":ITEM_ID,"passive_id":PASSIVE_ID,"tuning":{}}
static func _number(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v))
static func _text(v: Variant) -> bool:
 return v is String and not str(v).strip_edges().is_empty()
static func _true(v: Variant) -> bool:
 return v is bool and v
static func _deny(reason: String) -> Dictionary:
 return {"eligible":false,"reason":reason}
