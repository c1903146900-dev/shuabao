extends "res://tests/ink_river_hexes_20261006/ownership01/sim.gd"

# Reviewed Boss composition: install only in construction, before Session admission.
const OrdinaryFirstFloorBossDirector = preload("res://tests/ink_first_floor_boss_20261008/source01/enemy_director.gd")
const OrdinaryPursuitCommon = preload("res://elixir_swift_20261010/common_bridge.gd")
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
 _g01_projection_synced(owner)
func _fixed_step(real_dt: float) -> void:
 var g01_step: Dictionary=_g01_call_frame("fixed_step") if real_dt>0.0 else {}
 _g01_step_frames.append(g01_step)
 refresh_passive23()
 super._fixed_step(real_dt)
 refresh_passive23()
 assert(is_same(_g01_step_frames.back(),g01_step));_g01_step_frames.pop_back()
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
 if owner.has_method("hunter_elixir_multiplier"):
  result *= float(owner.hunter_elixir_multiplier(enemy))
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
 var g03_frame: Dictionary = _g03_begin_damage(enemy,source,cast_id)
 _g03_damage_frames.append(g03_frame)
 var result: bool = super.damage_enemy(enemy,amount,source,cast_id,is_true,critical,metadata)
 _g03_end_damage(g03_frame)
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
func _c03_forward_original_event(kind: String, data: Dictionary = {}) -> void:
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
 var g03_witness: Dictionary = _g03_capture_original_damage(data)
 _g03_emissions.append(g03_witness)
 var witness: Dictionary = _g06_capture_original_damage(data)
 _g06_emissions.append(witness)
 _g01_damage_effect(g03_witness)
 super.emit_event(kind,data)
 if not _g06_emissions.is_empty() and is_same(_g06_emissions.back(),witness): _g06_emissions.pop_back()
 if not _g03_emissions.is_empty() and is_same(_g03_emissions.back(),g03_witness): _g03_emissions.pop_back()

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
 var swift_frame: Dictionary = _swift_finish_candidate(id,cancelled)
 var frame: Dictionary = {}
 if not _b04_terminal_frames.is_empty() and int(_b04_terminal_frames.back().cast_id) == id:
  frame = _b04_terminal_frames.back()
  frame.finish_depth += 1
 super.finish_cast(id,cancelled,wait_for_motion)
 if not frame.is_empty():
  frame.finish_depth -= 1
  if int(frame.finish_depth) == 0 and not bool(frame.invalid): frame.finish_returned = true
 _swift_finish_returned(swift_frame)

func cancel_cast(id: int) -> void:
 for frame: Dictionary in _b04_terminal_frames:
  if int(frame.cast_id) == id: frame.invalid = true
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 # Pending source evidence expires; earned Model task progress is untouched.
 _g01_root_epoch+=1
 _g01_roots.clear();_g01_push_bindings.clear();_g01_vortex_bindings.clear()
 _g03_invalidate_frames()
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
 var g03_frame: Dictionary = _g03_begin_p1_flush(id)
 _g03_damage_frames.append(g03_frame)
 super._p1_flush(id)
 if not _g02_p1_frames.is_empty() and is_same(_g02_p1_frames.back(),frame): _g02_p1_frames.pop_back()
 _g03_end_damage(g03_frame)

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

# Original HP commit seam. Public damage events never enter this authority.
# Core has no outward callback between _hero_before_hp_commit's return and
# the real HP write followed immediately by _hero_after_incoming.
var _d04_pending_hp: Dictionary = {}
var _d04_hp_notifications: Array = []
var _d04_hp_serial: int = 0

func d04_model_is_bound(owner: RefCounted) -> bool:
 return b02_model_is_bound(owner) and owner.has_method("record_verified_lifeline_damage")

func _hero_before_hp_commit(packet: float, metadata: Dictionary) -> float:
 _d04_pending_hp = {}
 var original: float = super._hero_before_hp_commit(packet,metadata)
 if phase != "combat" or paused or hero.dead or not is_finite(original) or original <= 0.0: return original
 if not is_finite(hero.hp) or hero.hp <= 0.0 or not is_finite(float(hero.stats.max_hp)) or float(hero.stats.max_hp) <= 0.0: return original
 _d04_pending_hp = {"owner":hero,"metadata":metadata,"generation":encounter_generation,"room_id":room_id,"hp_before":hero.hp,"max_hp":float(hero.stats.max_hp),"packet":maxf(0.0,original)}
 return original

func _hero_after_incoming(before_hp: float, lost: float, metadata: Dictionary) -> void:
 var frame: Dictionary = _d04_pending_hp
 # Consume the adjacent-commit permit before any inherited/added callback.
 _d04_pending_hp = {}
 super._hero_after_incoming(before_hp,lost,metadata)
 if frame.is_empty() or not is_same(frame.owner,hero) or not is_same(frame.metadata,metadata): return
 if phase != "combat" or paused or hero.dead or frame.generation != encounter_generation or frame.room_id != room_id: return
 if not is_finite(before_hp) or not is_finite(lost) or not is_finite(hero.hp) or before_hp != float(frame.hp_before) or lost <= 0.0 or hero.hp <= 0.0: return
 if hero.hp != maxf(0.0,before_hp-float(frame.packet)) or lost != minf(before_hp,float(frame.packet)) or float(hero.stats.max_hp) != float(frame.max_hp): return
 if _ordinary_passive23_owner == null: return
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if not d04_model_is_bound(owner): return
 _d04_hp_serial += 1
 frame["serial"] = _d04_hp_serial
 frame["hp_after"] = hero.hp
 frame["lost"] = lost
 _d04_hp_notifications.append(frame)
 owner.record_verified_lifeline_damage(self,metadata)
 if not _d04_hp_notifications.is_empty() and is_same(_d04_hp_notifications.back(),frame): _d04_hp_notifications.pop_back()

func verify_d04_hp_commit(owner: RefCounted, metadata: Dictionary, run_id: String) -> Dictionary:
 if not d04_model_is_bound(owner) or run_id.is_empty() or str(owner._run_id) != run_id or _d04_hp_notifications.is_empty(): return {}
 var frame: Dictionary = _d04_hp_notifications.back()
 if not is_same(frame.owner,hero) or not is_same(frame.metadata,metadata): return {}
 if phase != "combat" or paused or hero.dead or hero.hp <= 0.0 or frame.generation != encounter_generation or frame.room_id != room_id: return {}
 if hero.hp != float(frame.hp_after) or float(hero.stats.max_hp) != float(frame.max_hp): return {}
 var scope: Dictionary = {"run_id":run_id,"actor_id":owner.state.actor_id,"room_id":room_id,"generation":encounter_generation}
 var commit: Dictionary = {"serial":frame.serial,"kind":"original_incoming_damage","source":str(metadata.get("source","enemy")),"hp_before":frame.hp_before,"hp_after":frame.hp_after,"lost":frame.lost,"packet":frame.packet,"max_hp":frame.max_hp}
 var witness: Dictionary = {"original_owner_verified":true,"original_metadata_identity_verified":true,"adjacent_hp_commit_verified":true,"current_scope_verified":true,"bound_model_verified":true}
 return {"schema":"d04_original_hp_commit_v1","scope":scope,"commit":commit,"witness":witness}

