extends "res://tests/ink_e3_ordinary_20261006/ordinary01/sim.gd"
## Mechanism-only successor. No ordinary selection or production entry change.
const P2State = preload("res://tests/ink_p2_ordinary_20261006/mechanism01/p2_state.gd")
const P2Common = preload("res://tests/ink_p2_ordinary_20261006/mechanism01/p2_common_bridge.gd")
const P2_DECISION = "res://docs/source_decisions/20261006-p2-lifecycle-resolved.json"
const P2_DECISION_SHA = "6c7c5854948caba217258bd5e26e67f7fd0e2211d520a640c4ddd3a7fa0b6ea1"
var p2 = P2State.new()
var ink_p2_uses: Array = []
var ink_p2_claims: Array = []
var ink_p2_splashes: Array = []
var _p2_frames: Array = []
var _p2_source_frames: Array = []
var _p2_pending: Array = []
var _p2_packet_serial: int = 0
var _p2_scope_epoch: int = 0
var _p2_draining: bool = false
var _p2_installed: bool = false
var _p2_decision_hash: String = ""

func _init() -> void:
 super._init()
 _p2_decision_hash = FileAccess.get_sha256(P2_DECISION)
 var values: Dictionary = common.context_values.duplicate(true)
 common = P2Common.new(self)
 common.context_values = values
 _p2_installed = true

func _p2_selected() -> bool:
 return _p2_installed and _p2_decision_hash == P2_DECISION_SHA and hero.loadout.passive == "p2" and int(hero.ranks.passive) >= 1 and int(hero.ranks.passive) <= 4 and phase == "combat" and not hero.dead

func _p2_retire() -> void:
 _p2_scope_epoch += 1
 p2.retire_scope()
 _p2_pending.clear(); _p2_frames.clear(); _p2_source_frames.clear()

func _p2_sync() -> bool:
 if not _p2_installed: return false
 if not _p2_selected():
  if p2.owner != null or not _p2_pending.is_empty(): _p2_retire()
  return false
 if p2.owner != null and (not p2.current(hero,encounter_generation,room_id) or int(hero.ranks.passive) < p2.rank): _p2_retire()
 if p2.owner == null: p2.bind_empty(hero,encounter_generation,room_id,int(hero.ranks.passive))
 p2.check_rank(int(hero.ranks.passive))
 p2.observe_time(hero_time)
 return true

func _p2_projection() -> Dictionary:
 if not _p2_sync(): return {"ap_fraction":0.0,"speed_fraction":0.0}
 return p2.projection(int(hero.ranks.passive),hero_time)

func _sync_loadout_from_ledger() -> void:
 var previous: String = str(hero.loadout.passive)
 super._sync_loadout_from_ledger()
 if not _p2_installed: return
 if previous != str(hero.loadout.passive):
  _p2_retire()
  p1.clear()
 _p2_sync()
 common.refresh_stats()

func _p1_current(state: Dictionary) -> bool:
 return hero.loadout.passive == "p1" and super._p1_current(state)

func _p2_complete(context: Dictionary, family: String) -> void:
 if not _p2_sync(): return
 var result: Dictionary = p2.complete_use(context,hero,family,str(P2State.MILESTONES[family]),int(hero.ranks.passive),hero_time)
 if result.status != "OK": return
 ink_p2_uses.append(result.merged({"family":family,"cast_id":context.cast_id,"generation":encounter_generation,"room_id":room_id},true))
 common.refresh_stats()

func _p2_admitted_family(action: String, context: Dictionary) -> String:
 # Recheck exactly the frozen successful branch boundaries. No notifications,
 # policy calls, root allocation or damage occur between this and super.
 if not effect_is_current(context): return ""
 var family: String = str(context.get("candidate",""))
 if action == "q" and family == "q1" and hero.loadout.q == "q1":
  return "q1" if _committing_q1 and ink_input.phase in ["drawing","frozen"] else ""
 if action == "q" and family == "q2" and hero.loadout.q == "q2":
  if ink_q2_pending.is_empty() or int(context.cast_id) != int(ink_q2_pending.cast_id): return ""
  if ink_q2_pending.path.size() > 1 and not hx("yanguizhou_h03"): return ""
  return "q2" if bool(q2_preview(hero.aim_point).accepted) else ""
 if action == "q" and family == "q3" and hero.loadout.q == "q3":
  return "q3" if ink_mountain.is_empty() and bool(q3_preview(hero.aim_point).accepted) else ""
 if action == "e" and family == "e1" and hero.loadout.e == "e1": return "e1"
 if action == "e" and family == "e2" and hero.loadout.e == "e2" and ink_boat.is_empty(): return "e2"
 return ""

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 var family: String = _p2_admitted_family(action,context)
 if not family.is_empty(): _p2_complete(context,family)
 return super._hero_cast_skill(action,context)

