extends "res://tests/ink_e1_ordinary_20261005/candidate01/sim.gd"
## Isolated base-R1 mechanism leaf. No ordinary host, capability, input or UI promotion.
## One inherited actor, shared fixed step, reward authority and cooldown service.
const SnowTuning = preload("res://tests/ink_r1_ordinary_20261005/candidate01/tuning.gd")
const SnowDirector = preload("res://tests/ink_r1_ordinary_20261005/candidate01/enemy_director.gd")
var ink_snow: Dictionary = {}
var ink_r1_finished: Array = []
var _r1_serial: int = 0
var _r1_step_start: float = 0.0
var _r1_step_active: bool = false

func _init() -> void:
 super._init()
 # Constructor only. This includes the retained Q3 collision/navigation chain.
 enemy_director = SnowDirector.new()

func _r1_current(state: Dictionary) -> bool:
 return source_rules_hash == EXPECTED_RULES_HASH and not state.is_empty() and not bool(state.get("retired",true)) and effect_is_current(state) and is_same(hero,state.owner) and not hero.dead

func r1_preview(point: Vector3) -> Dictionary:
 if hero.loadout.r != "r1" or int(hero.ranks.r) <= 0:
  return {"accepted":false,"reason":"r1_unlearned","preview_only":true}
 var values: Dictionary = SnowTuning.values(int(hero.ranks.r))
 if values.is_empty(): return {"accepted":false,"reason":"invalid_r1_rank","preview_only":true}
 if not point.is_finite(): return {"accepted":false,"reason":"manual_aim_required","preview_only":true}
 var position: Vector3 = Geometry.ground(point)
 if Geometry.ground(position-hero.position).length() > float(values.placement_range):
  return {"accepted":false,"reason":"outside_placement_range","preview_only":true}
 return {"accepted":true,"reason":"","preview_only":true,"position":position,"placement_range":values.placement_range,"radius":values.radius,"duration":values.duration,"rank":values.rank}

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action != "r" or hero.loadout.r != "r1": return super._hero_action_policy(action,aim)
 if source_rules_hash != EXPECTED_RULES_HASH: return {"reason":"source_binding_mismatch"}
 if _e1_form_current(): return {"reason":"rain_form_forbids_action"}
 if _ink_action_controlled("r"): return {"reason":"controlled"}
 if not ink_snow.is_empty(): return {"reason":"snow_domain_already_active"}
 var preview: Dictionary = r1_preview(aim)
 if not preview.accepted: return {"reason":preview.reason}
 return {"stage":"snow_domain"}

func _hero_cast_skill(action: String, context: Dictionary) -> Dictionary:
 if action != "r" or hero.loadout.r != "r1": return super._hero_cast_skill(action,context)
 if not effect_is_current(context): return {"accepted":false,"reason":"stale_cast"}
 var preview: Dictionary = r1_preview(hero.aim_point)
 if not preview.accepted: return {"accepted":false,"reason":preview.reason}
 var values: Dictionary = SnowTuning.values(int(hero.ranks.r))
 _r1_serial += 1
 var state: Dictionary = context.duplicate(true)
 state.merge({"owner":hero,"context":context.duplicate(true),"domain_id":"%d:%s:snow:%d" % [encounter_generation,room_id,_r1_serial],"rank":values.rank,"position":preview.position,"radius":values.radius,"born_at":hero_time,"expires_at":hero_time+float(values.duration),"normal_reduction":values.ordinary_reduction,"elite_reduction":values.elite_reduction,"boss_reduction":values.boss_reduction,"retired":false},true)
 ink_snow = state
 # Successful field creation starts CD once, using the existing CDR service.
 # Never use start_presentation: it grants unrelated immunity/global slowdown.
 start_skill_cooldown("r",float(values.cooldown))
 emit_event("ink_r1_created",_r1_public(state))
 return {"accepted":true,"phase":"snow_domain","domain_id":state.domain_id,"cancelled_during_callback":not _r1_current(state)}