# G03-only commit witnesses. Ordinary and atomic P1 calls share this stack;
# G06/G02 frames, filters, amounts and notification order stay unchanged.
var _g03_damage_frames: Array = []
var _g03_emissions: Array = []
var _g03_commit_serial: int = 0

func g03_model_is_bound(owner: RefCounted) -> bool:
 return owner != null and _ordinary_passive23_owner != null and _equipment_health_owner != null and is_same(_ordinary_passive23_owner.get_ref(),owner) and is_same(_equipment_health_owner.get_ref(),owner) and owner.has_method("_g03_state")

func _g03_begin_damage(enemy: Dictionary, source: String, id: int) -> Dictionary:
 if not _g02_target_current(enemy) or enemy.dead or float(enemy.hp) <= 0.0 or not cast_is_current(id): return {}
 return {"proof":"original_damage_hp_commit","enemy":enemy,"hero":hero,"source":source,"cast_id":id,"generation":encounter_generation,"room_id":room_id,"rank_category":enemy.rank_category,"pre_hp":float(enemy.hp),"expected_hp":float(enemy.hp),"seen":false,"invalid":false}

func _g03_begin_p1_flush(id: int) -> Dictionary:
 if paused or hero.dead or not p1.roots.has(id) or not p1.ready(id): return {}
 var root: Dictionary = p1.roots[id]
 if not _p1_current(root) or root.targets.size() != 1 or not _casts.has(id): return {}
 var enemy: Dictionary = root.targets[0].enemy
 if not _g02_target_current(enemy) or enemy.dead or float(enemy.hp) <= 0.0: return {}
 var requested: float = float(root.targets[0].actual)*float(root.bonus)
 if not is_finite(requested) or requested <= 0.0: return {}
 return {"proof":"original_p1_atomic_hp_commit","enemy":enemy,"hero":hero,"source":"yanguizhou_p1","cast_id":id,"generation":encounter_generation,"room_id":room_id,"rank_category":enemy.rank_category,"pre_hp":float(enemy.hp),"expected_hp":float(enemy.hp),"seen":false,"invalid":false,"root":root,"original_cast":_casts[id],"requested":requested,"receipt_index":ink_p1_receipts.size(),"settled_at":hero_time}

func _g03_end_damage(frame: Dictionary) -> void:
 if _g03_damage_frames.is_empty() or not is_same(_g03_damage_frames.back(),frame): return
 _g03_damage_frames.pop_back()
 if frame.is_empty() or bool(frame.invalid): return
 # A parent has not committed until its own first damage emission. No original
 # callback exists between its HP write and that emission. Rebase to the actual
 # HP after a complete child subtree, avoiding cancellation-roundoff residuals
 # that a tiny forged public damage could otherwise mistake for a parent hit.
 for index: int in range(_g03_damage_frames.size()-1,-1,-1):
  var parent: Dictionary = _g03_damage_frames[index]
  if parent.is_empty(): continue
  if is_same(parent.enemy,frame.enemy) and is_same(parent.hero,frame.hero) and parent.generation == frame.generation and parent.room_id == frame.room_id:
   if not bool(parent.seen): parent.expected_hp = float(frame.enemy.hp)
   # Even a seen parent owns the subtree's eventual handoff. Never skip it.
   break

func _g03_capture_original_damage(data: Dictionary) -> Dictionary:
 if phase != "combat" or paused or hero.dead or _g03_damage_frames.is_empty(): return {}
 var frame: Dictionary = _g03_damage_frames.back()
 if frame.is_empty() or bool(frame.invalid) or bool(frame.seen) or not is_same(frame.hero,hero) or frame.generation != encounter_generation or frame.room_id != room_id: return {}
 var enemy: Dictionary = frame.enemy
 if not _g02_target_current(enemy) or enemy.rank_category != frame.rank_category: return {}
 if data.get("target") != enemy.actor_id or data.get("source") != frame.source or not data.get("cast_id") is int or data.cast_id != frame.cast_id: return {}
 var value: Variant = data.get("amount")
 if not (value is int or value is float) or not is_finite(float(value)) or float(value) <= 0.0: return {}
 var amount: float = float(value)
 var before: float = float(frame.expected_hp)
 var after: float = float(enemy.hp)
 var loss: float = before-after
 var roundoff: float = maxf(0.000000001,absf(before)*0.0000000000000008881784197001252)
 if not is_finite(before) or not is_finite(after) or before <= 0.0 or after < 0.0 or amount > before or loss <= 0.0 or absf(loss-amount) > roundoff: return {}
 if frame.proof == "original_damage_hp_commit":
  if frame.source == "yanguizhou_p1" or enemy.dead or not cast_is_current(int(frame.cast_id)): return {}
 elif frame.proof == "original_p1_atomic_hp_commit":
  if not _g03_p1_commit_matches(frame,data,amount): return {}
 else: return {}
 var owner_hp: float = float(hero.hp)
 var owner_max_hp: float = float(hero.stats.max_hp)
 if not is_finite(owner_hp) or not is_finite(owner_max_hp) or owner_hp <= 0.0 or owner_max_hp <= 0.0 or owner_hp > owner_max_hp: return {}
 frame.seen = true
 _g03_commit_serial += 1
 # Snapshot after the real target commit but BEFORE super.emit_event and this
 # packet's lifesteal. Earlier source reactions affect it; later observers don't.
 var commit: Dictionary = {"target":str(enemy.actor_id),"rank_category":str(enemy.rank_category),"target_hp_before":before,"target_hp_after":after,"amount":amount,"owner_actor_id":str(hero.actor_id),"owner_hp":owner_hp,"owner_max_hp":owner_max_hp}
 # The pinned current ancestry performs no intervening emission for damage.
 # Core emit_event increments sequence first. Pin it BEFORE callbacks; a prior
 # same-payload event must never claim or poison this new commit's identity.
 return {"frame":frame,"raw":data.duplicate(true),"commit":commit,"sequence":sequence+1,"commit_serial":_g03_commit_serial}

