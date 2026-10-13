extends "res://tests/ink_river_hexes_20261006/ownership01/sim.gd"

# Reviewed Boss composition: install only in construction, before Session admission.
const OrdinaryFirstFloorBossDirector = preload("res://tests/ink_first_floor_boss_20261008/source01/enemy_director.gd")
func _init() -> void:
 super._init()
 enemy_director = OrdinaryFirstFloorBossDirector.new()
func _kill_enemy(enemy: Dictionary, source: String, cast_id: int) -> void:
 if not enemy.dead and enemy.kind == "boss" and enemy_director.has_method("cancel_boss_casts"):
  enemy_director.boss_controller.cancel(self,enemy,"owner_died")
 super._kill_enemy(enemy,source,cast_id)

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
