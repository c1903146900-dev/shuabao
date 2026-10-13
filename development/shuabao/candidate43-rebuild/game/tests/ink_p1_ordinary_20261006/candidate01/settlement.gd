extends "res://tests/ink_r1_ordinary_20261005/candidate01/sim.gd"
## P1 settlement above the frozen CURRENT R1/E1/Q2/Q3/navigation chain.
## Mechanism-only candidate. Production host, selectors and growth stay frozen.
const P1Collector = preload("res://tests/ink_p1_settlement_20261005/candidate03/p1_collector.gd")
const P1_FAMILIES: Array = ["q1", "q2", "q3", "e1"]
var p1 = P1Collector.new()
var ink_p1_receipts: Array = []
var _p1_packet_stack: Array = []
var _p1_packet_serial: int = 0

func new_cast(slot: String, stage: String = "", extra: Dictionary = {}) -> Dictionary:
 var owner = hero
 var candidate: String = str(hero.loadout.get(slot, slot))
 var rank: int = int(hero.ranks.passive)
 var eligible: bool = hero.loadout.passive == "p1" and rank >= 1 and rank <= 4 and slot in ["q", "e"] and candidate in P1_FAMILIES
 var bonus: float = T.fraction("P1-1", rank) if eligible else 0.0
 var refund: float = T.fraction("P1-2", rank) if eligible else 0.0
 var context: Dictionary = super.new_cast(slot, stage, extra)
 if eligible and effect_is_current(context) and is_same(hero, owner) and not hero.dead:
  p1.begin(context, owner, rank, bonus, refund)
 return context

func _p1_current(state: Dictionary) -> bool:
 return not state.is_empty() and effect_is_current(state.context) and is_same(hero, state.owner) and not hero.dead

func _p1_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if not p1.roots.has(id) or not _p1_current(p1.roots[id]) or bool(p1.roots[id].settled): return false
 if bool(metadata.get("replay", false)) or bool(metadata.get("p1_supplement", false)) or bool(metadata.get("basic_attack", false)): return false
 var family: String = str(p1.roots[id].context.candidate)
 # Only the four admitted base families. No generated Hex/replay entitlement.
 return source == family

func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int = 0, is_true: bool = false, critical: bool = false, metadata: Dictionary = {}) -> bool:
 _p1_packet_serial += 1
 var frame: Dictionary = {"id":_p1_packet_serial, "enemy":enemy, "cast_id":cast_id, "source":source, "seen":false, "eligible":_p1_packet_allowed(source, cast_id, metadata)}
 _p1_packet_stack.append(frame)
 p1.enter(cast_id)
 var result: bool = super.damage_enemy(enemy, amount, source, cast_id, is_true, critical, metadata)
 # A room reset can clear the stack while the original call is unwinding.
 if not _p1_packet_stack.is_empty() and is_same(_p1_packet_stack.back(), frame): _p1_packet_stack.pop_back()
 p1.leave(cast_id)
 _p1_flush(cast_id)
 return result

func emit_event(kind: String, data: Dictionary = {}) -> void:
 if kind == "damage" and not _p1_packet_stack.is_empty():
  var frame: Dictionary = _p1_packet_stack.back()
  if bool(frame.eligible) and not bool(frame.seen) and int(data.get("cast_id", 0)) == int(frame.cast_id) and str(data.get("target", "")) == str(frame.enemy.get("actor_id", "")) and str(data.get("source", "")) == str(frame.source):
   frame.seen = true
   # This amount was computed AFTER final multipliers, guard, defence and HP
   # capping, and BEFORE external callbacks. Never infer it from later HP delta.
   p1.capture(int(frame.cast_id), int(frame.id), frame.enemy, float(data.amount))
 var milestone: int = 0
 if kind in ["ink_q3_finished", "ink_e1_finished"]:
  var id: int = int(data.get("cast_id", 0))
  if p1.roots.has(id) and _p1_current(p1.roots[id]):
   var family: String = str(p1.roots[id].context.candidate)
   var valid: bool = (family == "q3" and kind == "ink_q3_finished" and str(data.get("reason", "")) in ["collapsed", "expired"]) or (family == "e1" and kind == "ink_e1_finished" and bool(data.get("damage_stages_complete", false)))
   if valid:
    milestone = id
    # Terminal observers may finish/cancel/step reentrantly. Keep the entire
    # notification behind the same finite barrier before any P1 payment.
    p1.enter(id)
    p1.complete(id)
 super.emit_event(kind, data)
 if milestone != 0:
  p1.leave(milestone)
  _p1_flush(milestone)

func finish_cast(id: int, cancelled: bool = false, wait_for_motion: bool = false) -> void:
 if cancelled:
  super.finish_cast(id, true, wait_for_motion)
  return
 if not cast_is_current(id) or id == 0: return
 # Generic core completion is not proof that this family has ended all future
 # damage. Only the real terminal receipt above releases the P1 milestone.
 p1.enter(id)
 super.finish_cast(id, false, wait_for_motion)
 p1.leave(id)
 _p1_flush(id)

