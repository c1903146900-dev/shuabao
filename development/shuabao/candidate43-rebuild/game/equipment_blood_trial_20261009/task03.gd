extends RefCounted
## Pure proportional task. Evidence is an internal contract, never public-event
## authentication. The real bound Sim/Model must establish every witness flag.
const ITEM_ID := "final:G03"
const TASK_ID := "task:G03"
const SCHEMA := "g03_verified_damage_commit_v1"
const MAX_EXACT := 9007199254740991
const FLAGS := ["source_bridge_connected","original_target_identity_verified","original_hp_commit_verified","first_damage_emission_verified","owner_commit_snapshot_verified","current_scope_verified","bound_owner_verified"]

static func valid_tuning(t: Dictionary) -> bool:
 if t.size() != 4 or t.get("stage_id") != "task:G03:1" or not t.get("reward_skill_points") is int or t.reward_skill_points != 1: return false
 return _number(t.get("threshold")) and float(t.threshold) > 0.0 and float(t.threshold) <= MAX_EXACT and _number(t.get("health_threshold")) and float(t.health_threshold) > 0.0 and float(t.health_threshold) <= 100.0

static func select_unique(inventory: Array, definitions: Dictionary) -> Dictionary:
 var out: Dictionary = _empty()
 var definition: Variant = definitions.get(ITEM_ID)
 if not definition is Dictionary or not _true(definition.get("mechanism_prepared")) or not definition.get("taskG03") is Dictionary or not valid_tuning(definition.taskG03): return out
 var seen: Dictionary = {}
 for item: Variant in inventory:
  if not item is Dictionary: return _empty()
  if item.get("id") != ITEM_ID: continue
  if not item.get("uid") is int or int(item.uid) < 0 or not item.get("count") is int or int(item.count) <= 0 or seen.has(item.uid): return _empty()
  if int(out.owned_copies) > 9223372036854775807-int(item.count): return _empty()
  seen[item.uid] = true
  out.owned_copies += int(item.count)
  out.equipped = true
  out.tuning = definition.taskG03.duplicate(true)
 return out

