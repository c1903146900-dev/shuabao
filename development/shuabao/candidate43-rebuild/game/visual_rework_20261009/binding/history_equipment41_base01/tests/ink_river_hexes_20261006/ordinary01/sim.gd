extends "res://tests/ink_river_hexes_20261006/ownership01/sim.gd"

# Reviewed Boss composition: install only in construction, before Session admission.
const OrdinaryFirstFloorBossDirector = preload("res://tests/ink_first_floor_boss_20261008/source01/enemy_director.gd")
const OrdinaryPursuitCommon = preload("res://equipment_pursuit_20261009/common_bridge.gd")
func _init() -> void:
 super._init()
 enemy_director = OrdinaryFirstFloorBossDirector.new()
 # Fresh construction only: retain the original runtime/clock and all bridge
 # state. The new leaf inherits the exact existing P2 -> E3 -> Boat -> Rain chain.
 var original_common = common
 common = OrdinaryPursuitCommon.new(self)
 common.runtime = original_common.runtime
 common.model = original_common.model
 common.settings = original_common.settings
 common.context_values = original_common.context_values
 common._last_stats = original_common._last_stats
 common._draining = original_common._draining
 common._inside_hit = original_common._inside_hit
 common._shift_cast = original_common._shift_cast
 common._pending_finishes = original_common._pending_finishes
 common._spatial_recorded = original_common._spatial_recorded
 common._action_origins = original_common._action_origins
func _kill_enemy(enemy: Dictionary, source: String, cast_id: int) -> void:
 var g02_frame: Dictionary = _g02_begin_core_death(enemy,source,cast_id)
 _g02_core_frames.append(g02_frame)
 if not enemy.dead and enemy.kind == "boss" and enemy_director.has_method("cancel_boss_casts"):
  enemy_director.boss_controller.cancel(self,enemy,"owner_died")
 super._kill_enemy(enemy,source,cast_id)
 if not _g02_core_frames.is_empty() and is_same(_g02_core_frames.back(),g02_frame): _g02_core_frames.pop_back()

## Ownership Sim plus ordinary presentation and composed equipment consumers.
## The inherited world clock remains authoritative for all source effects.
const OrdinaryBossAudioSnapshot = preload("res://tests/ink_first_floor_boss_20261008/audio01/snapshot_adapter.gd")
func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary=super.ink_presenter_snapshot()
 var sunsets: Array=[]
 for state: Dictionary in ink_rivers:
  if not _q2_valid(state) or not bool(state.h04_at_completion) or hero_time<float(state.born_at) or hero_time>=float(state.sunset_expires_at): continue
  var elapsed: float=maxf(0.0,hero_time-float(state.born_at))
  var duration: float=T.hex_parameter("H04-1")
  var interval: float=T.hex_parameter("H04-4")
  var sampled_tick: int=0
  for receipt: Dictionary in h04_sample_receipts:
   if receipt.river_id==state.river_id: sampled_tick=maxi(sampled_tick,int(receipt.tick))
  sunsets.append({"river_id":state.river_id,"cast_id":state.cast_id,"generation":state.generation,"room_id":state.room_id,"center":state.path.back(),"radius":lerpf(T.hex_parameter("H04-2"),T.hex_parameter("H04-3"),clampf(elapsed/duration,0.0,1.0)),"born_at":state.born_at,"expires_at":state.sunset_expires_at,"remaining":maxf(0.0,float(state.sunset_expires_at)-hero_time),"interval":interval,"scheduled_ticks":int(state.next_sunset_tick)-1,"sampled_tick":sampled_tick,"next_tick_at":float(state.born_at)+float(state.next_sunset_tick)*interval if int(state.next_sunset_tick)<=8 else -1.0,"tick_progress":fmod(elapsed,interval)/interval,"source_time":hero_time,"paused":paused})
 out["h04_sunsets"]=sunsets
 return OrdinaryBossAudioSnapshot.capture(self,out)

# Integrated content consumers: one inherited clock and health observer.
const OrdinaryPassive23StatConsumer = preload("res://tests/ink_initial_hex_runtime_20261004/ink_initial_stat_consumer.gd")
var _ordinary_passive23_owner: WeakRef
var _ordinary_passive23_syncing: bool = false
var _ordinary_passive23_stats = OrdinaryPassive23StatConsumer.new()
func bind_passive23_model(owner: RefCounted) -> void:
 assert(_ordinary_passive23_owner == null and _equipment_health_owner != null and is_same(_equipment_health_owner.get_ref(), owner))
 _ordinary_passive23_owner = weakref(owner)
func refresh_passive23() -> void:
 if _ordinary_passive23_syncing or transaction_active or _ordinary_passive23_owner == null: return
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if owner == null: return
 _ordinary_passive23_syncing = true
 _ordinary_passive23_stats.sync_stats(self, owner)
 _ordinary_passive23_syncing = false