func _p1_flush(id: int) -> void:
 if not p1.roots.has(id): return
 var state: Dictionary = p1.roots[id]
 if not _p1_current(state):
  p1.cancel(id)
  return
 if paused or not p1.ready(id): return
 state = p1.take(id)
 var count: int = state.targets.size()
 var receipt: Dictionary = {"cast_id":id, "candidate":state.context.candidate, "slot":state.context.slot, "generation":state.context.generation, "room_id":state.context.room_id, "passive_rank":state.rank, "distinct_targets":count, "ordinary_packet_count":state.packets.size(), "qualified":count == 1, "settled_at":hero_time, "final_basis":0.0, "requested_supplement":0.0, "actual_supplement":0.0, "cooldown_before":0.0, "cooldown_refund":0.0, "cooldown_after":0.0, "target_status":"not_single", "supplement_killed":false}
 if count == 1:
  var target: Dictionary = state.targets[0]
  var enemy: Dictionary = target.enemy
  var slot: String = str(state.context.slot)
  receipt.target_id = target.actor_id
  receipt.final_basis = float(target.actual)
  receipt.requested_supplement = float(target.actual) * float(state.bonus)
  receipt.cooldown_before = maxf(0.0, float(hero.cooldowns.get(slot, 0.0)))
  receipt.cooldown_refund = float(receipt.cooldown_before) * float(state.refund)
  receipt.cooldown_after = float(receipt.cooldown_before) - float(receipt.cooldown_refund)
  # Current remaining CD is paid exactly now. Zero stays zero; no future credit
  # or cooldown restart. Both numerical commits precede outward notification.
  hero.cooldowns[slot] = receipt.cooldown_after
  var live_original: bool = is_same(enemy, enemy_by_id(str(target.actor_id))) and int(enemy.get("generation", -1)) == encounter_generation and str(enemy.get("room_id", "")) == room_id
  receipt.target_status = "original_missing_or_replaced" if not live_original else "already_dead" if bool(enemy.dead) or float(enemy.hp) <= 0.0 else "live_original"
  if live_original and not bool(enemy.dead) and float(enemy.hp) > 0.0:
   receipt.actual_supplement = minf(float(enemy.hp), float(receipt.requested_supplement))
   enemy.hp = maxf(0.0, float(enemy.hp) - float(receipt.requested_supplement))
   # Death is committed atomically with HP, before callbacks can cancel/replace
   # the encounter. Death notifications below remain scoped to this instance.
   if float(enemy.hp) <= 0.0:
    receipt.supplement_killed = true
    enemy.dead = true; enemy.state = "dead"; enemy.push = {}; enemy.pull_state = {}; enemy.carried = false
 ink_p1_receipts.append(receipt.duplicate(true))
 if count == 1 and float(receipt.actual_supplement) > 0.0:
  var enemy: Dictionary = state.targets[0].enemy
  emit_event("damage", {"target":enemy.actor_id, "position":enemy.position, "amount":receipt.actual_supplement, "source":"yanguizhou_p1", "parent_skill":state.context.candidate, "cast_id":id, "critical":false, "damage_type":"final_supplement", "p1_supplement":true, "hex_generated":false, "replay":false, "basic_attack":false, "final_damage_already_settled":true, "enemy_kind":enemy.kind})
  if bool(receipt.supplement_killed) and _p1_committed_scope_current(state, enemy):
   common.killed(enemy, "yanguizhou_p1", id)
   if _p1_committed_scope_current(state, enemy): _hero_killed(enemy, "yanguizhou_p1", id)
   if _p1_committed_scope_current(state, enemy): emit_event("kill", {"target":enemy.actor_id, "position":enemy.position, "source":"yanguizhou_p1", "cast_id":id, "credit":"solo_lethal", "enemy_kind":enemy.kind, "p1_supplement":true})
 if _p1_current(state): emit_event("ink_p1_settled", receipt)

func _p1_committed_scope_current(state: Dictionary, enemy: Dictionary) -> bool:
 # A same-room cancellation AFTER atomic lethal commit cannot resurrect it or
 # duplicate its death. A new room/hero/actor cannot inherit old notifications.
 return phase == "combat" and room_id == str(state.context.room_id) and encounter_generation == int(state.context.generation) and is_same(hero, state.owner) and is_same(enemy, enemy_by_id(str(enemy.actor_id)))

func _q3_damage_segment(state: Dictionary, segment: String, origin: Vector3, direction: Vector3, length: float, width: float, amount: float, collapse: bool) -> void:
 var id: int = int(state.cast_id)
 p1.enter(id)
 super._q3_damage_segment(state, segment, origin, direction, length, width, amount, collapse)
 p1.leave(id); _p1_flush(id)

func _e1_reform(state: Dictionary, reason: String, at: float) -> void:
 var id: int = int(state.cast_id)
 p1.enter(id)
 super._e1_reform(state, reason, at)
 p1.leave(id); _p1_flush(id)

func _fixed_step(real_dt: float) -> void:
 super._fixed_step(real_dt)
 for id in p1.roots.keys(): _p1_flush(int(id))

func cancel_cast(id: int) -> void:
 p1.cancel(id)
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 p1.clear(); _p1_packet_stack.clear(); ink_p1_receipts.clear()
 super._hero_clear_transients()