func _g03_p1_commit_matches(frame: Dictionary, data: Dictionary, amount: float) -> bool:
 var root: Dictionary = frame.root
 var enemy: Dictionary = frame.enemy
 var id: int = int(frame.cast_id)
 if not bool(root.settled) or not is_same(root.owner,hero) or root.targets.size() != 1 or not is_same(root.targets[0].enemy,enemy): return false
 if not _casts.has(id) or not is_same(_casts[id],frame.original_cast): return false
 var index: int = int(frame.receipt_index)
 if index < 0 or index != ink_p1_receipts.size()-1: return false
 var receipt: Dictionary = ink_p1_receipts[index]
 var expected: float = minf(float(frame.pre_hp),float(frame.requested))
 if receipt.get("cast_id") != id or receipt.get("target_id") != enemy.actor_id or receipt.get("generation") != frame.generation or receipt.get("room_id") != frame.room_id: return false
 if receipt.get("candidate") != root.context.candidate or receipt.get("slot") != root.context.slot or receipt.get("settled_at") != frame.settled_at: return false
 if receipt.get("distinct_targets") != 1 or receipt.get("qualified") != true or receipt.get("target_status") != "live_original": return false
 if receipt.get("requested_supplement") != frame.requested or receipt.get("actual_supplement") != expected or amount != expected: return false
 if float(enemy.hp) != maxf(0.0,float(frame.pre_hp)-float(frame.requested)) or receipt.get("supplement_killed") != (float(enemy.hp) == 0.0) or bool(enemy.dead) != bool(receipt.supplement_killed): return false
 var original: Dictionary = {"target":enemy.actor_id,"position":enemy.position,"amount":amount,"source":"yanguizhou_p1","parent_skill":root.context.candidate,"cast_id":id,"critical":false,"damage_type":"final_supplement","p1_supplement":true,"hex_generated":false,"replay":false,"basic_attack":false,"final_damage_already_settled":true,"enemy_kind":enemy.kind}
 return data == original

func verify_g03_damage_attribution(owner: RefCounted, event: Dictionary, run_id: String) -> Dictionary:
 if not g03_model_is_bound(owner) or run_id.is_empty() or str(owner._run_id) != run_id or event.get("kind") != "damage" or _g03_emissions.is_empty(): return {}
 var emission: Dictionary = _g03_emissions.back()
 if emission.is_empty(): return {}
 var frame: Dictionary = emission.frame
 if bool(frame.invalid) or not bool(frame.seen) or not is_same(frame.hero,hero) or frame.generation != encounter_generation or frame.room_id != room_id: return {}
 if phase != "combat" or hero.dead or _g03_damage_frames.is_empty() or not is_same(_g03_damage_frames.back(),frame): return {}
 var enemy: Dictionary = frame.enemy
 if not is_same(enemy,enemy_by_id(str(enemy.actor_id))) or enemy.generation != frame.generation or enemy.room_id != frame.room_id or enemy.rank_category != frame.rank_category: return {}
 # Current target HP and owner HP/maxHP may legitimately differ after an earlier
 # observer's nested damage/heal. The original snapshot is the authority here.
 for key: String in emission.raw:
  if event.get(key) != emission.raw[key]: return {}
 if event.get("generation") != frame.generation or event.get("room_id") != frame.room_id or not event.get("sequence") is int: return {}
 if emission.sequence != event.sequence: return {}
 var observed: bool = false
 for recorded: Dictionary in event_log:
  if recorded.get("sequence") == event.sequence and recorded == event: observed = true;break
 if not observed: return {}
 var scope: Dictionary = {"run_id":run_id,"actor_id":str(owner.state.actor_id),"generation":frame.generation,"room_id":frame.room_id}
 return {"schema":"g03_verified_damage_commit_v1","event":event.duplicate(true),"commit":emission.commit.duplicate(true),"witness":{"source_bridge_connected":true,"original_target_identity_verified":true,"original_hp_commit_verified":true,"first_damage_emission_verified":true,"owner_commit_snapshot_verified":true,"current_scope_verified":true,"bound_owner_verified":true,"scope":scope,"proof":frame.proof,"commit_serial":emission.commit_serial,"source":frame.source,"target":str(enemy.actor_id),"cast_id":frame.cast_id}}

func _g03_invalidate_frames() -> void:
 for frame: Dictionary in _g03_damage_frames:
  if not frame.is_empty(): frame.invalid = true
 _g03_damage_frames.clear()
 _g03_emissions.clear()

# E03 uses the exact same bound Model, Common successor and original runtime.
func e03_model_is_bound(owner: RefCounted) -> bool:
 return b02_model_is_bound(owner) and owner.has_method("e03_regen_effect") and common.has_method("e03_clock_context") and common.has_method("e03_tick_interval")

func e03_current_regen_effect(for_tick: bool = false) -> Dictionary:
 if _ordinary_passive23_owner == null: return {}
 var owner: RefCounted = _ordinary_passive23_owner.get_ref()
 if not e03_model_is_bound(owner): return {}
 return owner.e03_regen_effect(self,for_tick)

# Successful Q/E release proof. Public notifications never authorize a grant.
var _c03_release_calls: Array = []
var _c03_release_commit: Dictionary = {}
var _c03_notification_depth: int = 0

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 var frame: Dictionary = _c03_begin_release_call(action,context)
 _c03_release_calls.append(frame)
 var result: Dictionary = super._hero_cast_skill(action,context)
 assert(is_same(_c03_release_calls.back(),frame))
 _c03_release_calls.pop_back()
 return result

func _e3_exchange(state: Dictionary, b: Vector3) -> Dictionary:
 var frame: Dictionary = _c03_begin_release_call("e",state.get("context",{}))
 if not frame.is_empty(): frame["exchange_state"] = state
 _c03_release_calls.append(frame)
 var result: Dictionary = super._e3_exchange(state,b)
 assert(is_same(_c03_release_calls.back(),frame))
 _c03_release_calls.pop_back()
 return result

func _c03_begin_release_call(action: String, context: Dictionary) -> Dictionary:
 if action not in ["q","e"] or not effect_is_current(context) or hero.dead or paused: return {}
 var owner: RefCounted = _ordinary_passive23_owner.get_ref() if _ordinary_passive23_owner != null else null
 if owner == null or not g02_model_is_bound(owner) or owner.get_script().resource_path != "res://equipment_scholar_20261011/model.gd" or not owner.has_method("record_c03_release"): return {}
 var id: int = int(context.get("cast_id",-1))
 if not _casts.has(id): return {}
 return {"action":action,"cast_id":id,"cast":_casts[id],"hero":hero,"owner":owner,"common":common,"runtime":common.runtime,"run_id":owner._run_id,"generation":encounter_generation,"room_id":room_id,"combat_level_id":combat_level_id,"notification_depth":_c03_notification_depth,"seen":false,"g01_before":_g01_release_before()}

func _c03_release_state_current(family: String, state: Dictionary, frame: Dictionary) -> bool:
 if frame.is_empty() or state.is_empty() or frame.seen or frame.notification_depth != _c03_notification_depth: return false
 if phase != "combat" or paused or hero.dead or not is_same(hero,frame.hero) or not is_same(common,frame.common) or not is_same(common.runtime,frame.runtime): return false
 if not g02_model_is_bound(frame.owner) or frame.owner._run_id != frame.run_id: return false
 if encounter_generation != frame.generation or room_id != frame.room_id or combat_level_id != frame.combat_level_id: return false
 if not effect_is_current(state) or int(state.get("cast_id",-1)) != frame.cast_id or not _casts.has(frame.cast_id) or not is_same(_casts[frame.cast_id],frame.cast): return false
 if family.left(1) != frame.action: return false
 match family:
  "q1":
   if state.get("source","") != "q1": return false
   for original: Dictionary in ink_waves:
    if is_same(original,state): return true
  "q2":
   for original: Dictionary in ink_rivers:
    if is_same(original,state): return true
  "q3": return is_same(ink_mountain,state) and not bool(state.get("retired",true))
  "e1": return is_same(ink_rain,state) and is_same(state.get("owner"),hero) and _e1_current(state)
  "e2": return is_same(ink_boat,state) and is_same(state.get("owner"),hero) and state.get("phase","") == "outward"
  "e3": return is_same(frame.get("exchange_state"),state) and _e3_live(state) and state.get("phase","") == "settling" and bool(state.get("release_completed",false)) and state.get("impact") is Dictionary and not state.impact.is_empty()
 return false