func _fixed_step(real_dt: float) -> void:
 refresh_passive23()
 super._fixed_step(real_dt)
 refresh_passive23()
func damage_hero(amount: float, direction: Vector3 = Vector3.ZERO, control: float = 0.0, is_true: bool = false, mandatory: bool = false, metadata: Dictionary = {}) -> void:
 # Sampling immediately before mitigation sees movements and deaths in this tick.
 refresh_passive23()
 super.damage_hero(amount, direction, control, is_true, mandatory, metadata)
func begin_encounter(next_id: String, roster: Array) -> Dictionary:
 var result: Dictionary = super.begin_encounter(next_id, roster)
 refresh_passive23()
 return result
func end_encounter(result: String) -> void:
 super.end_encounter(result)
 refresh_passive23()
 if hero.dead and _ordinary_potion_model!=null and _ordinary_potion_model.get_ref()!=null:
  _ordinary_potion_model.get_ref().potion_consumer.retire()
func _clear_wave_transients() -> void:
 if enemy_director != null and enemy_director.has_method("cancel_boss_casts"):
  enemy_director.cancel_boss_casts(self,"room_or_terminal")
 super._clear_wave_transients()
 # end_encounter sets phase before clearing and before taking frozen_snapshot.
 refresh_passive23()

var _ordinary_potion_model: WeakRef
func bind_potion_model(model: RefCounted) -> Dictionary:
 if _ordinary_potion_model!=null: return {"accepted":false,"reason":"potion_sim_already_bound"}
 var result: Dictionary=model.bind_potion_sim(self)
 if result.accepted: _ordinary_potion_model=weakref(model)
 return result
func _hero_pre_step(actor_dt: float, real_dt: float) -> void:
 super._hero_pre_step(actor_dt,real_dt)
 if _ordinary_potion_model!=null and _ordinary_potion_model.get_ref()!=null:
  _ordinary_potion_model.get_ref().potion_consumer.advance(actor_dt)

# Explicit 2026-10-08 baseline free-curve override, one production Sim.
const Q1FreeCurve=preload("res://visual_rework_20261009/input/q1_free_curve_sampler.gd")
func _update_preview(point:Vector3)->void:
 # User override 2026-10-08: free curves are baseline, not H01-gated.
 # Existing input handler freezes time BEFORE this call and commits on release.
 var sampled:Dictionary=Q1FreeCurve.sample(ink_input.path,point,float(ink_input.length_cap))
 if bool(sampled.changed):
  ink_input.path=sampled.path;revision+=1
 if bool(sampled.at_limit):_freeze_preview("length_limit",hero_time)

# Final multiplier after common bonuses, before mitigation. The inherited source
# pipeline already skips this hook for replay and snapshot_final packets.
func _hero_final_outgoing_multiplier(enemy: Dictionary, event: Dictionary) -> float:
 var result: float = super._hero_final_outgoing_multiplier(enemy, event)
 if _ordinary_passive23_owner == null: return result
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if owner == null or not owner.has_method("passive18_multiplier"): return result
 result *= float(owner.passive18_multiplier(enemy, event))
 if owner.has_method("distance_equipment_multiplier"):
  result *= float(owner.distance_equipment_multiplier(hero.position, enemy))
 return result

# Source-live packet witnesses for equipment Q/E kill attribution. No extra hit,
# clock, actor or cast is created; original damage/kill processing stays inherited.
var _b01_damage_frames: Array = []
func damage_enemy(enemy: Dictionary, amount: float, source: String, cast_id: int = 0, is_true: bool = false, critical: bool = false, metadata: Dictionary = {}) -> bool:
 var frame: Dictionary = {"enemy":enemy,"source":source,"cast_id":cast_id,"metadata":metadata.duplicate(true),"original_h04":_river_hex_original_packet(source,cast_id,metadata),"pre_hp":float(enemy.get("hp",0.0)),"generation":encounter_generation,"room_id":room_id,"g06_expected_hp":float(enemy.get("hp",0.0)),"g06_seen":false}
 frame.g02_owner = hero
 frame.g02_pre_dead = bool(enemy.get("dead",true))
 frame.g02_damage_seen = false
 frame.g02_damage = {}
 _b01_damage_frames.append(frame)
 var result: bool = super.damage_enemy(enemy,amount,source,cast_id,is_true,critical,metadata)
 if not _b01_damage_frames.is_empty() and is_same(_b01_damage_frames.back(),frame):
  _b01_damage_frames.pop_back()
  var nested_loss: float = float(frame.pre_hp)-float(enemy.get("hp",0.0))
  # Propagate one child subtree exactly once. Updating every ancestor here
  # would count a grandchild again when its immediate parent later unwinds.
  for parent_index: int in range(_b01_damage_frames.size()-1,-1,-1):
   var parent: Dictionary = _b01_damage_frames[parent_index]
   if is_same(parent.enemy,enemy) and int(parent.generation)==int(frame.generation) and str(parent.room_id)==str(frame.room_id):
    if not bool(parent.g06_seen): parent.g06_expected_hp=float(parent.g06_expected_hp)-nested_loss
    # A seen parent still owns its subtree's eventual handoff. Do not jump
    # through it and then subtract the same grandchild again at its return.
    break
 return result