func _e3_exchange(state: Dictionary, b: Vector3) -> Dictionary:
 # E3 A already owns the source near/far AP snapshot. Successful B is the use
 # milestone; it MUST NOT retroactively multiply/rebuild A's nominal damage.
 if _e3_live(state) and state.phase == "first" and hero_time < float(state.expires_at)-TIME_EPS and b.is_finite() and _e3_centers_in_range(b,state.a,float(state.max_distance)):
  if _e3_preflight(_e3_exchange_plan(state,b)).is_empty(): _p2_complete(state.context,"e3")
 return super._e3_exchange(state,b)

func _p2_packet_allowed(source: String, id: int, metadata: Dictionary) -> bool:
 if not _p2_sync() or source not in P2State.FAMILIES or not cast_is_current(id): return false
 if not bool(metadata.get("active_skill",false)) or bool(metadata.get("hex_generated",false)) or bool(metadata.get("replay",false)) or bool(metadata.get("p2_generated",false)) or bool(metadata.get("p1_supplement",false)) or bool(metadata.get("basic_attack",false)): return false
 return p2.packet_entitled(id,source)

func _p2_packet_source(source: String, metadata: Dictionary) -> Dictionary:
 var out: Dictionary = {"source_time":hero_time,"contact_position":metadata.get("position",hero.position)}
 if metadata.has("ink_receipt"):
  out.source_time = metadata.ink_receipt.contact_time
  out.contact_position = metadata.ink_receipt.contact_position
 elif metadata.has("q2_receipt"): out.source_time = metadata.q2_receipt.source_time
 elif not _p2_source_frames.is_empty() and _p2_source_frames.back().source == source:
  out = _p2_source_frames.back().duplicate(true)
 elif source == "e3" and not ink_frames.is_empty(): out.source_time = ink_frames.get("exchange_at",hero_time)
 return out

func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int = 0, is_true: bool = false, critical: bool = false, metadata: Dictionary = {}) -> bool:
 _p2_packet_serial += 1
 var eligible: bool = _p2_packet_allowed(source,cast_id,metadata)
 var frame: Dictionary = {"packet_serial":_p2_packet_serial,"enemy":enemy,"source":source,"cast_id":cast_id,"scope":_ink_scope(),"scope_epoch":_p2_scope_epoch,"seen":false,"eligible":eligible,"source_info":_p2_packet_source(source,metadata),"p2_generated":bool(metadata.get("p2_generated",false)),"effect_id":str(metadata.get("effect_id",""))}
 _p2_frames.append(frame)
 var result: bool = super.damage_enemy(enemy,amount,source,cast_id,is_true,critical,metadata)
 if not _p2_frames.is_empty() and is_same(_p2_frames.back(),frame): _p2_frames.pop_back()
 # All original HP/lifesteal/kill/after-hit work (including nested originals)
 # must unwind before splash. A lethal original therefore cannot die twice.
 if _p2_frames.is_empty(): _p2_drain_splashes()
 return result

