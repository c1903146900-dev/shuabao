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