func verify_b01_kill_attribution(event: Dictionary) -> Dictionary:
 if phase != "combat" or paused or hero.dead or str(event.get("kind","")) != "kill" or str(event.get("credit","")) != "solo_lethal": return {}
 var id: int = int(event.get("cast_id",0))
 if id <= 0 or not cast_is_current(id) or not _casts.has(id): return {}
 var slot: String = str(_casts[id].slot)
 if slot not in ["q","e"]: return {}
 var enemy: Dictionary = enemy_by_id(str(event.get("target","")))
 if enemy.is_empty() or not enemy.dead or int(enemy.generation) != encounter_generation or str(enemy.room_id) != room_id: return {}
 if int(event.get("generation",-1)) != encounter_generation or str(event.get("room_id","")) != room_id: return {}
 var observed: bool = false
 for recorded: Dictionary in event_log:
  if int(recorded.get("sequence",-1)) == int(event.get("sequence",-2)) and recorded == event: observed=true;break
 if not observed: return {}
 var source: String = str(event.get("source",""))
 var parent_skill: String = ""
 var h04: bool = false
 if source == "yanguizhou_p1":
  if not bool(event.get("p1_supplement",false)): return {}
  for receipt: Dictionary in ink_p1_receipts:
   if int(receipt.cast_id)==id and str(receipt.get("target_id",""))==str(enemy.actor_id) and bool(receipt.get("supplement_killed",false)) and int(receipt.generation)==encounter_generation and str(receipt.room_id)==room_id:
    parent_skill=str(receipt.candidate);break
  if parent_skill not in ["q1","q2","q3","e1","e2","e3"] or not parent_skill.begins_with(slot): return {}
 else:
  if _b01_damage_frames.is_empty(): return {}
  var frame: Dictionary = _b01_damage_frames.back()
  if not is_same(frame.enemy,enemy) or int(frame.cast_id)!=id or str(frame.source)!=source: return {}
  var meta: Dictionary = frame.metadata
  if bool(meta.get("replay",false)) or bool(meta.get("basic_attack",false)) or bool(meta.get("p1_supplement",false)) or bool(meta.get("p2_generated",false)) or not bool(meta.get("active_skill",false)): return {}
  if source == "hex_yanguizhou_h04":
   if slot!="q" or not bool(frame.original_h04): return {}
   parent_skill="q2";h04=true
  elif source in ["q1","q2","q3","e1","e2","e3"] and source.begins_with(slot) and not bool(meta.get("hex_generated",false)):
   parent_skill=source
  else: return {}
 return {"source_bridge_connected":true,"attribution_verified":true,"kind":"kill","source":source,"parent_skill":parent_skill,"original_q2_hex_receipt_verified":h04,"cast_id":id,"target":str(enemy.actor_id),"generation":encounter_generation,"room_id":room_id,"sequence":int(event.sequence)}

var _g06_emissions: Array = []
var _g06_p1_emitted: Dictionary = {}
var _g06_p1_scope: String = ""
func emit_event(kind: String, data: Dictionary = {}) -> void:
 # G02 observes the committed original packet before any damage callbacks.
 if kind == "damage": _g02_note_original_damage(data)
 if kind == "kill":
  # Invalid nested public emissions shadow, rather than borrow, an outer kill.
  var g02_emission: Dictionary = _g02_capture_original_kill(data)
  _g02_emissions.append(g02_emission)
  super.emit_event(kind,data)
  if not _g02_emissions.is_empty() and is_same(_g02_emissions.back(),g02_emission): _g02_emissions.pop_back()
  return
 # Insert before the existing G06 kind!="damage" branch. Source commit occurs
 # before normal observers; the diagnostic follows normal observers.
 if kind == "ink_basic_finished":
  var b04_result: Dictionary = _b04_consume_original_completion(data)
  super.emit_event(kind,data)
  _b04_emit_completion_receipt(b04_result)
  return
 if kind!="damage":
  super.emit_event(kind,data)
  return
 # Every nested emission gets its own slot, including invalid ones. An observer
 # cannot borrow the still-active parent receipt by emitting a lookalike event.
 var witness: Dictionary = _g06_capture_original_damage(data)
 _g06_emissions.append(witness)
 super.emit_event(kind,data)
 if not _g06_emissions.is_empty() and is_same(_g06_emissions.back(),witness): _g06_emissions.pop_back()