func emit_event(kind: String, data: Dictionary = {}) -> void:
 if kind == "damage" and not _p2_frames.is_empty():
  var frame: Dictionary = _p2_frames.back()
  var match_packet: bool = not bool(frame.seen) and str(data.get("target","")) == str(frame.enemy.get("actor_id","")) and str(data.get("source","")) == str(frame.source) and int(data.get("cast_id",0)) == int(frame.cast_id)
  if match_packet:
   frame.seen = true
   if bool(frame.p2_generated):
    data = data.merged({"p2_generated":true,"effect_id":frame.effect_id},true)
   if bool(frame.eligible) and int(frame.scope_epoch) == _p2_scope_epoch and _ink_scope_current(frame.scope) and _p2_selected() and float(data.get("amount",0.0)) > 0.0:
    # Only the real innermost damage call reaches this before outward signals.
    # Re-project at CURRENT submission hero_time, never rewind to source_time.
    common.refresh_stats()
    var receipt: Dictionary = p2.claim_positive(int(frame.cast_id),str(frame.source),int(frame.packet_serial),float(data.amount),data.position,float(hero.stats.ap),hero_time)
    if receipt.status == "CLAIMED":
     receipt.merge(frame.source_info,true)
     receipt.target_id = str(data.target)
     _p2_queue_splash(receipt)
     common.refresh_stats()
 super.emit_event(kind,data)

func _p2_queue_splash(receipt: Dictionary) -> void:
 # Numerical data, center and target membership snapshot at original HP commit,
 # before callbacks and before removing P2's derived stats. A lethal target is
 # absent (HP zero) even though its original kill callback has not yet run.
 var radius: float = T.parameter("P2-6",int(receipt.passive_rank))
 var targets: Array = []
 for enemy in enemies:
  if enemy.dead or enemy.state == "spawn" or float(enemy.hp) <= 0.0: continue
  if int(enemy.generation) != encounter_generation or str(enemy.room_id) != room_id: continue
  if Geometry.ground(Vector3(enemy.position)-Vector3(receipt.position)).length() <= radius+float(enemy.radius)+Geometry.EPS: targets.append(enemy)
 targets.sort_custom(func(a,b): return str(a.actor_id) < str(b.actor_id))
 receipt["splash_id"] = "%d:%s:p2:%d:%d" % [encounter_generation,room_id,_p2_scope_epoch,int(receipt.packet_serial)]
 receipt["radius"] = radius
 receipt["nominal_damage"] = T.parameter("P2-7",int(receipt.passive_rank))+float(receipt.ap_before_clear)*T.fraction("P2-8",int(receipt.passive_rank))
 receipt["target_ids"] = targets.map(func(enemy): return str(enemy.actor_id))
 receipt["snapshot_at"] = hero_time
 ink_p2_claims.append(receipt.duplicate(true))
 _p2_pending.append({"scope":_ink_scope(),"scope_epoch":_p2_scope_epoch,"receipt":receipt,"targets":targets,"cursor":0,"started":false,"actual":[]})

func _p2_work_current(work: Dictionary) -> bool:
 return int(work.scope_epoch) == _p2_scope_epoch and _ink_scope_current(work.scope) and _p2_selected()

func _p2_drain_splashes() -> void:
 if _p2_draining or not _p2_frames.is_empty() or not _p2_source_frames.is_empty(): return
 _p2_draining = true
 while not _p2_pending.is_empty():
  var work: Dictionary = _p2_pending[0]
  if not _p2_work_current(work): _p2_pending.pop_front(); continue
  if paused: break
  var receipt: Dictionary = work.receipt
  if not bool(work.started):
   work.started = true
   emit_event("ink_p2_splash_started",receipt.duplicate(true))
   if not _p2_work_current(work): continue
   if paused: break
  while _p2_work_current(work) and not paused and int(work.cursor) < work.targets.size():
   var enemy: Dictionary = work.targets[int(work.cursor)]
   work.cursor = int(work.cursor)+1
   if not is_same(enemy,enemy_by_id(str(enemy.actor_id))) or enemy.dead or enemy.state == "spawn" or float(enemy.hp) <= 0.0: continue
   # Normal ordinary/common/equipment pipeline at dispatch. The new source is
   # neither Q/E use nor a P1 packet; do not suppress all ordinary reactions.
   var metadata: Dictionary = {"generation":receipt.generation,"room_id":receipt.room_id,"effect_id":str(receipt.splash_id)+":"+str(enemy.actor_id),"position":receipt.position,"p2_generated":true,"active_skill":false,"basic_attack":false,"area":true,"direct":true,"hex_generated":false,"parent_skill":receipt.family}
   damage_enemy(enemy,float(receipt.nominal_damage),"yanguizhou_p2",0,false,false,metadata)
  if not _p2_work_current(work): continue
  if paused: break
  if int(work.cursor) == work.targets.size():
   _p2_pending.pop_front()
   var finished: Dictionary = receipt.merged({"finished_at":hero_time,"dispatched_targets":int(work.cursor)},true)
   ink_p2_splashes.append(finished)
   emit_event("ink_p2_splash_finished",finished.duplicate(true))
 _p2_draining = false