func _equipment_release_committed(family: String, state: Dictionary) -> void:
 if _c03_release_calls.is_empty() or not _c03_release_commit.is_empty(): return
 var frame: Dictionary = _c03_release_calls.back()
 if not _c03_release_state_current(family,state,frame): return
 _g01_register_root(family,state,frame)
 frame.seen = true
 var evidence: Dictionary = {"family":family,"cast_id":frame.cast_id,"run_id":frame.run_id,"generation":frame.generation,"room_id":frame.room_id,"combat_level_id":frame.combat_level_id}
 _c03_release_commit = {"frame":frame,"state":state,"evidence":evidence}
 frame.owner.record_c03_release(self,evidence)
 _c03_release_commit = {}

func verify_c03_release(owner: RefCounted, evidence: Dictionary) -> bool:
 if _c03_release_commit.is_empty() or _c03_release_calls.is_empty(): return false
 var frame: Dictionary = _c03_release_commit.frame
 if not is_same(_c03_release_calls.back(),frame) or not is_same(frame.owner,owner) or evidence != _c03_release_commit.evidence: return false
 if not frame.seen or frame.notification_depth != _c03_notification_depth or not g02_model_is_bound(owner): return false
 if phase != "combat" or paused or hero.dead or not is_same(hero,frame.hero) or not is_same(common,frame.common) or not is_same(common.runtime,frame.runtime): return false
 if owner._run_id != frame.run_id or encounter_generation != frame.generation or room_id != frame.room_id or combat_level_id != frame.combat_level_id: return false
 return effect_is_current(_c03_release_commit.state) and _casts.has(frame.cast_id) and is_same(_casts[frame.cast_id],frame.cast)

func emit_event(kind: String, data: Dictionary = {}) -> void:
 _c03_notification_depth += 1
 _c03_forward_original_event(kind,data)
 _c03_notification_depth -= 1

# Swift05 proof exists only inside original player locomotion and completion.
var _swift_motion_frames: Array=[]
var _swift_finish_commit: Dictionary={}
func _step_player_locomotion(real_dt: float) -> void:
 var frame: Dictionary={}
 var owner: RefCounted=_ordinary_passive23_owner.get_ref() if _ordinary_passive23_owner!=null else null
 var id: int=int(_dash_state.get("cast_id",-1))
 if owner!=null and owner.get_script().resource_path=="res://equipment_scholar_20261011/model.gd" and owner.has_method("record_swift_end") and g02_model_is_bound(owner) and phase=="combat" and not paused and not hero.dead and real_dt>0.0 and hero.dash_left>0.0 and effect_is_current(_dash_state) and _casts.has(id) and _casts[id].get("slot")=="shift" and not _casts[id].get("finished",true):
  frame={"state":_dash_state,"cast":_casts[id],"cast_id":id,"hero":hero,"owner":owner,"common":common,"runtime":common.runtime,"run_id":owner._run_id,"generation":encounter_generation,"room_id":room_id,"combat_level_id":combat_level_id,"dash_serial":dash_serial,"depth":_c03_notification_depth,"seen":false,"in_finish":false}
 _swift_motion_frames.append(frame)
 super._step_player_locomotion(real_dt)
 assert(is_same(_swift_motion_frames.back(),frame))
 _swift_motion_frames.pop_back()
func _swift_frame_current(frame: Dictionary) -> bool:
 if frame.is_empty() or _swift_motion_frames.is_empty() or not is_same(_swift_motion_frames.back(),frame) or frame.depth!=_c03_notification_depth:return false
 if phase!="combat" or paused or hero.dead or not is_same(hero,frame.hero) or not is_same(common,frame.common) or not is_same(common.runtime,frame.runtime):return false
 if not g02_model_is_bound(frame.owner) or frame.owner._run_id!=frame.run_id or encounter_generation!=frame.generation or room_id!=frame.room_id or combat_level_id!=frame.combat_level_id:return false
 return dash_serial==frame.dash_serial and is_same(_dash_state,frame.state) and effect_is_current(_dash_state) and _casts.has(frame.cast_id) and is_same(_casts[frame.cast_id],frame.cast) and frame.cast.get("slot")=="shift" and not bool(frame.cast.get("cancelled",true))
func _swift_finish_candidate(id: int, cancelled: bool)->Dictionary:
 if cancelled or _swift_motion_frames.is_empty() or not _swift_finish_commit.is_empty():return {}
 var frame: Dictionary=_swift_motion_frames.back()
 if not _swift_frame_current(frame) or int(frame.cast_id)!=id or frame.seen or frame.in_finish or bool(frame.cast.get("finished",true)) or hero.dash_left!=0.0:return {}
 frame.in_finish=true
 return frame
func _swift_finish_returned(frame: Dictionary)->void:
 if frame.is_empty():return
 frame.in_finish=false
 if not _swift_frame_current(frame) or frame.seen or not bool(frame.cast.get("finished",false)) or hero.dash_left!=0.0:return
 frame.seen=true
 var evidence: Dictionary={"cast_id":frame.cast_id,"dash_serial":frame.dash_serial,"run_id":frame.run_id,"generation":frame.generation,"room_id":frame.room_id,"combat_level_id":frame.combat_level_id}
 _swift_finish_commit={"frame":frame,"evidence":evidence}
 frame.owner.record_swift_end(self,evidence)
 _swift_finish_commit={}
func verify_swift_end(owner: RefCounted,evidence: Dictionary)->bool:
 if _swift_finish_commit.is_empty():return false
 var frame: Dictionary=_swift_finish_commit.frame
 return _swift_frame_current(frame) and is_same(frame.owner,owner) and frame.seen and bool(frame.cast.get("finished",false)) and hero.dash_left==0.0 and evidence==_swift_finish_commit.evidence