func _g06_capture_original_damage(data: Dictionary) -> Dictionary:
 if phase!="combat" or paused or hero.dead: return {}
 var value: Variant = data.get("amount")
 if not (value is int or value is float) or not is_finite(float(value)) or float(value)<=0.0: return {}
 var amount: float = float(value)
 var enemy: Dictionary = enemy_by_id(str(data.get("target","")))
 if enemy.is_empty() or str(enemy.get("rank_category","")) not in ["elite","boss"]: return {}
 if int(enemy.get("generation",-1))!=encounter_generation or str(enemy.get("room_id",""))!=room_id: return {}
 var id: int = int(data.get("cast_id",0))
 if not cast_is_current(id): return {}
 var source: String = str(data.get("source",""))
 var proof: String = ""
 var p1_key: String = ""
 if source=="yanguizhou_p1":
  if not bool(data.get("p1_supplement",false)) or not bool(data.get("final_damage_already_settled",false)): return {}
  var scope: String = "%d:%s" % [encounter_generation,room_id]
  if _g06_p1_scope!=scope: _g06_p1_scope=scope;_g06_p1_emitted.clear()
  p1_key="%d:%s" % [id,str(enemy.actor_id)]
  if _g06_p1_emitted.has(p1_key): return {}
  for receipt: Dictionary in ink_p1_receipts:
   if int(receipt.cast_id)==id and str(receipt.get("target_id",""))==str(enemy.actor_id) and int(receipt.generation)==encounter_generation and str(receipt.room_id)==room_id and float(receipt.get("actual_supplement",0.0))==amount:
    proof="original_atomic_p1_receipt";break
  if proof.is_empty(): return {}
  _g06_p1_emitted[p1_key]=true
 else:
  if _b01_damage_frames.is_empty(): return {}
  var frame: Dictionary = _b01_damage_frames.back()
  if bool(frame.g06_seen) or not is_same(frame.enemy,enemy) or int(frame.cast_id)!=id or str(frame.source)!=source or int(frame.generation)!=encounter_generation or str(frame.room_id)!=room_id: return {}
  var previous_hp: float = float(frame.g06_expected_hp)
  var hp_loss: float = previous_hp-float(enemy.hp)
  # Four double-precision rounding units accommodate subtraction only. This is
  # not a gameplay damage epsilon or a loose relative approximate comparison.
  var roundoff: float = maxf(0.000000001,absf(previous_hp)*0.0000000000000008881784197001252)
  if previous_hp<=0.0 or amount>previous_hp or hp_loss<=0.0 or absf(hp_loss-amount)>roundoff: return {}
  frame.g06_seen=true
  proof="original_first_damage_emission_and_hp_delta"
 return {"source_bridge_connected":true,"attribution_verified":true,"witness":proof,"amount":amount,"target":str(enemy.actor_id),"rank_category":str(enemy.rank_category),"source":source,"cast_id":id,"generation":encounter_generation,"room_id":room_id,"sequence":-1,"p1_receipt_key":p1_key}

func verify_g06_damage_attribution(event: Dictionary) -> Dictionary:
 if phase!="combat" or paused or hero.dead or str(event.get("kind",""))!="damage" or _g06_emissions.is_empty(): return {}
 var witness: Dictionary = _g06_emissions.back()
 if witness.is_empty(): return {}
 for key: String in ["source","target","cast_id","generation","room_id","amount"]:
  if event.get(key)!=witness.get(key): return {}
 if int(witness.generation)!=encounter_generation or str(witness.room_id)!=room_id: return {}
 if int(witness.sequence)>=0 and int(witness.sequence)!=int(event.get("sequence",-2)): return {}
 var observed: bool = false
 for recorded: Dictionary in event_log:
  if int(recorded.get("sequence",-1))==int(event.get("sequence",-2)) and recorded==event: observed=true;break
 if not observed: return {}
 witness.sequence=int(event.sequence)
 return witness.duplicate(true)

# Append these methods/fields to the EXISTING ordinary Sim leaf. Also insert
# emit_hook.gd.inc at the start of its EXISTING emit_event; do not create a second
# emit_event and do not replace the G06 damage branch or the superclass chain.
var _b04_terminal_frames: Array = []
var _b04_emissions: Array = []

func b04_model_is_bound(owner: RefCounted) -> bool:
 return owner != null and _ordinary_passive23_owner != null and _equipment_health_owner != null and is_same(_ordinary_passive23_owner.get_ref(),owner) and is_same(_equipment_health_owner.get_ref(),owner) and owner.has_method("record_verified_basic_completion")

func _b04_original_basic_state(state: Dictionary) -> bool:
 if not _b04_basic_current(state): return false
 for live: Dictionary in ink_basics:
  if is_same(live,state): return true
 return false

func _b04_basic_current(state: Dictionary) -> bool:
 if phase != "combat" or paused or hero.dead or not effect_is_current(state): return false
 if state.get("source") not in ["attack","dash_attack"] or not state.get("cast_id") is int: return false
 var id: int = int(state.cast_id)
 if id <= 0 or not _casts.has(id): return false
 var original: Dictionary = _casts[id]
 if original.get("slot") != "attack" or not original.get("cancelled") is bool or original.cancelled: return false
 if not state.get("wave_id") is String or str(state.wave_id).is_empty(): return false
 return true

