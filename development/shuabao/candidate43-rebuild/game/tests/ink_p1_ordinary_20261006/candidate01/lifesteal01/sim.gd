extends "res://tests/ink_p1_ordinary_20261006/candidate01/sim.gd"
## Narrow final-correction lifesteal adapter. The passed 342-check parent stays
## frozen; no damage, hit, critical, defence, movement or core step is replayed.
var ink_p1_lifesteal_receipts: Array = []
var _p1_lifesteal_claims: Dictionary = {}

func emit_event(kind: String, data: Dictionary = {}) -> void:
 var state: Dictionary = _p1_lifesteal_source(kind,data)
 if state.is_empty():
  super.emit_event(kind,data)
  return
 var id: int = int(state.context.cast_id)
 var enemy: Dictionary = state.targets[0].enemy
 var key: String = "%d:%s:%d" % [int(state.context.generation),str(state.context.room_id),id]
 # This event occurs only after the parent's atomic HP/CD/death-state commit.
 # Claim and snapshot before outward callbacks; cancellation cannot reopen it.
 _p1_lifesteal_claims[key] = true
 var flags: Dictionary = {"direct":true,"area":true,"basic_attack":false,"active_skill":true,"parent_skill":str(state.context.candidate)}
 var rate: float = maxf(0.0,_hero_lifesteal_rate(flags))
 var factor: float = maxf(0.0,_hero_lifesteal_factor(flags))
 var amount: float = float(data.amount)
 var receipt: Dictionary = {"cast_id":id,"candidate":state.context.candidate,"generation":state.context.generation,"room_id":state.context.room_id,"source_time":hero_time,"actual_supplement":amount,"lifesteal_rate":rate,"source_factor":factor,"requested_heal":amount*rate*factor,"actual_heal":0.0,"status":"committed_damage_callback_pending"}
 ink_p1_lifesteal_receipts.append(receipt)
 if ink_p1_lifesteal_receipts.size() > 32: ink_p1_lifesteal_receipts.pop_front()
 super.emit_event(kind,data)
 # Enemy death caused by this correction is legitimate. Hero death, another
 # room/owner/target instance, or an ended encounter cannot receive old healing.
 # A same-room cancellation AFTER commit does not undo real damage or reopen it.
 if not _p1_committed_scope_current(state,enemy) or hero.dead:
  receipt.status = "scope_or_hero_retired_after_damage"
  return
 receipt.status = "no_lifesteal" if float(receipt.requested_heal) <= 0.0 else "healed"
 if float(receipt.requested_heal) > 0.0:
  # Use the existing health authority: maxHP cap, actual-heal return, equipment
  # health dependency revision and legitimate healed observers remain intact.
  receipt.actual_heal = heal(float(receipt.requested_heal),true,{"source":"lifesteal","parent_skill":str(state.context.candidate),"cast_id":id,"p1_supplement":true,"final_damage_already_settled":true})
 # The parent's existing kill notifications follow this call and recheck scope.
 # Keep this diagnostic out of a new room if a healed callback changes scope.
 if _p1_committed_scope_current(state,enemy) and not hero.dead:
  emit_event("ink_p1_lifesteal_settled",receipt.duplicate(true))

func _p1_lifesteal_source(kind: String, data: Dictionary) -> Dictionary:
 if kind != "damage" or str(data.get("source","")) != "yanguizhou_p1" or not bool(data.get("p1_supplement",false)) or str(data.get("damage_type","")) != "final_supplement" or not bool(data.get("final_damage_already_settled",false)): return {}
 var id: int = int(data.get("cast_id",0))
 if not p1.roots.has(id): return {}
 var state: Dictionary = p1.roots[id]
 if not bool(state.settled) or state.targets.size() != 1 or str(state.context.candidate) not in ["q1","q2","q3","e1"]: return {}
 var key: String = "%d:%s:%d" % [int(state.context.generation),str(state.context.room_id),id]
 if _p1_lifesteal_claims.has(key): return {}
 var enemy: Dictionary = state.targets[0].enemy
 var amount: float = float(data.get("amount",0.0))
 if not is_finite(amount) or amount <= 0.0 or str(data.get("target","")) != str(enemy.actor_id) or str(data.get("parent_skill","")) != str(state.context.candidate): return {}
 if not _p1_committed_scope_current(state,enemy) or hero.dead: return {}
 # The parent appends its immutable committed damage receipt immediately before
 # emitting this event. A settled single-target root alone is not enough: an
 # already-dead target has actual_supplement0 and cannot authorize a fake event.
 var matching_commit: bool = false
 for committed: Dictionary in ink_p1_receipts:
  if int(committed.cast_id) == id and int(committed.generation) == int(state.context.generation) and str(committed.room_id) == str(state.context.room_id) and str(committed.candidate) == str(state.context.candidate) and str(committed.get("target_id","")) == str(enemy.actor_id) and bool(committed.qualified) and int(committed.distinct_targets) == 1 and float(committed.actual_supplement) == amount:
   matching_commit = true
   break
 if not matching_commit: return {}
 return state

func _hero_clear_transients() -> void:
 _p1_lifesteal_claims.clear(); ink_p1_lifesteal_receipts.clear()
 super._hero_clear_transients()