func _e1_damage_batch(state: Dictionary, targets: Array, segment: String, amount: float, origin: Vector3, at: float, impact: Dictionary) -> void:
 var frame: Dictionary = {"source":"e1","source_time":at,"contact_position":origin}
 _p2_source_frames.append(frame)
 super._e1_damage_batch(state,targets,segment,amount,origin,at,impact)
 if not _p2_source_frames.is_empty() and is_same(_p2_source_frames.back(),frame): _p2_source_frames.pop_back()
 _p2_drain_splashes()

func _e1_reform(state: Dictionary, reason: String, at: float) -> void:
 # Keep E1's original two-channel settlement and legacy HP-delta receipts ahead
 # of our added splash; its entire reform is already one synchronous batch.
 var frame: Dictionary = {"source":"e1","source_time":at,"contact_position":hero.position}
 _p2_source_frames.append(frame)
 super._e1_reform(state,reason,at)
 if not _p2_source_frames.is_empty() and is_same(_p2_source_frames.back(),frame): _p2_source_frames.pop_back()
 _p2_drain_splashes()

func _e2_contact(state: Dictionary, enemy: Dictionary, segment: String, at_position: Vector3, at: float, impact: Dictionary, explicit_amount: float = -1.0) -> void:
 var frame: Dictionary = {"source":"e2","source_time":at,"contact_position":at_position}
 _p2_source_frames.append(frame)
 super._e2_contact(state,enemy,segment,at_position,at,impact,explicit_amount)
 if not _p2_source_frames.is_empty() and is_same(_p2_source_frames.back(),frame): _p2_source_frames.pop_back()
 _p2_drain_splashes()

func _settle_motion_interval(before: Dictionary, tick_start: float, tick_end: float) -> void:
 # The legacy Q1 fallback does not retain a paused multi-contact tail. Select
 # the already inherited ordered remainder solver for P2-owned real Q1 waves,
 # as the existing P1 adapter does for its own waves; add no world/AI step.
 if _p2_selected() and _q2_resume_from < 0.0 and ink_rivers.is_empty() and _q2_enemy_hits.is_empty():
  for wave in ink_waves:
   if not bool(wave.get("retired",false)) and effect_is_current(wave) and p2.uses.has(int(wave.cast_id)):
    _q2_resume_from = tick_start
    break
 super._settle_motion_interval(before,tick_start,tick_end)

func _fixed_step(real_dt: float) -> void:
 var scope: Dictionary = _ink_scope()
 var epoch: int = _p2_scope_epoch
 _p2_sync()
 _p2_drain_splashes()
 if not _ink_scope_current(scope) or epoch != _p2_scope_epoch or paused or hero.dead: return
 super._fixed_step(real_dt)
 if _ink_scope_current(scope) and epoch == _p2_scope_epoch:
  common.refresh_stats()
  _p2_drain_splashes()

func cancel_cast(id: int) -> void:
 if p2 != null: p2.cancel_root(id)
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 if p2 != null: _p2_retire()
 ink_p2_uses.clear(); ink_p2_claims.clear(); ink_p2_splashes.clear()
 super._hero_clear_transients()
 if _p2_installed: common.refresh_stats(false)

func _hero_victory_pending() -> bool:
 return not _p2_pending.is_empty() or super._hero_victory_pending()

func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 var selected: bool = _p2_sync()
 out.p2 = {"selected":selected,"rank":p2.rank,"stacks":p2.stacks,"expires_at":p2.expires_at,"remaining":maxf(0.0,p2.expires_at-hero_time),"ready":p2.ready_epoch > 0,"ready_epoch":p2.ready_epoch,"last_family":p2.last_family,"use_serial":p2.use_serial,"pending_splashes":_p2_pending.size()}
 return out