func _retire_motion(state: Dictionary, at: float, reason: String) -> void:
 if not _b04_original_basic_state(state) or bool(state.get("retired",false)) or reason not in ["contact","path_end","blocked"]:
  super._retire_motion(state,at,reason)
  return
 var frame: Dictionary = {"state":state,"original_cast":_casts[int(state.cast_id)],"cast_id":state.cast_id,"wave_id":state.wave_id,"source":state.source,"generation":encounter_generation,"room_id":room_id,"at":at,"reason":reason,"seen":false,"invalid":false,"finish_depth":0,"finish_returned":false}
 _b04_terminal_frames.append(frame)
 # Original retirement still owns retired=true, common/P1 finish_cast, real
 # ink_finished insertion and the original ink_basic_finished notification.
 super._retire_motion(state,at,reason)
 if not _b04_terminal_frames.is_empty() and is_same(_b04_terminal_frames.back(),frame): _b04_terminal_frames.pop_back()

func finish_cast(id: int, cancelled: bool = false, wait_for_motion: bool = false) -> void:
 var frame: Dictionary = {}
 if not _b04_terminal_frames.is_empty() and int(_b04_terminal_frames.back().cast_id) == id:
  frame = _b04_terminal_frames.back()
  frame.finish_depth += 1
 super.finish_cast(id,cancelled,wait_for_motion)
 if not frame.is_empty():
  frame.finish_depth -= 1
  if int(frame.finish_depth) == 0 and not bool(frame.invalid): frame.finish_returned = true

func cancel_cast(id: int) -> void:
 for frame: Dictionary in _b04_terminal_frames:
  if int(frame.cast_id) == id: frame.invalid = true
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 _g02_invalidate_frames()
 for frame: Dictionary in _b04_terminal_frames: frame.invalid = true
 _b04_terminal_frames.clear()
 _b04_emissions.clear()
 super._hero_clear_transients()

func _b04_frame_matches(frame: Dictionary, data: Dictionary) -> bool:
 if bool(frame.invalid) or not bool(frame.finish_returned) or int(frame.finish_depth) != 0: return false
 if int(frame.generation) != encounter_generation or str(frame.room_id) != room_id: return false
 var state: Dictionary = frame.state
 # Original object membership was proved when the frame was opened. A nested
 # legitimate step can filter retired states out of ink_basics before this
 # callback returns; that does not turn the retained original object into a
 # copy. Cancel/room-clear still invalidate the frame and original cast.
 if not _b04_basic_current(state) or not state.get("retired") is bool or not state.retired: return false
 if int(state.cast_id) != int(frame.cast_id) or str(state.wave_id) != str(frame.wave_id) or str(state.source) != str(frame.source): return false
 if not is_same(_casts[int(frame.cast_id)],frame.original_cast): return false
 if not frame.original_cast.get("finished") is bool or not frame.original_cast.finished: return false
 if not is_finite(float(frame.at)) or float(frame.at) < float(state.released_at) or float(frame.at) > hero_time + TIME_EPS: return false
 # The base retirement appends THIS dictionary immediately before emit_event.
 # Matching values/event_log sequence do not prove source identity. In common
 # completion callbacks finish_returned is false, so even an injected event
 # during that stack cannot impersonate the yet-to-be-created notification.
 if ink_finished.is_empty() or not is_same(ink_finished.back(),data): return false
 var expected: Dictionary = _motion_public(state)
 expected.finished_at = frame.at
 expected.settled_at = hero_time
 expected.reason = frame.reason
 return data == expected

func _b04_consume_original_completion(data: Dictionary) -> Dictionary:
 if _b04_terminal_frames.is_empty(): return {}
 var frame: Dictionary = _b04_terminal_frames.back()
 if bool(frame.seen) or not _b04_frame_matches(frame,data): return {}
 # Claim the real terminal before calling the Model or ANY original observer.
 frame.seen = true
 if _ordinary_passive23_owner == null: return {}
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if not b04_model_is_bound(owner): return {}
 var emission: Dictionary = {"frame":frame,"data":data,"owner":owner}
 _b04_emissions.append(emission)
 var result: Dictionary = owner.record_verified_basic_completion(self,data)
 if not _b04_emissions.is_empty() and is_same(_b04_emissions.back(),emission): _b04_emissions.pop_back()
 return result