# DRAFT fragment for exact ordinary01/sim.gd successor; not a standalone script.
# Integration must insert _g01_register_root before frame.seen=true at the already
# authenticated _equipment_release_committed, and _g01_damage_effect after the
# original _g03_capture_original_damage (before public notification).
const G01_MODEL_PATH := "res://equipment_scholar_20261011/model.gd"
var _g01_roots: Dictionary={}
var _g01_root_epoch:int=0
var _g01_effect_commits: Array=[]
var _g01_effect_serial:int=0
var _g01_source_calls:Array=[]
var _g01_step_frames:Array=[]
const G01_FULL_EFFECTS_READY := true # Complete source chain reviewed; runtime acceptance is separate.
func g01_model_is_bound(owner:RefCounted)->bool:
 return G01_FULL_EFFECTS_READY and owner!=null and owner.get_script().resource_path==G01_MODEL_PATH and owner.has_method("record_g01_effect") and g03_model_is_bound(owner) and b02_model_is_bound(owner)
func _g01_register_root(family:String,state:Dictionary,frame:Dictionary)->void:
 # Caller is the existing successful-release hook after its strict original
 # _c03_release_state_current check, before any C03/public callback.
 if _c03_release_calls.is_empty() or not is_same(_c03_release_calls.back(),frame):return
 if not _c03_release_state_current(family,state,frame) or not g01_model_is_bound(frame.owner):return
 var key:String=str(frame.cast_id)
 if _g01_roots.has(key):return
 _g01_roots[key]={"epoch":_g01_root_epoch,"effect_claimed":false,"family":family,"cast_id":frame.cast_id,"cast":frame.cast,"state":state,"owner":frame.owner,"hero":hero,"common":common,"runtime":common.runtime,"run_id":frame.run_id,"generation":encounter_generation,"room_id":room_id,"combat_level_id":combat_level_id}
func _g01_root_current(root:Dictionary)->bool:
 if root.is_empty() or phase!="combat" or paused or hero.dead:return false
 var registered:Dictionary=_g01_roots.get(str(root.get("cast_id",-1)),{})
 if not is_same(registered,root) or root.get("epoch",-1)!=_g01_root_epoch:return false
 if not g01_model_is_bound(root.owner) or not is_same(root.hero,hero) or not is_same(root.common,common) or not is_same(root.runtime,common.runtime):return false
 if root.owner._run_id!=root.run_id or root.generation!=encounter_generation or root.room_id!=room_id or root.combat_level_id!=combat_level_id:return false
 return _casts.has(root.cast_id) and is_same(_casts[root.cast_id],root.cast) and cast_is_current(root.cast_id)
func _g01_damage_effect(witness:Dictionary)->void:
 if witness.is_empty():return
 var frame:Dictionary=witness.frame
 var key:String=str(frame.cast_id)
 if not _g01_roots.has(key):return
 var root:Dictionary=_g01_roots[key]
 if not _g01_root_current(root) or not _g01_damage_parent_matches(root,frame):return
 if _g03_damage_frames.is_empty() or not is_same(_g03_damage_frames.back(),frame) or not frame.seen or frame.invalid or not is_same(frame.hero,root.hero):return
 if float(witness.commit.amount)<=0.0:return
 _g01_submit_effect(root,"original_skill_damage",{"damage_witness":witness},_c03_notification_depth)
func _g01_damage_parent_matches(root:Dictionary,frame:Dictionary)->bool:
 if frame.proof=="original_p1_atomic_hp_commit":
  # Existing G03 capture has already verified exact original atomic HP loss,
  # its original P1 receipt and packet. Retain the exact authored parent root.
  return frame.source=="yanguizhou_p1" and p1.roots.has(root.cast_id) and is_same(p1.roots[root.cast_id],frame.root) and frame.root.context.get("candidate")==root.family and is_same(frame.original_cast,root.cast)
 if frame.proof!="original_damage_hp_commit" or _b01_damage_frames.is_empty():return false
 var packet:Dictionary=_b01_damage_frames.back()
 if not is_same(packet.enemy,frame.enemy) or packet.cast_id!=root.cast_id or packet.source!=frame.source:return false
 var metadata:Dictionary=packet.metadata
 if bool(metadata.get("replay",false)) or bool(metadata.get("basic_attack",false)) or bool(metadata.get("p1_supplement",false)) or bool(metadata.get("p2_generated",false)) or not bool(metadata.get("active_skill",false)):return false
 if frame.source==root.family:return not bool(metadata.get("hex_generated",false))
 if frame.source!="hex_yanguizhou_h04" or root.family!="q2" or not packet.original_h04 or not _river_hex_original_packet(frame.source,root.cast_id,metadata) or _river_hex_packet_frames.is_empty():return false
 return is_same(_river_hex_packet_frames.back().state,root.state) and is_same(_river_hex_packet_frames.back().enemy,frame.enemy)
func _g01_submit_effect(root:Dictionary,kind:String,proof:Dictionary,depth:int)->void:
 if not _g01_root_current(root) or bool(root.effect_claimed) or depth!=_c03_notification_depth or not _g01_effect_proof_current(root,kind,proof):return
 _g01_effect_serial+=1
 var scope:Dictionary={"run_id":root.run_id,"actor_id":str(root.owner.state.actor_id),"generation":root.generation,"room_id":root.room_id}
 var evidence:Dictionary={"schema":"g01_original_effect_v1","scope":scope,"family":root.family,"cast_id":root.cast_id,"effect_serial":_g01_effect_serial,"successful_release":true,"actual_effect":true,"kind":kind}
 var commit:Dictionary={"root":root,"kind":kind,"proof":proof,"depth":depth,"evidence":evidence}
 _g01_effect_commits.append(commit)
 var result:Dictionary=root.owner.record_g01_effect(self,evidence)
 assert(is_same(_g01_effect_commits.back(),commit))
 _g01_effect_commits.pop_back()
 if result.get("accepted",false) and not result.get("replayed",false):root.effect_claimed=true
 if result.get("g01_completed_now",false):_g01_queue_projection(root)
func verify_g01_effect(owner:RefCounted,evidence:Dictionary)->bool:
 if _g01_effect_commits.is_empty():return false
 var commit:Dictionary=_g01_effect_commits.back()
 return is_same(commit.root.owner,owner) and _g01_root_current(commit.root) and commit.depth==_c03_notification_depth and not bool(commit.root.effect_claimed) and evidence==commit.evidence and _g01_effect_proof_current(commit.root,commit.kind,commit.proof)
# On original _hero_clear_transients, clear only Sim roots/uncommitted frames.
# Never delete Model g01_equipment_progress or its already committed evolution.

func _g01_damage_proof_current(root:Dictionary,proof:Dictionary)->bool:
 var value:Variant=proof.get("damage_witness")
 if not value is Dictionary or value.is_empty() or _g03_emissions.is_empty():return false
 var witness:Dictionary=value
 if not is_same(_g03_emissions.back(),witness) or witness.get("sequence",-1)!=sequence+1:return false
 if not witness.get("frame") is Dictionary or not witness.get("commit") is Dictionary:return false
 var frame:Dictionary=witness.frame
 if _g03_damage_frames.is_empty() or not is_same(_g03_damage_frames.back(),frame):return false
 if not frame.seen or frame.invalid or not is_same(frame.hero,root.hero) or frame.cast_id!=root.cast_id:return false
 if frame.generation!=root.generation or frame.room_id!=root.room_id or not _g01_damage_parent_matches(root,frame):return false
 var commit:Dictionary=witness.commit
 var amount:Variant=commit.get("amount")
 if not (amount is int or amount is float) or not is_finite(float(amount)) or float(amount)<=0.0:return false
 if commit.get("target")!=str(frame.enemy.actor_id) or commit.get("target_hp_after")!=float(frame.enemy.hp):return false
 var before:float=float(commit.get("target_hp_before",-1.0))
 var after:float=float(commit.get("target_hp_after",-1.0))
 var tolerance:float=maxf(0.000000001,absf(before)*0.0000000000000008881784197001252)
 return is_finite(before) and is_finite(after) and before>0.0 and after>=0.0 and absf(before-after-float(amount))<=tolerance