static func evaluate(selection: Dictionary, progress: Variant, completed: Variant, claims: Dictionary, scope: Dictionary, evidence: Dictionary, progress_carry: Variant = 0.0) -> Dictionary:
 if not _true(selection.get("equipped")) or selection.get("equipment_id") != ITEM_ID or selection.get("task_id") != TASK_ID or not selection.get("tuning") is Dictionary or not valid_tuning(selection.tuning): return _deny("g03_not_equipped_or_invalid_tuning")
 if not selection.get("owned_copies") is int or int(selection.owned_copies) <= 0: return _deny("g03_invalid_copy_count")
 if not valid_scope(scope): return _deny("g03_invalid_scope")
 var threshold: float = float(selection.tuning.threshold)
 if not _number(progress) or float(progress) < 0.0 or float(progress) > threshold or not completed is bool: return _deny("g03_invalid_progress")
 if completed: return _deny("g03_already_completed")
 if not _number(progress_carry) or float(progress_carry) < -float(progress) or float(progress_carry) >= threshold-float(progress): return _deny("g03_invalid_fractional_carry")
 # A saved carry is only an arithmetic remainder, never an alternate task
 # progress channel. High==threshold with a negative remainder is still below.
 # Four binary rounding units cover the normalized pair.
 if absf(float(progress_carry)) > absf(float(progress))*0.0000000000000008881784197001252: return _deny("g03_noncanonical_fractional_carry")
 if claims.size() != 2 or claims.get("scope") != scope or not claims.get("sequences") is Dictionary: return _deny("g03_invalid_current_claims")
 for sequence: Variant in claims.sequences:
  if not sequence is int or int(sequence) <= 0 or not _true(claims.sequences[sequence]): return _deny("g03_invalid_sequence_claim")
 if evidence.get("schema") != SCHEMA: return _deny("g03_internal_witness_required")
 var event: Variant = evidence.get("event")
 var commit: Variant = evidence.get("commit")
 var witness: Variant = evidence.get("witness")
 if not event is Dictionary or not commit is Dictionary or not witness is Dictionary: return _deny("g03_witness_records_required")
 for flag: String in FLAGS:
  if not _true(witness.get(flag)): return _deny("g03_verification_required:" + flag)
 if witness.get("scope") != scope or witness.get("proof") not in ["original_damage_hp_commit","original_p1_atomic_hp_commit"]: return _deny("g03_witness_scope_or_proof_mismatch")
 if not witness.get("commit_serial") is int or int(witness.commit_serial) <= 0: return _deny("g03_real_commit_identity_required")
 if event.get("kind") != "damage" or not _text(event.get("source")) or not _text(event.get("target")): return _deny("g03_actual_damage_required")
 if not event.get("cast_id") is int or int(event.cast_id) < 0 or not event.get("sequence") is int or int(event.sequence) <= 0: return _deny("g03_event_identity_required")
 if event.get("generation") != scope.generation or event.get("room_id") != scope.room_id: return _deny("g03_event_scope_mismatch")
 if witness.get("source") != event.source or witness.get("target") != event.target or witness.get("cast_id") != event.cast_id: return _deny("g03_witness_event_mismatch")
 if witness.proof == "original_p1_atomic_hp_commit" and (event.source != "yanguizhou_p1" or not _true(event.get("p1_supplement")) or not _true(event.get("final_damage_already_settled"))): return _deny("g03_atomic_p1_required")
 if witness.proof == "original_damage_hp_commit" and event.source == "yanguizhou_p1": return _deny("g03_p1_requires_atomic_witness")
 if commit.get("rank_category") not in ["ordinary","elite","boss"] or commit.get("target") != event.target or not _text(commit.get("owner_actor_id")): return _deny("g03_original_actors_required")
 for field: String in ["amount","target_hp_before","target_hp_after","owner_hp","owner_max_hp"]:
  if not _number(commit.get(field)): return _deny("g03_finite_commit_required:" + field)
 if not _number(event.get("amount")) or float(event.amount) != float(commit.amount) or float(commit.amount) <= 0.0: return _deny("g03_actual_amount_required")
 var before: float = float(commit.target_hp_before)
 var after: float = float(commit.target_hp_after)
 var roundoff: float = maxf(0.000000001,absf(before)*0.0000000000000008881784197001252)
 if before <= 0.0 or after < 0.0 or before-after <= 0.0 or float(commit.amount) > before or absf((before-after)-float(commit.amount)) > roundoff: return _deny("g03_original_hp_delta_required")
 var hp: float = float(commit.owner_hp)
 var maximum: float = float(commit.owner_max_hp)
 if maximum <= 0.0 or hp <= 0.0 or hp > maximum: return _deny("g03_live_commit_owner_required")
 if hp >= maximum*(float(selection.tuning.health_threshold)/100.0): return _deny("g03_health_not_strictly_below_threshold")
 if claims.sequences.has(event.sequence): return _deny("g03_packet_already_claimed")
 var increment: float = float(commit.amount)/maximum
 if not is_finite(increment) or increment <= 0.0: return _deny("g03_invalid_packet_ratio")
 var accumulated: Dictionary = accumulate(float(progress),float(progress_carry),increment,threshold)
 var complete: bool = accumulated.completed
 var ledger_progress: int = int(floor(float(accumulated.progress)))
 if float(accumulated.progress) == float(ledger_progress) and float(accumulated.carry) < 0.0: ledger_progress -= 1
 return {"eligible":true,"reason":"","equipment_id":ITEM_ID,"task_id":TASK_ID,"scope":scope.duplicate(true),"sequence":event.sequence,"commit_serial":witness.commit_serial,"actual_damage":float(commit.amount),"owner_hp_at_commit":hp,"owner_max_hp_at_commit":maximum,"ratio":increment,"progress_before":float(progress),"progress_carry_before":float(progress_carry),"progress_after":accumulated.progress,"progress_carry_after":accumulated.carry,"ledger_progress":ledger_progress,"completed":complete,"reward_skill_points":1 if complete else 0,"stage_id":"task:G03:1" if complete else "","reward_key":"task:G03:permanent_sp" if complete else ""}

static func accumulate(progress: float, carry: float, increment: float, threshold: float) -> Dictionary:
 # TwoSum retains the rounding remainder. In particular, an addition that rounds
 # UP to exactly500 cannot issue SP while its retained remainder is negative.
 # This is arithmetic bookkeeping only: no gameplay epsilon or integer rounding.
 if increment >= threshold: return {"progress":threshold,"carry":0.0,"completed":true}
 var sum: float = progress+increment
 var virtual_increment: float = sum-progress
 var remainder: float = (progress-(sum-virtual_increment))+(increment-virtual_increment)
 var tail: float = remainder+carry
 var combined: float = sum+tail
 var virtual_tail: float = combined-sum
 var residual: float = (sum-(combined-virtual_tail))+(tail-virtual_tail)
 var complete: bool = combined > threshold or (combined == threshold and residual >= 0.0)
 if complete: return {"progress":threshold,"carry":0.0,"completed":true}
 return {"progress":combined,"carry":residual,"completed":false}

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