func verify_b04_basic_completion(owner: RefCounted, data: Dictionary, run_id: String) -> Dictionary:
 if not b04_model_is_bound(owner) or run_id.is_empty() or run_id != str(owner._run_id) or _b04_emissions.is_empty() or _b04_terminal_frames.is_empty(): return {}
 var emission: Dictionary = _b04_emissions.back()
 var frame: Dictionary = emission.frame
 if not is_same(emission.owner,owner) or not is_same(emission.data,data) or not is_same(_b04_terminal_frames.back(),frame): return {}
 if not bool(frame.seen) or not _b04_frame_matches(frame,data): return {}
 var event: Dictionary = data.duplicate(true)
 event.kind = "ink_basic_finished"
 var witness: Dictionary = {"run_id":run_id,"generation":encounter_generation,"room_id":room_id,"cast_id":frame.cast_id,"wave_id":frame.wave_id,"source":frame.source,"source_bridge_connected":true,"original_state_identity_verified":true,"terminal_frame_verified":true,"first_terminal_verified":true,"cast_lookup_verified":true,"scope_current_verified":true,"state_retired":true}
 return {"schema":"b04_verified_basic_completion_v1","event":event,"original_cast":frame.original_cast.duplicate(true),"witness":witness}

func _b04_emit_completion_receipt(result: Dictionary) -> void:
 if not result.get("accepted",false) or result.get("replayed",false) or not result.has("b04_completion"): return
 var proposal: Dictionary = result.b04_completion
 # Original observers may synchronously change rooms, cancel or kill the actor.
 # The already committed completion stays committed. Do not leak a diagnostic
 # into the replacement scope or let diagnostics precede the original event.
 if phase != "combat" or paused or hero.dead or int(proposal.scope.generation) != encounter_generation or str(proposal.scope.room_id) != room_id: return
 if _ordinary_passive23_owner == null: return
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if not b04_model_is_bound(owner) or str(owner._run_id) != str(result.b04_run_id): return
 if not cast_is_current(int(proposal.claim_to_add.cast_id)): return
 emit_event("equipment_b04_cycle",{"passive_id":"passive:08","cast_id":proposal.claim_to_add.cast_id,"wave_id":proposal.claim_to_add.wave_id,"remainder_before":proposal.remainder_before,"remainder_after":proposal.remainder_after,"triggered":proposal.triggered,"cooldowns_before":proposal.cooldowns_before,"cooldowns_after":proposal.cooldowns_after,"reductions":proposal.reductions})

# Append to the real ordinary Sim leaf. Narrow edits to the existing
# damage_enemy/_kill_enemy/emit_event/_hero_clear_transients are in the patch.
var _g02_core_frames: Array = []
var _g02_p1_frames: Array = []
var _g02_emissions: Array = []
var _g02_death_serial: int = 0

func g02_model_is_bound(owner: RefCounted) -> bool:
 return owner != null and _ordinary_passive23_owner != null and _equipment_health_owner != null and is_same(_ordinary_passive23_owner.get_ref(),owner) and is_same(_equipment_health_owner.get_ref(),owner) and owner.has_method("_g02_state")

func _g02_target_current(enemy: Dictionary, committed_notification: bool = false) -> bool:
 return phase == "combat" and (committed_notification or not paused) and not hero.dead and not enemy.is_empty() and is_same(enemy,enemy_by_id(str(enemy.get("actor_id","")))) and enemy.get("generation") is int and int(enemy.generation) == encounter_generation and str(enemy.get("room_id","")) == room_id and enemy.get("rank_category") in ["ordinary","elite","boss"]

func _g02_note_original_damage(data: Dictionary) -> void:
 if _b01_damage_frames.is_empty(): return
 var frame: Dictionary = _b01_damage_frames.back()
 if not is_same(frame.get("g02_owner"),hero): return
 if bool(frame.get("g02_damage_seen",false)) or int(frame.generation) != encounter_generation or str(frame.room_id) != room_id: return
 var enemy: Dictionary = frame.enemy
 if not _g02_target_current(enemy) or bool(frame.get("g02_pre_dead",true)) or bool(enemy.dead): return
 if data.get("target") != enemy.actor_id or data.get("source") != frame.source or not data.get("cast_id") is int or data.cast_id != frame.cast_id: return
 var amount: Variant = data.get("amount")
 if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount) <= 0.0: return
 # G06's existing ancestor propagation already subtracts completed child
 # subtrees exactly once. Read its pre-emission value; never modify it here.
 var before: float = float(frame.g06_expected_hp)
 var after: float = float(enemy.hp)
 var loss: float = before-after
 var roundoff: float = maxf(0.000000001,absf(before)*0.0000000000000008881784197001252)
 if not is_finite(before) or not is_finite(after) or before <= 0.0 or after < 0.0 or loss <= 0.0 or float(amount) > before or absf(loss-float(amount)) > roundoff: return
 frame.g02_damage_seen = true
 frame.g02_damage = {"hp_before":before,"hp_after":after,"amount":float(amount),"source":frame.source,"cast_id":frame.cast_id}