func _r1_rates(enemy: Dictionary, portion: float) -> Dictionary:
 var out: Dictionary = {"in_domain":false,"reduction":0.0,"move_rate":1.0,"attack_rate":1.0,"domain_id":"","active_portion":0.0}
 var state: Dictionary = ink_snow
 if portion <= 0.0 or not _r1_current(state) or enemy.is_empty() or bool(enemy.get("dead",true)) or enemy.get("state","") == "spawn": return out
 if not is_same(enemy,enemy_by_id(str(enemy.get("actor_id","")))): return out
 if int(enemy.get("generation",-1)) != encounter_generation or str(enemy.get("room_id","")) != room_id: return out
 if not Vector3(enemy.position).is_finite(): return out
 var center: Vector3 = Geometry.ground(enemy.position)
 var body_radius: float = float(enemy.get("radius",0.0))
 if not is_finite(body_radius) or body_radius < 0.0: return out
 # Same body-overlap boundary as existing circle_targets, on the ground plane.
 if center.distance_to(Vector3(state.position)) > float(state.radius)+body_radius: return out
 var reduction: float = 0.0
 match str(enemy.get("rank_category","")):
  "ordinary": reduction = float(state.normal_reduction)
  "elite": reduction = float(state.elite_reduction)
  "boss": reduction = float(state.boss_reduction)
  _: return out
 var rate: float = 1.0-reduction*portion
 out.merge({"in_domain":true,"reduction":reduction,"move_rate":rate,"attack_rate":rate,"domain_id":state.domain_id,"active_portion":portion},true)
 return out

func r1_enemy_rates(enemy: Dictionary) -> Dictionary:
 var active: bool = _r1_current(ink_snow) and hero_time < float(ink_snow.expires_at)
 return _r1_rates(enemy,1.0 if active else 0.0)

func r1_step_enemy_rates(enemy: Dictionary, dt: float) -> Dictionary:
 if not _r1_step_active or dt <= 0.0: return r1_enemy_rates(enemy)
 if not _r1_current(ink_snow): return _r1_rates(enemy,0.0)
 # Account for the final partial lifetime inside this already admitted step.
 # Geometry is sampled at this enemy phase; no world clock is rewound/replayed.
 var interval: float = maxf(0.0,hero_time-_r1_step_start)
 if interval <= 0.0: return r1_enemy_rates(enemy)
 var active: float = maxf(0.0,minf(hero_time,float(ink_snow.expires_at))-maxf(_r1_step_start,float(ink_snow.born_at)))
 return _r1_rates(enemy,clampf(active/interval,0.0,1.0))

func _fixed_step(real_dt: float) -> void:
 var scope: Dictionary = _ink_scope()
 _r1_step_start = hero_time; _r1_step_active = true
 super._fixed_step(real_dt) # Exactly one existing core step; Q2 retains its own remainder.
 _r1_step_active = false
 if not _ink_scope_current(scope) or paused or not _r1_current(ink_snow): return
 if hero_time >= float(ink_snow.expires_at)-TIME_EPS: _r1_finish_naturally()

func _r1_finish_naturally() -> void:
 var state: Dictionary = ink_snow
 if not _r1_current(state): return
 ink_snow = {}; state.retired = true
 var receipt: Dictionary = _r1_public(state)
 receipt.merge({"reason":"natural_expiry","finished_at":state.expires_at},true)
 ink_r1_finished.append(receipt)
 if ink_r1_finished.size() > 32: ink_r1_finished.pop_front()
 finish_cast(int(state.cast_id))
 if effect_is_current(state) and not hero.dead: emit_event("ink_r1_finished",receipt)

func cancel_cast(id: int) -> void:
 if not ink_snow.is_empty() and int(ink_snow.cast_id) == id:
  ink_snow.retired = true; ink_snow = {}
 super.cancel_cast(id)

func _hero_clear_transients() -> void:
 if not ink_snow.is_empty(): ink_snow.retired = true
 ink_snow = {}; _r1_step_active = false
 # Core does not reset skill cooldowns on end/begin encounter. Keep that rule.
 super._hero_clear_transients()

func _hero_hex_status(id: String) -> Dictionary:
 if id in ["yanguizhou_h13","yanguizhou_h14","yanguizhou_h15","yanguizhou_h16"]:
  return {"active":false,"reason":"r_hex_not_implemented"}
 return super._hero_hex_status(id)

func _r1_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = {}
 for field: String in ["domain_id","cast_id","generation","room_id","rank","position","radius","born_at","expires_at","normal_reduction","elite_reduction","boss_reduction"]: out[field] = state[field]
 out["remaining"] = maxf(0.0,float(state.expires_at)-hero_time)
 return out

func ink_presenter_snapshot() -> Dictionary:
 var out: Dictionary = super.ink_presenter_snapshot()
 out["r1_schema"] = "ink-r1-isolated-core-1"
 out["snow"] = _r1_public(ink_snow) if _r1_current(ink_snow) else {}
 out["r1_finished"] = ink_r1_finished.duplicate(true)
 return out

func _hero_snapshot() -> Dictionary:
 var out: Dictionary = super._hero_snapshot()
 out["r1_core_candidate"] = {"ordinary_entry_ready":false,"runtime_validation":"NOT_RUN","H13_H16_available":false,"native_input":false,"art_audio_accepted":false}
 return out