# DRAFT only. Merge into the exact ordinary Sim after all source seams review.
# Existing _fixed_step gets one push/pop around its unchanged original body.
# Existing _c03_begin_release_call additionally captures g01_before from
# _g01_release_before(), before calling super. No callbacks are added.
var _g01_push_bindings: Dictionary={}
var _g01_vortex_bindings:Dictionary={}
func _g01_release_before()->Dictionary:
 var positions:Array=[]
 for enemy:Dictionary in enemies:positions.append({"actor":enemy,"position":Vector3(enemy.position)})
 for ally in allies:
  if is_instance_valid(ally) and not is_same(ally,hero):positions.append({"actor":ally,"position":Vector3(ally.position)})
 positions.append({"actor":hero,"position":Vector3(hero.position)})
 return {"rain":ink_rain,"speed_bonus":float(hero.rain_speed_bonus),"positions":positions,"control":{"stun_left":float(hero.stun_left),"slow_left":float(hero.slow_left),"slow_amount":float(hero.slow_amount),"knockback":Vector3(hero.knockback),"control_frame_left":float(_control_frame_left),"control_motion_blocking":bool(_control_motion_blocking)}}
func _g01_call_frame(kind:String,state:Dictionary={},target:Dictionary={})->Dictionary:
 var owner:RefCounted=_ordinary_passive23_owner.get_ref() if _ordinary_passive23_owner!=null else null
 if not g01_model_is_bound(owner) or phase!="combat" or paused or hero.dead:return {}
 return {"kind":kind,"state":state,"target":target,"hero":hero,"owner":owner,"common":common,"runtime":common.runtime,"run_id":owner._run_id,"generation":encounter_generation,"room_id":room_id,"combat_level_id":combat_level_id,"depth":_c03_notification_depth}
func _g01_call_current(frame:Dictionary)->bool:
 if frame.is_empty() or phase!="combat" or paused or hero.dead or frame.depth!=_c03_notification_depth:return false
 return g01_model_is_bound(frame.owner) and is_same(frame.hero,hero) and is_same(frame.common,common) and is_same(frame.runtime,common.runtime) and frame.run_id==frame.owner._run_id and frame.generation==encounter_generation and frame.room_id==room_id and frame.combat_level_id==combat_level_id
func _g01_release_call_current(frame:Dictionary)->bool:
 if frame.is_empty() or phase!="combat" or paused or hero.dead or frame.notification_depth!=_c03_notification_depth:return false
 return g01_model_is_bound(frame.owner) and is_same(frame.hero,hero) and is_same(frame.common,common) and is_same(frame.runtime,common.runtime) and frame.run_id==frame.owner._run_id and frame.generation==encounter_generation and frame.room_id==room_id and frame.combat_level_id==combat_level_id
func _g01_step_current()->bool:
 return not _g01_step_frames.is_empty() and _g01_call_current(_g01_step_frames.back())
func _g01_source_current(kind:String,state:Dictionary)->Dictionary:
 if _g01_source_calls.is_empty():return {}
 var frame:Dictionary=_g01_source_calls.back()
 if not _g01_call_current(frame) or frame.kind!=kind or not is_same(frame.state,state):return {}
 return frame
func _g01_original_member(rows:Array,value:Dictionary)->bool:
 for row:Dictionary in rows:
  if is_same(row,value):return true
 return false
func _g01_root_for(family:String,state:Dictionary)->Dictionary:
 var root:Dictionary=_g01_roots.get(str(state.get("cast_id",-1)),{})
 return root if not root.is_empty() and root.family==family and is_same(root.state,state) and _g01_root_current(root) else {}
func _settle_motion_interval(before:Dictionary,tick_start:float,tick_end:float)->void:
 var frame:Dictionary=_g01_call_frame("motion_interval") if _g01_step_current() else {}
 _g01_source_calls.append(frame)
 super._settle_motion_interval(before,tick_start,tick_end)
 assert(is_same(_g01_source_calls.back(),frame));_g01_source_calls.pop_back()
func _q2_enhance_projectile(state:Dictionary,river:Dictionary,at:float)->void:
 var frame:Dictionary={}
 if not _g01_source_calls.is_empty() and _g01_call_current(_g01_source_calls.back()) and _g01_source_calls.back().kind=="motion_interval" and _g01_original_member(ink_basics,state) and _g01_original_member(ink_rivers,river):
  frame=_g01_call_frame("q2_enhance",river,state)
  frame.before={"path_length":float(state.path_length),"speed":float(state.speed),"enhanced_once":bool(state.get("q2_enhanced_once",false))}
 _g01_source_calls.append(frame)
 super._q2_enhance_projectile(state,river,at)
 assert(is_same(_g01_source_calls.back(),frame));_g01_source_calls.pop_back()
func _q3_damage_segment(state:Dictionary,segment:String,origin:Vector3,direction:Vector3,length:float,width:float,amount:float,collapse:bool)->void:
 var frame:Dictionary={}
 var root:Dictionary=_g01_root_for("q3",state)
 if not root.is_empty() and not _c03_release_calls.is_empty():
  var caller:Dictionary=_c03_release_calls.back()
  if _g01_release_call_current(caller) and caller.action=="q" and caller.cast_id==root.cast_id:
   # Original collapse retires collision ownership BEFORE this segment. Its
   # retained exact released state remains the same valid root, never a copy.
   if (collapse and segment=="mountain_collapse" and bool(state.get("retired",false))) or (not collapse and segment=="mountain_raise_burst" and is_same(ink_mountain,state)):
    frame=_g01_call_frame("q3_segment",state)
 _g01_source_calls.append(frame)
 super._q3_damage_segment(state,segment,origin,direction,length,width,amount,collapse)
 assert(is_same(_g01_source_calls.back(),frame));_g01_source_calls.pop_back()
func _e1_mark_contact(state:Dictionary,enemy:Dictionary,origin:Vector3,destination:Vector3,fraction:float,at:float,mover:String)->void:
 var frame:Dictionary={}
 if _g01_step_current() and is_same(ink_rain,state) and not _g01_root_for("e1",state).is_empty() and _g02_target_current(enemy):
  frame=_g01_call_frame("e1_mark",state,enemy);frame.absent_before=not state.marks.has(str(enemy.actor_id));frame.receipts_before=ink_e1_marks.size()
 _g01_source_calls.append(frame)
 super._e1_mark_contact(state,enemy,origin,destination,fraction,at,mover)
 assert(is_same(_g01_source_calls.back(),frame));_g01_source_calls.pop_back()