func _g02_new_frame(enemy: Dictionary, source: String, id: int, proof: String) -> Dictionary:
 _g02_death_serial += 1
 return {"enemy":enemy,"source":source,"cast_id":id,"proof":proof,"hero":hero,"generation":encounter_generation,"room_id":room_id,"rank_category":enemy.rank_category,"death_serial":_g02_death_serial,"hero_depth":0,"hero_returned":false,"emitted":false,"invalid":false}

func _g02_begin_core_death(enemy: Dictionary, source: String, id: int) -> Dictionary:
 if not _g02_target_current(enemy,true) or enemy.dead or float(enemy.hp) != 0.0 or _b01_damage_frames.is_empty() or not cast_is_current(id): return {}
 var damage: Dictionary = _b01_damage_frames.back()
 if not is_same(damage.get("g02_owner"),hero): return {}
 if not is_same(damage.enemy,enemy) or str(damage.source) != source or int(damage.cast_id) != id or int(damage.generation) != encounter_generation or str(damage.room_id) != room_id: return {}
 if not bool(damage.get("g02_damage_seen",false)) or damage.get("g02_damage",{}).get("hp_after") != 0.0 or float(damage.g02_damage.amount) <= 0.0: return {}
 var frame: Dictionary = _g02_new_frame(enemy,source,id,"original_damage_death")
 frame.damage_frame = damage
 return frame

func _g02_begin_p1_flush(id: int) -> Dictionary:
 if paused or hero.dead or not p1.roots.has(id) or not p1.ready(id): return {}
 var root: Dictionary = p1.roots[id]
 if not _p1_current(root) or root.targets.size() != 1 or not _casts.has(id): return {}
 var target: Dictionary = root.targets[0]
 var enemy: Dictionary = target.enemy
 if not _g02_target_current(enemy) or enemy.dead or float(enemy.hp) <= 0.0: return {}
 var requested: float = float(target.actual)*float(root.bonus)
 if not is_finite(requested) or requested < float(enemy.hp): return {}
 var frame: Dictionary = _g02_new_frame(enemy,"yanguizhou_p1",id,"original_p1_atomic_death")
 frame.root = root
 frame.original_cast = _casts[id]
 frame.hp_before = float(enemy.hp)
 frame.requested_supplement = requested
 frame.receipt_index = ink_p1_receipts.size()
 frame.settled_at = hero_time
 return frame

func _p1_flush(id: int) -> void:
 # Invalid/reentrant calls get their OWN empty slot and cannot borrow an
 # outer P1 frame. The inherited collector/atomic HP/CD/notifications remain.
 var frame: Dictionary = _g02_begin_p1_flush(id)
 _g02_p1_frames.append(frame)
 super._p1_flush(id)
 if not _g02_p1_frames.is_empty() and is_same(_g02_p1_frames.back(),frame): _g02_p1_frames.pop_back()

func _g02_frame_current(frame: Dictionary) -> bool:
 if frame.is_empty() or bool(frame.invalid) or not is_same(frame.hero,hero) or int(frame.generation) != encounter_generation or str(frame.room_id) != room_id: return false
 var enemy: Dictionary = frame.enemy
 if not _g02_target_current(enemy,true) or not enemy.dead or float(enemy.hp) != 0.0 or enemy.rank_category != frame.rank_category: return false
 if frame.proof == "original_damage_death":
  return not _g02_core_frames.is_empty() and is_same(_g02_core_frames.back(),frame) and not _b01_damage_frames.is_empty() and is_same(_b01_damage_frames.back(),frame.damage_frame)
 if frame.proof != "original_p1_atomic_death" or _g02_p1_frames.is_empty() or not is_same(_g02_p1_frames.back(),frame): return false
 if not bool(frame.root.settled) or not is_same(frame.root.owner,hero) or frame.root.targets.size() != 1 or not is_same(frame.root.targets[0].enemy,enemy): return false
 var id: int = int(frame.cast_id)
 if not _casts.has(id) or not is_same(_casts[id],frame.original_cast): return false
 # P1 intentionally permits same-room cancellation AFTER its atomic lethal
 # commit. Require its original cast object, not cast_is_current here.
 var index: int = int(frame.receipt_index)
 if index < 0 or index >= ink_p1_receipts.size(): return false
 var receipt: Dictionary = ink_p1_receipts[index]
 if receipt.get("cast_id") != id or receipt.get("target_id") != enemy.actor_id or receipt.get("generation") != frame.generation or receipt.get("room_id") != frame.room_id: return false
 if receipt.get("candidate") != frame.root.context.candidate or receipt.get("slot") != frame.root.context.slot or receipt.get("settled_at") != frame.settled_at: return false
 if receipt.get("target_status") != "live_original" or not receipt.get("supplement_killed") is bool or not receipt.supplement_killed: return false
 if receipt.get("actual_supplement") != frame.hp_before or receipt.get("requested_supplement") != frame.requested_supplement or float(receipt.actual_supplement) <= 0.0: return false
 return true

