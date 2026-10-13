extends RefCounted
## Pure G02 task proposal. It trusts the strict internal source bridge contract;
## public kill dictionaries, field booleans and event-log entries alone prove nothing.
const ITEM_ID := "final:G02"
const TASK_ID := "task:G02"
const SCHEMA := "g02_verified_own_death_v1"
const MAX_EXACT := 9007199254740991
const FLAGS := ["source_bridge_connected","original_target_identity_verified","original_death_commit_verified","hero_killed_return_verified","first_kill_emission_verified","current_scope_verified","bound_owner_verified"]

static func valid_tuning(t: Dictionary) -> bool:
 if t.size() != 6 or t.get("stage_id") != "task:G02:1" or t.get("reward_skill_points") != 1 or not t.get("reward_skill_points") is int: return false
 for key: String in ["threshold","normal_weight","elite_weight","boss_weight"]:
  if not t.get(key) is int or int(t[key]) <= 0 or int(t[key]) > MAX_EXACT: return false
 return true

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = {"equipped":false,"equipment_id":ITEM_ID,"task_id":TASK_ID,"owned_copies":0,"tuning":{}}
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or not _true(definition.get("mechanism_prepared")) or not definition.get("taskG02") is Dictionary or not valid_tuning(definition.taskG02): return out
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return _empty()
  if item.get("id") != ITEM_ID: continue
  if not item.get("uid") is int or int(item.uid) < 0 or not item.get("count") is int or int(item.count) <= 0 or seen.has(item.uid): return _empty()
  if int(out.owned_copies) > 9223372036854775807-int(item.count): return _empty()
  seen[item.uid] = true
  out.owned_copies += int(item.count)
  out.equipped = true
  out.tuning = definition.taskG02.duplicate(true)
 return out

static func evaluate(selection: Dictionary, progress: Variant, completed: Variant, claims: Dictionary, scope: Dictionary, evidence: Dictionary) -> Dictionary:
 if not _true(selection.get("equipped")) or selection.get("equipment_id") != ITEM_ID or selection.get("task_id") != TASK_ID or not selection.get("tuning") is Dictionary or not valid_tuning(selection.tuning): return _deny("g02_not_equipped_or_invalid_tuning")
 if not selection.get("owned_copies") is int or int(selection.owned_copies) <= 0: return _deny("g02_invalid_copy_count")
 if not valid_scope(scope): return _deny("g02_invalid_scope")
 var threshold: int = int(selection.tuning.threshold)
 if not progress is int or int(progress) < 0 or int(progress) > threshold or not completed is bool: return _deny("g02_invalid_progress")
 if completed: return _deny("g02_already_completed")
 if int(progress) == threshold: return _deny("g02_inconsistent_completion")
 if claims.size() != 2 or claims.get("scope") != scope or not claims.get("targets") is Dictionary: return _deny("g02_invalid_current_claims")
 for target: Variant in claims.targets:
  if not _text(target) or not _true(claims.targets[target]): return _deny("g02_invalid_target_claim")
 if evidence.get("schema") != SCHEMA: return _deny("g02_internal_witness_required")
 var event: Variant = evidence.get("event")
 var original: Variant = evidence.get("original_target")
 var witness: Variant = evidence.get("witness")
 if not event is Dictionary or not original is Dictionary or not witness is Dictionary: return _deny("g02_witness_records_required")
 for flag: String in FLAGS:
  if not _true(witness.get(flag)): return _deny("g02_verification_required:" + flag)
 if witness.get("scope") != scope: return _deny("g02_witness_scope_mismatch")
 if witness.get("proof") not in ["original_damage_death","original_p1_atomic_death"]: return _deny("g02_unknown_death_source")
 if not witness.get("death_serial") is int or int(witness.death_serial) <= 0: return _deny("g02_real_death_identity_required")
 if event.get("kind") != "kill" or event.get("credit") != "solo_lethal" or not _text(event.get("source")): return _deny("g02_solo_actual_kill_required")
 if not event.get("cast_id") is int or int(event.cast_id) < 0 or not event.get("sequence") is int or int(event.sequence) <= 0: return _deny("g02_event_identity_required")
 if witness.get("source") != event.source or not witness.get("cast_id") is int or witness.cast_id != event.cast_id: return _deny("g02_witness_source_mismatch")
 if witness.proof == "original_p1_atomic_death" and (event.source != "yanguizhou_p1" or not _true(event.get("p1_supplement"))): return _deny("g02_atomic_p1_source_required")
 if witness.proof == "original_damage_death" and event.source == "yanguizhou_p1": return _deny("g02_p1_requires_atomic_receipt")
 for record: Dictionary in [event,original]:
  if not record.get("generation") is int or record.generation != scope.generation or record.get("room_id") != scope.room_id: return _deny("g02_source_scope_mismatch")
 var target: Variant = original.get("actor_id")
 if not _text(target) or event.get("target") != target or witness.get("target") != target: return _deny("g02_original_target_mismatch")
 if not _true(original.get("dead")) or not _number(original.get("hp")) or float(original.hp) != 0.0: return _deny("g02_original_target_not_dead")
 var rank: Variant = original.get("rank_category")
 if rank not in ["ordinary","elite","boss"] or witness.get("rank_category") != rank: return _deny("g02_original_rank_required")
 if claims.targets.has(target): return _deny("g02_target_already_claimed")
 var weight_key: String = "normal_weight" if rank == "ordinary" else str(rank) + "_weight"
 var weight: int = int(selection.tuning[weight_key])
 var after: int = mini(threshold,int(progress)+weight)
 var complete: bool = after == threshold
 return {"eligible":true,"reason":"","equipment_id":ITEM_ID,"task_id":TASK_ID,"scope":scope.duplicate(true),"target":target,"rank_category":rank,"weight":weight,"progress_before":int(progress),"progress_after":after,"completed":complete,"reward_skill_points":1 if complete else 0,"stage_id":"task:G02:1" if complete else "","reward_key":"task:G02:permanent_sp" if complete else "","death_serial":witness.death_serial}

static func valid_scope(scope: Dictionary) -> bool:
 return scope.size() == 4 and _text(scope.get("run_id")) and _text(scope.get("actor_id")) and scope.get("generation") is int and int(scope.generation) >= 0 and _text(scope.get("room_id"))
static func _text(v: Variant) -> bool:
 return v is String and not str(v).strip_edges().is_empty()
static func _true(v: Variant) -> bool:
 return v is bool and v
static func _number(v: Variant) -> bool:
 return (v is int or v is float) and is_finite(float(v))
static func _empty() -> Dictionary:
 return {"equipped":false,"equipment_id":ITEM_ID,"task_id":TASK_ID,"owned_copies":0,"tuning":{}}
static func _deny(reason: String) -> Dictionary:
 return {"eligible":false,"reason":reason}