func _e2_board(state:Dictionary,context:Dictionary)->Dictionary:
 var frame:Dictionary={}
 if not _c03_release_calls.is_empty() and _g01_release_call_current(_c03_release_calls.back()) and _c03_release_calls.back().cast_id==int(state.get("cast_id",-1)) and is_same(ink_boat,state):
  frame=_g01_call_frame("e2_board",state);frame.from=Vector3(hero.position);frame.context=context
 _g01_source_calls.append(frame)
 var result:Dictionary=super._e2_board(state,context)
 assert(is_same(_g01_source_calls.back(),frame));_g01_source_calls.pop_back()
 return result
func _equipment_push_bound(family:String,source_state:Dictionary,enemy:Dictionary,before_push:Dictionary,committed_push:Dictionary)->void:
 var root:Dictionary=_g01_root_for(family,source_state)
 if root.is_empty() or _g01_source_calls.is_empty() or not _g02_target_current(enemy):return
 var frame:Dictionary=_g01_source_calls.back()
 if not _g01_call_current(frame):return
 if family=="q1":
  if frame.kind!="motion_interval" or not _g01_original_member(ink_waves,source_state):return
 elif family=="q3":
  if frame.kind!="q3_segment" or not is_same(frame.state,source_state):return
 else:return
 if committed_push.is_empty() or is_same(before_push,committed_push) or not is_same(enemy.push,committed_push) or committed_push.get("source")!=family or int(committed_push.get("cast_id",-1))!=root.cast_id:return
 _g01_push_bindings[str(enemy.actor_id)]={"enemy":enemy,"push":committed_push,"root":root}
func _step_push(enemy:Dictionary,dt:float)->void:
 var frame:Dictionary={}
 if _g01_step_current() and _g02_target_current(enemy):
  frame=_g01_call_frame("source_push",enemy.push,enemy);frame.from=Vector3(enemy.position)
 _g01_source_calls.append(frame)
 super._step_push(enemy,dt)
 assert(is_same(_g01_source_calls.back(),frame));_g01_source_calls.pop_back()
func _equipment_h02_vortex_bound(wave:Dictionary,vortex:Dictionary)->void:
 var root:Dictionary=_g01_root_for("q1",wave)
 if root.is_empty() or not _g01_step_current() or not verify_g01_h02_binding(wave,vortex):return
 _g01_vortex_bindings[str(vortex.vortex_id)]={"vortex":vortex,"root":root}
func _equipment_effect_committed(family:String,state:Dictionary,kind:String,commit:Dictionary)->void:
 var root:Dictionary={}
 if kind=="q1_h02_pull":
  var bound:Dictionary=_g01_vortex_bindings.get(str(state.get("vortex_id","")),{})
  if not bound.is_empty() and is_same(bound.vortex,state):root=bound.root
 elif kind=="source_push_moved":
  var frame:Dictionary=_g01_source_current("source_push",state)
  if not frame.is_empty():
   var bound:Dictionary=_g01_push_bindings.get(str(frame.target.actor_id),{})
   if not bound.is_empty() and is_same(bound.push,state):root=bound.root
 else:root=_g01_root_for(family,state)
 if root.is_empty() or family!=root.family:return
 _g01_submit_effect(root,kind,commit,_c03_notification_depth)

func _g01_effect_shape(kind:String,proof:Dictionary)->bool:
 var dictionaries:Array=[]
 match kind:
  "q1_h02_pull":dictionaries=["vortex","enemy"]
  "source_push_moved":dictionaries=["enemy","push"]
  "q2_projectile_enhanced":dictionaries=["projectile","before","after"]
  "e1_buff_granted","e1_control_cleansed":dictionaries=["before","after"]
  "e1_rain_marked":dictionaries=["enemy","mark","receipt"]
  "e2_boarded":dictionaries=["context"]
  "e3_exchanged":return proof.get("members") is Array
  "q3_h06_stun","q3_movement_blocked","q3_projectile_erased":return true # Source verifier requires exact private commit identity.
  _:return false
 for key:String in dictionaries:
  if not proof.get(key) is Dictionary:return false
 if kind in ["source_push_moved","e2_boarded"]:
  if not proof.get("from") is Vector3 or not proof.get("to") is Vector3:return false
 if kind=="q2_projectile_enhanced":
  for key:String in ["path_length","speed"]:
   if not (proof.before.get(key) is int or proof.before.get(key) is float) or not (proof.after.get(key) is int or proof.after.get(key) is float):return false
  if not proof.before.get("enhanced_once") is bool:return false
 if kind=="e1_buff_granted":
  if not proof.before.get("form") is Dictionary or not proof.after.get("form") is Dictionary:return false
  for key:String in ["speed_bonus","damage_reduction"]:
   if not (proof.after.get(key) is int or proof.after.get(key) is float):return false
 if kind=="e1_control_cleansed":
  for key:String in ["stun_left","slow_left","slow_amount","control_frame_left"]:
   if not (proof.before.get(key) is int or proof.before.get(key) is float) or not (proof.after.get(key) is int or proof.after.get(key) is float):return false
  if not proof.before.get("knockback") is Vector3 or not proof.after.get("knockback") is Vector3:return false
  if not proof.before.get("control_motion_blocking") is bool or not proof.after.get("control_motion_blocking") is bool:return false
 return true