func _g02_matching_frame(enemy: Dictionary, source: String, id: int) -> Dictionary:
 var frames: Array = _g02_p1_frames if source == "yanguizhou_p1" else _g02_core_frames
 if frames.is_empty(): return {}
 var frame: Dictionary = frames.back()
 if frame.is_empty() or not is_same(frame.enemy,enemy) or frame.source != source or frame.cast_id != id or not _g02_frame_current(frame): return {}
 return frame

func _hero_killed(enemy: Dictionary, source: String, cast_id: int) -> void:
 var frame: Dictionary = _g02_matching_frame(enemy,source,cast_id)
 if not frame.is_empty(): frame.hero_depth += 1
 super._hero_killed(enemy,source,cast_id)
 if not frame.is_empty():
  frame.hero_depth -= 1
  if int(frame.hero_depth) == 0 and _g02_frame_current(frame): frame.hero_returned = true

func _g02_capture_original_kill(data: Dictionary) -> Dictionary:
 if data.get("credit") != "solo_lethal" or not data.get("cast_id") is int: return {}
 var enemy: Dictionary = enemy_by_id(str(data.get("target","")))
 var source: String = str(data.get("source",""))
 var frame: Dictionary = _g02_matching_frame(enemy,source,int(data.cast_id))
 if frame.is_empty() or bool(frame.emitted) or not bool(frame.hero_returned) or int(frame.hero_depth) != 0: return {}
 var expected: Dictionary = {"target":enemy.actor_id,"position":enemy.position,"source":source,"cast_id":frame.cast_id,"credit":"solo_lethal","enemy_kind":enemy.kind}
 if frame.proof == "original_p1_atomic_death": expected.p1_supplement = true
 if data != expected: return {}
 # No outward callback occurs between the inherited _hero_killed return and
 # this original kill emission. Claim before inherited event observers.
 frame.emitted = true
 return {"frame":frame,"raw":data.duplicate(true),"sequence":-1}

func verify_g02_kill_attribution(owner: RefCounted, event: Dictionary, run_id: String) -> Dictionary:
 if not g02_model_is_bound(owner) or run_id.is_empty() or str(owner._run_id) != run_id or event.get("kind") != "kill" or _g02_emissions.is_empty(): return {}
 var emission: Dictionary = _g02_emissions.back()
 if emission.is_empty(): return {}
 var frame: Dictionary = emission.frame
 if not _g02_frame_current(frame) or not bool(frame.emitted): return {}
 for key: String in emission.raw:
  if event.get(key) != emission.raw[key]: return {}
 if event.get("generation") != frame.generation or event.get("room_id") != frame.room_id or not event.get("sequence") is int: return {}
 if int(emission.sequence) >= 0 and emission.sequence != event.sequence: return {}
 var observed: bool = false
 for recorded: Dictionary in event_log:
  if recorded.get("sequence") == event.sequence and recorded == event: observed = true;break
 if not observed: return {}
 emission.sequence = int(event.sequence)
 var enemy: Dictionary = frame.enemy
 var scope: Dictionary = {"run_id":run_id,"actor_id":owner.state.actor_id,"generation":encounter_generation,"room_id":room_id}
 var witness: Dictionary = {"scope":scope,"proof":frame.proof,"death_serial":frame.death_serial,"target":enemy.actor_id,"rank_category":frame.rank_category,"source":frame.source,"cast_id":frame.cast_id,"source_bridge_connected":true,"original_target_identity_verified":true,"original_death_commit_verified":true,"hero_killed_return_verified":true,"first_kill_emission_verified":true,"current_scope_verified":true,"bound_owner_verified":true}
 var target: Dictionary = {"actor_id":enemy.actor_id,"rank_category":frame.rank_category,"generation":frame.generation,"room_id":frame.room_id,"dead":enemy.dead,"hp":enemy.hp}
 return {"schema":"g02_verified_own_death_v1","event":event.duplicate(true),"original_target":target,"witness":witness}

func _g02_invalidate_frames() -> void:
 for frames: Array in [_g02_core_frames,_g02_p1_frames]:
  for frame: Dictionary in frames:
   if not frame.is_empty(): frame.invalid = true
 _g02_core_frames.clear();_g02_p1_frames.clear();_g02_emissions.clear()

# Source combat clock and full P2/Common stat chain, installed at construction.
# No added kill emit/hook: B02 reuses the frozen G02 death verifier.
func b02_model_is_bound(owner: RefCounted) -> bool:
 return g02_model_is_bound(owner) and owner.has_method("b02_buff_effect") and common != null and common.get_script() == OrdinaryPursuitCommon and common.model != null and is_same(common.model.get_ref(),owner)

func b02_current_buff_effect() -> Dictionary:
 if _ordinary_passive23_owner == null: return {}
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if not b02_model_is_bound(owner): return {}
 return owner.b02_buff_effect(self)
