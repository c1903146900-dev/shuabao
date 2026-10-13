extends "res://tests/ink_p2_ordinary_20261006/mechanism01/sim.gd"
## Local original-E1 remainder only. No ordinary selector/entry promotion.
var _e1_reform_pending: Array = []
var _e1_reform_draining: bool = false
var _e1_reform_epoch: int = 0

func _e1_reform(state: Dictionary, reason: String, at: float) -> void:
 if not _e1_current(state) or not is_same(ink_rain, state) or bool(state.retired): return
 # The original rain-layer snapshot and detachment are copied because its
 # synchronous two-batch method exposes no continuation hook. Damage is not
 # copied: each cursor delegates one target through the existing P2 wrapper.
 var origin: Vector3 = hero.position
 var targets: Array = circle_targets(origin, float(state.radius))
 var marked: Array = []
 var all_mark_ids: Array = state.marks.keys()
 for enemy in targets:
  var mark: Dictionary = state.marks.get(str(enemy.actor_id), {})
  if not mark.is_empty() and is_same(mark.enemy, enemy): marked.append(enemy)
 state.retired = true; ink_rain = {}
 _e1_set_speed_bonus(0.0)
 var receipt: Dictionary = _e1_public(state).merged({"position":origin, "reason":reason, "finished_at":at, "cleared_mark_target_ids":all_mark_ids, "radius_target_ids":targets.map(func(e): return e.actor_id), "bonus_target_ids":marked.map(func(e): return e.actor_id)}, true)
 common.refresh_stats()
 var impact: Dictionary = {"impact_penetration":float(hero.stats.penetration), "impact_lifesteal_rate":hero.lifesteal(), "ink_e1_impact_stats":common.context().hero.stats.duplicate(true)}
 _e1_reform_pending.append({"state":state,"scope":_ink_scope(),"epoch":_e1_reform_epoch,"targets":targets,"marked":marked,"origin":origin,"at":at,"impact":impact,"receipt":receipt,"stage":0,"cursor":0,"started":false,"cast_finished":false})
 _e1_drain_reform()

func _e1_reform_work_current(work: Dictionary) -> bool:
 return int(work.epoch) == _e1_reform_epoch and _ink_scope_current(work.scope) and _e1_current(work.state)

func _e1_drop_reform(work: Dictionary) -> void:
 work.state.marks.clear()
 _e1_reform_pending.erase(work)

func _e1_drain_reform() -> void:
 if _e1_reform_draining or _e1_reform_pending.is_empty(): return
 _e1_reform_draining = true
 while not _e1_reform_pending.is_empty():
  var work: Dictionary = _e1_reform_pending[0]
  if not _e1_reform_work_current(work): _e1_drop_reform(work); continue
  if paused: break
  var id: int = int(work.state.cast_id)
  # Reproduce BOTH ancestor reform wrappers. In particular the P2 batch wrapper
  # alone is too short: its splash must also wait past the original HP-delta
  # receipt and every remaining base/mark packet, across a pause if necessary.
  var frame: Dictionary = {"source":"e1","source_time":work.at,"contact_position":work.origin}
  p1.enter(id)
  _p2_source_frames.append(frame)
  _e1_drain_reform_work(work)
  if not _p2_source_frames.is_empty() and is_same(_p2_source_frames.back(),frame): _p2_source_frames.pop_back()
  p1.leave(id)
  _p1_flush(id)
  if not _e1_reform_work_current(work): _e1_drop_reform(work)
  if paused: break
 _e1_reform_draining = false
 _p2_drain_splashes()

func _e1_drain_reform_work(work: Dictionary) -> void:
 var state: Dictionary = work.state
 if not bool(work.started):
  work.started = true
  emit_event("ink_e1_reform_started",work.receipt)
 while _e1_reform_work_current(work) and not paused and int(work.stage) < 2:
  var targets: Array = work.targets if int(work.stage) == 0 else work.marked
  if int(work.cursor) >= targets.size():
   work.stage = int(work.stage)+1; work.cursor = 0
   continue
  var enemy: Dictionary = targets[int(work.cursor)]
  # Admission is immediately before the unchanged one-target batch. Advancing
  # first makes a committed packet immutable under its synchronous callbacks;
  # no paused or future target is pre-claimed by the underlying claim_hit.
  work.cursor = int(work.cursor)+1
  var segment: String = "reform_burst" if int(work.stage) == 0 else "rain_mark_bonus"
  var amount: float = float(state.base_damage) if int(work.stage) == 0 else float(state.bonus_damage)
  _e1_damage_batch(state,[enemy],segment,amount,work.origin,float(work.at),work.impact)
 # Even the LAST damage callback may pause. Both real terminal milestones
 # remain pending until resumed, without resubmitting that last packet.
 if not _e1_reform_work_current(work) or paused or int(work.stage) < 2: return
 state.marks.clear()
 if not bool(work.cast_finished):
  work.cast_finished = true
  finish_cast(int(state.cast_id))
 if not _e1_reform_work_current(work) or paused: return
 work.receipt["hit_target_ids"] = state.hit_targets.keys()
 work.receipt["damage_stages_complete"] = true
 ink_e1_finished.append(work.receipt)
 emit_event("ink_e1_finished",work.receipt)
 _e1_drop_reform(work)

func _p2_drain_splashes() -> void:
 # Parent _fixed_step drains P2 first. Preserve the entire reform barrier on
 # resume too; a source frame is held only while its actual stack is active.
 if not _e1_reform_pending.is_empty() or _e1_reform_draining: return
 super._p2_drain_splashes()

func _fixed_step(real_dt: float) -> void:
 if _e1_reform_draining: return
 var scope: Dictionary = _ink_scope()
 var epoch: int = _e1_reform_epoch
 if not _e1_reform_pending.is_empty(): _p2_sync()
 _e1_drain_reform()
 if not _ink_scope_current(scope) or epoch != _e1_reform_epoch or hero.dead: return
 if paused:
  real_accumulator += real_dt
  return
 super._fixed_step(real_dt) # Exactly one inherited clock/AI/common/RNG step.

func cancel_cast(id: int) -> void:
 for work: Dictionary in _e1_reform_pending.duplicate():
  if int(work.state.cast_id) == id: _e1_drop_reform(work)
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _e1_reform_epoch += 1
 for work: Dictionary in _e1_reform_pending: work.state.marks.clear()
 _e1_reform_pending.clear()
 super._hero_clear_transients()

func _hero_victory_pending() -> bool:
 return not _e1_reform_pending.is_empty() or _e1_reform_draining or super._hero_victory_pending()