func _g01_effect_proof_current(root:Dictionary,kind:String,commit:Dictionary)->bool:
 if not _g01_root_current(root) or commit.is_empty():return false
 if kind=="original_skill_damage":return _g01_damage_proof_current(root,commit)
 var families:Dictionary={"q1_h02_pull":"q1","q2_projectile_enhanced":"q2","e1_buff_granted":"e1","e1_control_cleansed":"e1","e1_rain_marked":"e1","e2_boarded":"e2","e3_exchanged":"e3","q3_h06_stun":"q3","q3_movement_blocked":"q3","q3_projectile_erased":"q3"}
 if kind=="source_push_moved":
  if root.family not in ["q1","q3"]:return false
 elif families.get(kind,"")!=root.family:return false
 if not _g01_effect_shape(kind,commit):return false
 var family:String=root.family
 var state:Dictionary=root.state
 if kind=="q1_h02_pull":state=commit.vortex
 elif kind=="source_push_moved":state=commit.push
 if kind=="q1_h02_pull":
  var binding:Dictionary=_g01_vortex_bindings.get(str(state.get("vortex_id","")),{})
  if binding.is_empty() or family!="q1" or not _g01_step_current() or not is_same(binding.vortex,state) or not verify_g01_h02_pull(state,commit):return false
  return is_same(binding.root,root)
 if kind=="source_push_moved":
  var frame:Dictionary=_g01_source_current("source_push",state)
  if frame.is_empty():return false
  var bound:Dictionary=_g01_push_bindings.get(str(frame.target.actor_id),{})
  if bound.is_empty() or not is_same(bound.enemy,frame.target) or not is_same(bound.push,state) or not is_same(commit.get("enemy"),frame.target) or not is_same(commit.get("push"),state):return false
  if commit.get("from")!=frame.from or commit.get("to")!=frame.target.position or not Vector3(commit.to).is_finite() or Vector3(commit.to).distance_squared_to(frame.from)<=0.0:return false
  return is_same(bound.root,root)
 if not is_same(_g01_root_for(family,state),root):return false
 match kind:
  "q2_projectile_enhanced":
   var frame:Dictionary=_g01_source_current("q2_enhance",state)
   if frame.is_empty() or not is_same(commit.get("projectile"),frame.target) or commit.get("before")!=frame.before or frame.before.enhanced_once:return false
   var projectile:Dictionary=frame.target
   if not projectile.get("q2_enhanced_once",false) or not _g01_original_member(ink_basics,projectile):return false
   if commit.after.path_length!=projectile.path_length or commit.after.speed!=projectile.speed:return false
   if not is_finite(float(projectile.path_length)) or not is_finite(float(projectile.speed)) or not (float(projectile.path_length)>frame.before.path_length or float(projectile.speed)>frame.before.speed):return false
   return true
  "e1_buff_granted","e1_control_cleansed","e3_exchanged":
   if _c03_release_calls.is_empty():return false
   var frame:Dictionary=_c03_release_calls.back()
   if not _g01_release_call_current(frame) or not frame.seen or frame.cast_id!=root.cast_id or not is_same(frame.hero,root.hero):return false
   if kind=="e1_buff_granted":
    if not is_same(ink_rain,state) or not is_same(commit.get("owner"),hero) or not is_same(commit.before.form,frame.g01_before.rain) or is_same(frame.g01_before.rain,state):return false
    if not is_same(commit.after.form,state) or commit.after.speed_bonus!=hero.rain_speed_bonus or commit.after.damage_reduction!=state.damage_reduction:return false
    if not (float(state.speed_bonus)>0.0 or float(state.damage_reduction)>0.0) or float(state.expires_at)<=hero_time:return false
   elif kind=="e1_control_cleansed":
    # Positive formal buff already qualifies this same E1 root. Cleansing is
    # retained as a separate reviewed witness, never used to double count.
    if not state.h07_at_entry or not commit.get("h07_at_entry",false):return false
    var before:Dictionary=commit.before;var after:Dictionary=commit.after
    for key:String in frame.g01_before.control:
     if before.get(key)!=frame.g01_before.control[key]:return false
    if not (float(before.stun_left)>0.0 or float(before.slow_left)>0.0 or Vector3(before.knockback)!=Vector3.ZERO or float(before.control_frame_left)>0.0 or before.control_motion_blocking):return false
    if float(after.stun_left)!=0.0 or float(after.slow_left)!=0.0 or float(after.slow_amount)!=0.0 or Vector3(after.knockback)!=Vector3.ZERO or float(after.control_frame_left)!=0.0 or after.control_motion_blocking:return false
    if hero.stun_left!=0.0 or hero.slow_left!=0.0 or hero.knockback!=Vector3.ZERO or _control_motion_blocking:return false
   else:
    if not is_same(frame.get("exchange_state"),state) or not is_same(commit.get("members"),state.members):return false
    var moved:bool=false
    for member:Dictionary in state.members:
     var original:bool=false
     for saved:Dictionary in frame.g01_before.positions:
      if is_same(saved.actor,member.actor) and saved.position==member.from:original=true;break
     if not original or member.actor.position!=member.to or not Vector3(member.to).is_finite():return false
     if member.team!="enemy" and not state.h11:return false
     moved=moved or Vector3(member.to).distance_squared_to(member.from)>0.0
    if not moved:return false
   return true
  "e1_rain_marked":
   var frame:Dictionary=_g01_source_current("e1_mark",state)
   if frame.is_empty() or not frame.absent_before or not is_same(commit.get("enemy"),frame.target):return false
   var id:String=str(frame.target.actor_id)
   if not state.marks.has(id) or not is_same(commit.get("mark"),state.marks[id]) or int(state.marks[id].count)<=0 or ink_e1_marks.size()!=frame.receipts_before+1 or not is_same(ink_e1_marks.back(),commit.get("receipt")):return false
   return true
  "e2_boarded":
   var frame:Dictionary=_g01_source_current("e2_board",state)
   if frame.is_empty() or not is_same(commit.get("owner"),hero) or not is_same(commit.get("context"),frame.context):return false
   if commit.get("from")!=frame.from or commit.get("to")!=hero.position or state.boarding_position!=hero.position or not hero.position.is_finite() or hero.position.distance_squared_to(frame.from)<=0.0:return false
   return true
  "q3_h06_stun":
   var frame:Dictionary=_g01_source_current("q3_segment",state)
   if frame.is_empty() or not verify_g01_h06_stun(state,commit):return false
   return true
  "q3_movement_blocked":
   if not _g01_step_current() or not verify_g01_q3_movement(state,commit):return false
   return true
  "q3_projectile_erased":
   if not _g01_step_current() or not enemy_director.has_method("verify_g01_projectile_erase") or not enemy_director.verify_g01_projectile_erase(self,state,commit):return false
   return true
 return false
# Q3 movement proof comes only from the exact source-owned double-LIFO
# implementation. FULL_EFFECTS_READY remains false until complete source review.

# New base stats are projected only after the original ledger commit and at the
# original consumer's legal non-transaction boundary. No packet snapshot edits.
var _g01_projection_pending:Dictionary={}
func _g01_queue_projection(root:Dictionary)->void:
 if not g01_model_is_bound(root.owner):return
 _g01_projection_pending={"owner":root.owner,"hero":root.hero,"common":root.common,"runtime":root.runtime,"run_id":root.run_id}
 _g01_flush_projection()
func _g01_pending_projection_current()->bool:
 var pending:Dictionary=_g01_projection_pending
 return not pending.is_empty() and g01_model_is_bound(pending.owner) and pending.run_id==pending.owner._run_id and is_same(pending.hero,hero) and is_same(pending.common,common) and is_same(pending.runtime,common.runtime)
func _g01_flush_projection()->void:
 if _g01_projection_pending.is_empty():return
 if not _g01_pending_projection_current():_g01_projection_pending={};return
 if transaction_active or _ordinary_passive23_syncing:return
 refresh_passive23()
func _g01_projection_synced(owner:RefCounted)->void:
 # Called only after the existing sync_stats body completes successfully.
 if _g01_pending_projection_current() and is_same(_g01_projection_pending.owner,owner):_g01_projection_pending={}
func request_action(action:String,aim:Vector3=Vector3.INF,command_id:String="")->Dictionary:
 var result:Dictionary=super.request_action(action,aim,command_id)
 _g01_flush_projection()
 return result
