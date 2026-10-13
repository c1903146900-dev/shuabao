extends RefCounted
const SweptRectangle=preload("res://scripts/combat/swept_rectangle_geometry.gd")
## Shared source-authoritative common-Hex event runtime. See docs/common_hex_runtime.md.
## This module never owns skill points, gold, equipment rewards or campaign progress.
const Design = preload("res://data/final_design/catalog.gd")
const EPS = 0.000001
const OWNED_MODEL_HEXES = ["common_g17", "common_g20", "common_g21", "common_g27"]
var selected: Array = []
var _active_ids: Dictionary = {}
var _base_values: Dictionary = {}
var options: Dictionary = {}
var rng = RandomNumberGenerator.new()
var combat = false
var room_id = ""
var run_id = ""
var generation = -1
var time = 0.0 # World combat clock: projectiles, world entities and replay timelines.
var actor_time = 0.0 # Owner combat clock: buffs, proc ICDs and terminal health debt.
var _tick_prepared = false
var form = ""
var growth = 0
var growth_kills = 0
var cooldown_kills = 0
var cooldown_bonus = 0.0
var cooldown_groups = 0
var cooldown_elites = 0
var cooldown_bosses = 0
var soul_kills = 0
var replay_kills = 0
var replay_charges = 0
var long_range_hits = 0
var rescue_energy = 0.0
var dash_stacks = 0
var dash_until = 0.0
var final_until = 0.0
var soul_speed_until = 0.0
var boss_until = 0.0
var next_soul = 0.0
var next_bombardment = 0.0
var next_rescue = 0.0
var next_turret = 0.0
var actions: Dictionary = {}
var completed_actions: Dictionary = {}
var souls: Array = []
var projectiles: Array = []
var turrets: Array = []
var scheduled: Array = []
# Only explicitly source-capped replay families use this ledger. Its lifetime is
# the pending slices of one full cast, never the whole run or an arbitrary skill.
var _replay_hit_ledger: Dictionary = {}
var debt: Array = [] # deliberately survives room/generation changes
var shrink: Dictionary = {}
var shield_break_cooldowns: Dictionary = {}
var executed: Dictionary = {}
var seen_deaths: Dictionary = {}
var seen_rooms: Dictionary = {}
var _events: Array = []
var _serial = 0
var _next_chain = 0
var _entity_serial = 0
var chain_counts: Dictionary = {}

func _init() -> void:
 rng.seed = 20261002

func configure(ids: Array, settings: Dictionary = {}) -> void:
 selected.clear()
 _active_ids.clear()
 _base_values.clear()
 options = settings.duplicate(true)
 for candidate in ids:
  var id = _id(str(candidate))
  var definition: Dictionary = Design.hex_definition(id)
  if definition.is_empty() or id in selected: continue
  selected.append(id)
  _active_ids[id] = not definition.get("proposal", false) or id in options.get("approved_proposals", Design.approved_proposals())
  for token in definition.get("parameters", {}): _base_values[id + ":" + token] = Design.hex_parameter(id,token)
 if settings.has("seed"): rng.seed = int(settings.seed)

func active(id: String) -> bool:
 return bool(_active_ids.get(_id(id), false))

func _entity_id(kind: String) -> String:
 _entity_serial+=1
 return "%s|%s|%s|%s|%d"%[run_id,room_id,generation,kind,_entity_serial]

func _id(id: String) -> String:
 return id.to_lower() if id.begins_with("common_") else "common_" + id.to_lower()

func parameter(id: String, index: int) -> float:
 var canonical = _id(id)
 var token = canonical.trim_prefix("common_").to_upper() + "-" + str(index)
 var original = float(_base_values.get(canonical + ":" + token, 0.0))
 if not _base_values.has(canonical + ":" + token):
  original = Design.hex_parameter(canonical, token)
  _base_values[canonical + ":" + token] = original
 # Scaling comes from the model-owned G20 field whitelist, never from arbitrary token math.
 var resolver: Callable = options.get("parameter_value", Callable())
 return float(resolver.call(canonical, token, original)) if resolver.is_valid() else original

func _f(id: String, index: int) -> float:
 return parameter(id, index) / 100.0

func drain_events() -> Array:
 var result = _events
 _events = []
 return result

func _emit(kind: String, data: Dictionary = {}) -> void:
 _serial += 1
 var event = data.duplicate(true)
 event.merge({"kind":kind, "event_id":"common:%d" % _serial, "room_id":room_id, "generation":generation, "run_id":run_id, "cast_id":0, "source":"common_runtime", "hex_generated":true}, false)
 _events.append(event)

func _hero(ctx: Dictionary) -> Dictionary:
 return ctx.get("hero", {})

func _stats(ctx: Dictionary) -> Dictionary:
 var hero = _hero(ctx)
 return hero.get("stats", hero)

func _stat(ctx: Dictionary, key: String, fallback: float = 0.0) -> float:
 return float(_stats(ctx).get(key, fallback))

func _position(actor: Dictionary) -> Vector3:
 return actor.get("position", Vector3.ZERO)

func _ordinary(actor: Dictionary) -> bool:
 return str(actor.get("rank_category", actor.get("kind", "ordinary"))) not in ["elite", "boss"]

func _alive(actor: Dictionary) -> bool:
 return not actor.is_empty() and not actor.get("dead", false) and float(actor.get("hp", 1.0)) > 0

func _enemies(ctx: Dictionary) -> Array:
 return ctx.get("enemies", []).filter(func(actor): return _alive(actor) and not executed.has(str(actor.get("actor_id", ""))))

func _allies(ctx: Dictionary) -> Array:
 var result: Array = []
 if _alive(_hero(ctx)): result.append(_hero(ctx))
 for actor in ctx.get("allies", []):
  if _alive(actor) and str(actor.get("actor_id", "")) != str(_hero(ctx).get("actor_id", "")): result.append(actor)
 return result

func _actor(ctx: Dictionary, actor_id: String, friendly: bool = false) -> Dictionary:
 for actor in _allies(ctx) if friendly else _enemies(ctx):
  if str(actor.get("actor_id", "")) == actor_id: return actor
 return {}

func _near(actors: Array, at: Vector3, radius: float) -> Array:
 return actors.filter(func(actor): return _position(actor).distance_to(at) <= radius + EPS)

func _nearest(actors: Array, at: Vector3, radius: float) -> Array:
 var result = _near(actors, at, radius)
 result.sort_custom(func(a, b):
  var da = _position(a).distance_squared_to(at)
  var db = _position(b).distance_squared_to(at)
  return str(a.get("actor_id", "")) < str(b.get("actor_id", "")) if is_equal_approx(da, db) else da < db)
 return result

func _amount(ctx: Dictionary, id: String, flat: int, ad_index: int, ap_index: int) -> float:
 return parameter(id, flat) + _f(id, ad_index) * _stat(ctx, "ad") + _f(id, ap_index) * _stat(ctx, "ap")

func _reset_nonultimate(source: String) -> void:
 _emit("reset_cooldowns", {"source":source, "slots":["q", "e"], "learned_only":true})

func begin_room(ctx: Dictionary) -> void:
 var incoming_run = str(ctx.get("run_id", run_id))
 if not run_id.is_empty() and incoming_run != run_id: reset_run()
 run_id = incoming_run
 var next_room = str(ctx.get("room_id", ""))
 var next_generation = int(ctx.get("generation", 0))
 if combat and next_room == room_id and next_generation == generation: return
 room_id = next_room
 generation = next_generation
 combat = true
 _tick_prepared = false
 # Targets/projectiles/segments belong to precisely one enemy collection.
 actions.clear()
 completed_actions.clear()
 projectiles.clear()
 souls.clear()
 turrets.clear()
 scheduled.clear()
 _replay_hit_ledger.clear()
 shrink.clear()
 executed.clear()
 seen_deaths.clear()
 chain_counts.clear()
 _events.clear()
 # Distinguish an authored room from a wave/generation within that same room.
 if not seen_rooms.has(room_id):
  seen_rooms[room_id] = true
  form = "giant" if active("g03") and rng.randf() < _f("g03", 1) else "tiny" if active("g03") else ""
 if active("g19") and str(ctx.get("encounter_kind", "ordinary")) in ["elite", "boss"]:
  boss_until = actor_time + parameter("g19", 3)
  _reset_nonultimate("common_g19")
 _emit("room_ready", {"form":form})

func reset_run() -> void:
 end_room()
 run_id = ""
 room_id = ""
 generation = -1
 time = 0.0
 actor_time = 0.0
 _tick_prepared = false
 form = ""
 growth = 0
 growth_kills = 0
 cooldown_kills = 0
 cooldown_bonus = 0.0
 cooldown_groups = 0
 cooldown_elites = 0
 cooldown_bosses = 0
 soul_kills = 0
 replay_kills = 0
 replay_charges = 0
 long_range_hits = 0
 rescue_energy = 0.0
 dash_stacks = 0
 dash_until = 0.0
 final_until = 0.0
 soul_speed_until = 0.0
 boss_until = 0.0
 next_soul = 0.0
 next_bombardment = 0.0
 next_rescue = 0.0
 next_turret = 0.0
 debt.clear()
 shrink.clear()
 shield_break_cooldowns.clear()
 seen_rooms.clear()
 seen_deaths.clear()
 executed.clear()
 completed_actions.clear()
 chain_counts.clear()
 _events.clear()

func end_room() -> void:
 combat = false
 _tick_prepared = false
 # Debt and timed buffs freeze; target-bound work can never leak to replacement enemies.
 projectiles.clear()
 souls.clear()
 turrets.clear()
 scheduled.clear()
 _replay_hit_ledger.clear()
 actions.clear()

func project_stats(base: Dictionary, ctx: Dictionary) -> Dictionary:
 var result = base.duplicate(true)
 var hp_factor = 1.0
 var ad_factor = 1.0
 var ap_factor = 1.0
 var speed_factor = 1.0
 var model_factor = 1.0
 var damage_factor = 1.0
 if active("g02") and bool(ctx.get("ranged", false)):
  result.attack_range = parameter("g02", 1)
  ad_factor += _f("g02", 2)
  hp_factor += _f("g02", 3)
  result.attack_speed = float(base.get("attack_speed", 1.0)) * (1.0 + _f("g02", 4))
  result.lifesteal = float(result.get("lifesteal", 0.0)) + _f("g02", 5)
 if active("g03"):
  if form == "giant":
   model_factor *= parameter("g03", 2)
   hp_factor += _f("g03", 3)
   damage_factor *= 1.0 + _f("g03", 4)
  elif form == "tiny":
   model_factor *= parameter("g03", 5)
   speed_factor += _f("g03", 6)
   result.cdr = float(result.get("cdr", 0.0)) + _f("g03", 7)
 if active("g04"):
  hp_factor += growth * _f("g04", 2)
  model_factor *= 1.0 + growth * _f("g04", 3)
 if active("g05"):
  cooldown_bonus = cooldown_groups * _f("g05", 3) + cooldown_elites * _f("g05", 4) + cooldown_bosses * _f("g05", 5)
  result.cdr = float(result.get("cdr", 0.0)) + _f("g05", 1) + cooldown_bonus
 if active("g07") and actor_time < dash_until:
  result.defence = float(result.get("defence", 0.0)) + dash_stacks * parameter("g07", 2)
  result.tenacity = float(result.get("tenacity", 0.0)) + dash_stacks * _f("g07", 3)
 if active("g09") and actor_time < final_until:
  result.lifesteal = float(result.get("lifesteal", 0.0)) + _f("g09", 2)
  speed_factor += _f("g09", 3)
 if active("g10") and actor_time < soul_speed_until: speed_factor += _f("g10", 3)
 if active("g19") and actor_time < boss_until:
  ad_factor += _f("g19", 1)
  ap_factor += _f("g19", 2)
 var living = _enemies(ctx)
 if active("g22"):
  if living.size() >= int(parameter("g22", 1)):
   result.lifesteal = float(result.get("lifesteal", 0.0)) + _f("g22", 3)
  elif living.size() == 1 and not _ordinary(living[0]):
   result.penetration = float(result.get("penetration", 0.0)) + parameter("g22", 5)
 if active("g24"):
  var empty = clampi(int(ctx.get("empty_slots", 0)), 0, int(parameter("g24", 3)))
  hp_factor += empty * _f("g24", 2)
  damage_factor *= 1.0 + empty * _f("g24", 1)
 var gold_hp = 0.0
 if active("g30"):
  var units = floorf(clampf(float(ctx.get("gold", 0)), 0.0, parameter("g30", 4)) / parameter("g30", 1))
  result.defence = float(result.get("defence", 0.0)) + units * parameter("g30", 2)
  gold_hp = units * parameter("g30", 3)
 result.cdr = clampf(float(result.get("cdr", 0.0)), 0.0, float(ctx.get("cdr_cap", 0.65)))
 if active("g15"): speed_factor += result.cdr / _f("g15", 1) * _f("g15", 2)
 result.max_hp = (float(base.get("max_hp", 1.0)) + gold_hp) * hp_factor
 result.ad = float(base.get("ad", 0.0)) * ad_factor
 result.ap = float(base.get("ap", 0.0)) * ap_factor
 result.move_speed = float(base.get("move_speed", 0.0)) * speed_factor
 result.model_scale = float(base.get("model_scale", 1.0)) * model_factor
 result.common_damage_multiplier = damage_factor
 result.attack_speed = minf(float(result.get("attack_speed", 1.0)), float(ctx.get("attack_speed_cap", 2.5)))
 result.tenacity = clampf(float(result.get("tenacity", 0.0)), 0.0, float(ctx.get("tenacity_cap", 1.0)))
 return result

func skill_cooldown(base: float, action: Dictionary) -> float:
 if active("g08") and _nonultimate(action) and action.get("active_movement", false):
  return base * (1.0 - _f("g08", 1))
 return base

func _nonultimate(action: Dictionary) -> bool:
 return bool(action.get("active_skill", false)) and not action.get("ultimate", false) and str(action.get("slot", "")) != "shift"

func _action_key(action: Dictionary) -> String:
 return str(action.get("root_action_id", action.get("action_id", action.get("cast_id", ""))))

func action_start(action: Dictionary, ctx: Dictionary) -> void:
 if not combat or action.get("hex_generated", false) or action.get("replay", false): return
 var key = _action_key(action)
 if key.is_empty() or actions.has(key) or completed_actions.has(key): return
 var state = action.duplicate(true)
 state.merge({"segments":[], "started_at":time, "missiles":false, "displacement":false, "ultimate_triggered":false, "bonus_remaining":0.0, "bonus_total":0.0, "start_position":_position(_hero(ctx)), "room_id":room_id, "generation":generation}, true)
 if active("g25") and _nonultimate(action):
  var cost = minf(maxf(0.0, float(_hero(ctx).get("hp", 0.0)) - 1.0), float(_hero(ctx).get("hp", 0.0)) * _f("g25", 1))
  state.bonus_total = _stat(ctx, "max_hp", 1.0) * _f("g25", 2)
  state.bonus_remaining = state.bonus_total
  _emit("health_cost", {"source":"common_g25", "target_id":_hero(ctx).get("actor_id", ""), "amount":cost, "nonlethal":true, "no_reactions":true, "action_id":key})
 actions[key] = state

func displacement_completed(action: Dictionary, _ctx: Dictionary) -> void:
 var key = _action_key(action)
 if not combat or not active("g07") or not actions.has(key): return
 if not action.get("active_movement", false) or action.get("forced", false) or actions[key].displacement: return
 actions[key].displacement = true
 dash_stacks = mini(dash_stacks + 1 if actor_time < dash_until else 1, int(parameter("g07", 4)))
 dash_until = actor_time + parameter("g07", 1)
 _emit("buff", {"source":"common_g07", "stacks":dash_stacks, "duration":parameter("g07", 1)})

func ultimate_presentation_ended(action: Dictionary, ctx: Dictionary) -> void:
 var key = _action_key(action)
 if not combat or not active("g09") or not actions.has(key) or not actions[key].get("ultimate", false) or actions[key].ultimate_triggered: return
 actions[key].ultimate_triggered = true
 final_until = actor_time + parameter("g09", 4)
 _shield(_hero(ctx), _stat(ctx, "max_hp", 1.0) * _f("g09", 1), parameter("g09", 4), "common_g09", ctx)

func action_end(action: Dictionary, ctx: Dictionary) -> void:
 var key = _action_key(action)
 if not actions.has(key): return
 var state: Dictionary = actions[key]
 if action.get("active_movement", state.get("active_movement", false)):
  var movement = action.duplicate(true)
  movement.active_movement = true
  displacement_completed(movement, ctx)
 if not action.get("cancelled", false):
  if active("g18") and replay_charges > 0 and _nonultimate(state) and not state.segments.is_empty():
   replay_charges -= 1
   # Each record carries only an independent damage/heal payload, never a cast callback.
   var first_offset = INF
   for segment in state.segments: first_offset = minf(first_offset, float(segment.get("relative_time", 0.0)))
   for segment in state.segments:
    var saved: Dictionary = segment.duplicate(true)
    var group = str(saved.get("replay_hit_group", ""))
    if not group.is_empty():
     # Include root-action identity, not occurrence: travelling slices belong to
     # one source hit family while separate casts retain separate allowances.
     var ledger_key = JSON.stringify([run_id, room_id, generation, key, group])
     saved["replay_ledger_key"] = ledger_key
     if not _replay_hit_ledger.has(ledger_key): _replay_hit_ledger[ledger_key] = {"pending":0, "hits":{}}
     _replay_hit_ledger[ledger_key].pending += 1
    scheduled.append({"kind":"replay", "due":time + parameter("g18", 2) + float(segment.get("relative_time", 0.0)) - first_offset, "segments":[saved], "run_id":run_id, "room_id":room_id, "generation":generation})
  if active("g28") and str(state.get("slot", "")) == "shift" and actor_time + EPS >= next_turret:
   next_turret = actor_time + parameter("g28", 8)
   while turrets.size() >= int(parameter("g28", 7)): turrets.pop_front()
   turrets.append({"entity_id":_entity_id("turret"),"last_world_at":time,"position":state.start_position, "left":parameter("g28", 1), "fire":parameter("g28", 2), "damage":_amount(ctx, "g28", 4, 5, 6), "cast_id":state.get("cast_id", key)})
   _emit("turret_spawn", {"source":"common_g28", "position":state.start_position, "duration":parameter("g28", 1)})
 completed_actions[key] = true
 actions.erase(key)

func before_damage(event: Dictionary, ctx: Dictionary) -> Dictionary:
 var result = event.duplicate(true)
 if result.get("common_processed", false): return result
 result.common_processed = true
 if not combat or result.get("no_reactions", false): return result
 var amount = maxf(0.0, float(result.get("amount", 0.0)))
 if result.get("incoming", false):
  # The adapter invokes this at HP commit, AFTER ordinary mitigation and shield absorption.
  if active("g29") and result.get("direct", false) and str(result.get("stage", "")) == "hp_commit":
   var deferred = amount * _f("g29", 1)
   if deferred > 0:
    debt.append({"remaining":deferred, "duration":parameter("g29", 2), "rate":deferred / parameter("g29", 2), "last_actor_at":actor_time})
   amount -= deferred
  result.amount = amount
  return result
 var generated = bool(result.get("hex_generated", false) or result.get("replay", false))
 var original_amount = amount
 var key = _action_key(result)
 if not generated and active("g25") and actions.has(key) and _nonultimate(actions[key]):
  # The adapter supplies normalized segment shares; absent a plan, allocate once to first hit.
  var share = clampf(float(result.get("cast_damage_share", 1.0)), 0.0, 1.0)
  var bonus = minf(actions[key].bonus_remaining, actions[key].bonus_total * share)
  actions[key].bonus_remaining -= bonus
  result.cast_bonus = bonus
  amount += bonus
 if active("g01") and result.get("active_skill", false) and str(result.get("damage_type", "ordinary")) != "true" and not result.get("crit_rolled", false):
  result.crit_rolled = true
  result.critical = rng.randf() < clampf(_stat(ctx, "crit_chance"), 0.0, 1.0)
  if result.critical: amount *= _stat(ctx, "crit_damage", 1.75)
 if not result.get("snapshot_final", false):
  amount *= _stat(ctx, "common_damage_multiplier", 1.0)
  var target: Dictionary = result.get("target", {})
  if active("g06"):
   var target_stats: Dictionary = target.get("stats", target)
   var target_speed = float(target_stats.get("move_speed", target_stats.get("speed", 0.0)))
   if float(target.get("slow_left",0.0))>0: target_speed *= 1.0-float(target.get("slow_amount",0.0))
   var advantage = maxf(0.0, _stat(ctx, "move_speed") - target_speed)
   amount *= 1.0 + minf(_f("g06", 3), advantage / parameter("g06", 1) * _f("g06", 2))
  if active("g22"):
   # Only an explicitly unified hero impact may freeze its already-observed mode.
   # Separate contacts, travelling projectiles and other skills remain dynamic.
   var living = _enemies(ctx)
   var mode = str(result.get("g22_mode_snapshot", ""))
   if mode.is_empty():
    mode = "horde" if living.size() >= int(parameter("g22", 1)) else "duel" if living.size() == 1 and not _ordinary(living[0]) else "none"
   if mode == "horde" and result.get("area", false): amount *= 1.0 + _f("g22", 2)
   elif mode == "duel": amount *= 1.0 + _f("g22", 4)
 result.amount = amount
 if float(result.get("cast_bonus",0.0))>0.0:
  result.cast_bonus_final = float(result.cast_bonus) * amount / maxf(EPS,original_amount + float(result.cast_bonus))
 return result

func after_hit(event: Dictionary, ctx: Dictionary) -> void:
 if not combat or event.get("no_reactions", false) or event.get("replay", false): return
 var target: Dictionary = event.get("target", {})
 var generated = bool(event.get("hex_generated", false))
 var effective = float(event.get("effective_damage", event.get("amount", 0.0)))
 if active("g11") and event.get("direct", false) and _alive(target) and _ordinary(target):
  var max_hp = float(target.get("max_hp", target.get("stats", {}).get("max_hp", 1.0)))
  if float(target.hp) < max_hp * _f("g11", 1):
   if not generated or str(event.get("source", "")) == "common_g11": _execute(target, event, ctx)
 if generated: return
 if active("g14") and event.get("basic_attack", false) and _alive(target):
  var id = str(target.get("actor_id", ""))
  var old: Dictionary = shrink.get(id, {})
  var count = int(old.get("stacks", 0)) if float(old.get("until", 0.0)) > time else 0
  shrink[id] = {"stacks":mini(count + 1, int(parameter("g14", 1))), "until":time + parameter("g14", 2), "ordinary":_ordinary(target)}
  _emit("enemy_modifiers", {"source":"common_g14", "target_id":id, "modifiers":enemy_modifiers(id), "duration":parameter("g14", 2)})
 if effective <= 0: return
 if active("g12") and event.get("active_skill", false):
  var origin: Vector3 = event.get("cast_origin", _position(_hero(ctx)))
  if origin.distance_to(_position(target)) + EPS >= parameter("g12", 1):
   long_range_hits += 1
   if long_range_hits >= int(parameter("g12", 2)) and actor_time + EPS >= next_bombardment:
    next_bombardment = actor_time + parameter("g12", 8)
    scheduled.append({"kind":"bombardment", "due":time + parameter("g12", 3), "position":_position(target), "radius":parameter("g12",4), "damage":_amount(ctx, "g12", 5, 6, 7), "room_id":room_id, "generation":generation})
    _emit("bombardment_warning", {"source":"common_g12", "position":_position(target), "delay":parameter("g12", 3), "radius":parameter("g12", 4)})
 var key = _action_key(event)
 if active("g16") and actions.has(key) and _nonultimate(actions[key]) and not actions[key].missiles:
  actions[key].missiles = true
  var targets = _nearest(_enemies(ctx), _position(_hero(ctx)), parameter("g16", 1))
  var count = mini(int(parameter("g16", 5)), int(parameter("g16", 2)) + floori(_stat(ctx, "crit_chance") / _f("g16", 3)) * int(parameter("g16", 4)))
  for i in range(count):
   if targets.is_empty(): break
   var chosen: Dictionary = targets[i % targets.size()]
   projectiles.append({"entity_id":_entity_id("missile"),"last_world_at":time,"kind":"missile", "source":"common_g16", "position":_position(_hero(ctx)), "target_id":chosen.actor_id, "speed":parameter("g16", 9), "left":parameter("g16", 1) / parameter("g16", 9) + 2.0, "damage":_amount(ctx, "g16", 6, 7, 8), "cast_id":actions[key].get("cast_id", key)})
  _emit("missiles_fired", {"source":"common_g16", "count":0 if targets.is_empty() else count, "action_id":key})

func enemy_modifiers(actor_id: String) -> Dictionary:
 if not active("g14") or not shrink.has(actor_id) or time >= float(shrink[actor_id].until):
  return {"model_scale":1.0, "collision_scale":1.0, "damage_multiplier":1.0, "knockback_resistance_multiplier":1.0}
 var state: Dictionary = shrink[actor_id]
 var count = int(state.stacks)
 var scale = 1.0 - count * _f("g14", 3) if state.ordinary else 1.0
 return {"model_scale":scale, "collision_scale":scale, "damage_multiplier":1.0 - (count * _f("g14", 4) if state.ordinary else minf(count * _f("g14", 4), _f("g14", 6))), "knockback_resistance_multiplier":1.0 - count * _f("g14", 5) if state.ordinary else 1.0}

func _execute(target: Dictionary, event: Dictionary, ctx: Dictionary) -> void:
 var target_id = str(target.get("actor_id", ""))
 if executed.has(target_id): return
 var chain = int(event.get("chain_id", -1))
 if chain < 0:
  _next_chain += 1
  chain = _next_chain
  chain_counts[chain] = 0
 if int(chain_counts.get(chain, 0)) >= int(parameter("g11", 8)): return
 chain_counts[chain] = int(chain_counts.get(chain, 0)) + 1
 executed[target_id] = true
 var direction: Vector3 = event.get("direction", _position(target) - _position(_hero(ctx)))
 if direction.length_squared() < EPS: direction = _hero(ctx).get("facing", Vector3.FORWARD)
 direction = direction.normalized()
 _emit("execute", {"source":"common_g11", "target_id":target_id, "chain_id":chain, "direction":direction,"cast_id":int(event.get("cast_id",0))})
 projectiles.append({"entity_id":_entity_id("corpse"),"last_world_at":time,"source_kind":target.get("kind","minion"),"kind":"corpse", "source":"common_g11", "position":_position(target), "direction":direction, "speed":parameter("g11", 2), "distance_left":parameter("g11", 3), "damage":_amount(ctx, "g11", 5, 6, 7), "chain_id":chain, "ignore_id":target_id,"cast_id":int(event.get("cast_id",0))})

func _damage(target: Dictionary, amount: float, source: String, at: Vector3, extra: Dictionary = {}) -> void:
 var payload = {"target_id":target.get("actor_id", ""), "amount":amount, "source":source, "damage_type":"ordinary", "position":at, "direct":true, "hex_generated":true, "active_skill":false, "basic_attack":false}
 payload.merge(extra, true)
 _emit("damage", payload)

func _area_damage(ctx: Dictionary, at: Vector3, radius: float, amount: float, source: String, extra: Dictionary = {}) -> void:
 var payload = extra.duplicate(true)
 payload.area = true
 for target in _near(_enemies(ctx), at, radius):
  if not extra.has("direction"): payload.direction = (_position(target) - at).normalized()
  _damage(target, amount, source, at, payload)
 _emit("area_effect", {"source":source, "position":at, "radius":radius})

func _shield(target: Dictionary, amount: float, duration: float, source: String, ctx: Dictionary) -> void:
 _emit("shield", {"target_id":target.get("actor_id", ""), "amount":amount, "initial_amount":amount, "duration":duration, "source":source, "owner_id":_hero(ctx).get("actor_id", ""), "source_hex":source, "no_rescue_charge":source == "common_g13"})

func healed(event: Dictionary, ctx: Dictionary) -> void:
 if not combat or not active("g13") or event.get("no_rescue_charge", false) or event.get("replay", false) or str(event.get("source", "")) == "common_g13": return
 if str(event.get("owner_id", "")) != str(_hero(ctx).get("actor_id", "")): return
 if _actor(ctx, str(event.get("target_id", "")), true).is_empty(): return
 rescue_energy += maxf(0.0, float(event.get("effective_heal", 0.0))) * _f("g13", 1)
 _try_rescue(ctx)

func shield_absorbed(event: Dictionary, ctx: Dictionary) -> void:
 if not combat or not active("g13"): return
 var shield: Dictionary = event.get("shield", {})
 if shield.get("no_rescue_charge", false) or str(shield.get("source_hex", "")) == "common_g13": return
 if str(shield.get("owner_id", "")) != str(_hero(ctx).get("actor_id", "")): return
 if _actor(ctx, str(event.get("target_id", "")), true).is_empty(): return
 rescue_energy += maxf(0.0, float(event.get("absorbed", 0.0))) * _f("g13", 1)
 _try_rescue(ctx)

func _try_rescue(ctx: Dictionary) -> void:
 if rescue_energy + EPS < _stat(ctx, "max_hp", 1.0) * _f("g13", 2) or actor_time + EPS < next_rescue: return
 var candidates = _near(_allies(ctx), _position(_hero(ctx)), parameter("g13", 3))
 if candidates.is_empty(): return
 candidates.sort_custom(func(a, b):
  var pa = float(a.get("hp", 0.0)) / maxf(1.0, float(a.get("stats", a).get("max_hp", 1.0)))
  var pb = float(b.get("hp", 0.0)) / maxf(1.0, float(b.get("stats", b).get("max_hp", 1.0)))
  return str(a.get("actor_id", "")) < str(b.get("actor_id", "")) if is_equal_approx(pa, pb) else pa < pb)
 var target: Dictionary = candidates[0]
 rescue_energy = 0.0
 next_rescue = actor_time + parameter("g13", 8)
 _emit("heal", {"source":"common_g13", "target_id":target.actor_id, "owner_id":_hero(ctx).get("actor_id", ""), "amount":float(target.get("stats", target).get("max_hp", 1.0)) * _f("g13", 4), "hex_generated":true, "no_rescue_charge":true})
 for ally in _near(_allies(ctx), _position(target), parameter("g13", 5)):
  _shield(ally, _stat(ctx, "max_hp", 1.0) * _f("g13", 6), parameter("g13", 7), "common_g13", ctx)

func shield_broken(event: Dictionary, ctx: Dictionary) -> void:
 if not combat or not active("g26") or str(event.get("reason", "")) != "enemy_damage": return
 var shield: Dictionary = event.get("shield", {})
 if str(shield.get("owner_id", "")) != str(_hero(ctx).get("actor_id", "")): return
 if float(event.get("remaining", 0.0)) > EPS or float(event.get("absorbed", 0.0)) <= 0: return
 var target_id = str(event.get("target_id", ""))
 if actor_time + EPS < float(shield_break_cooldowns.get(target_id, 0.0)): return
 shield_break_cooldowns[target_id] = actor_time + parameter("g26", 5)
 var holder = _actor(ctx, target_id, true)
 var at: Vector3 = event.get("position", _position(holder))
 var damage = minf(float(shield.get("initial_amount", 0.0)) * _f("g26", 2), _stat(ctx, "max_hp", 1.0) * _f("g26", 3))
 _area_damage(ctx, at, parameter("g26", 1), damage, "common_g26")
 for target in _near(_enemies(ctx), at, parameter("g26", 1)):
  if _ordinary(target): _emit("knockback", {"source":"common_g26", "target_id":target.actor_id, "direction":(_position(target) - at).normalized(), "distance":parameter("g26", 4)})

func enemy_died(event: Dictionary, _ctx: Dictionary) -> void:
 if not combat or not event.get("participated", false): return
 var target: Dictionary = event.get("target", {})
 var id = str(target.get("actor_id", ""))
 if id.is_empty() or seen_deaths.has(id): return
 seen_deaths[id] = true
 var ordinary = _ordinary(target)
 var kind = str(target.get("rank_category", target.get("kind", "ordinary")))
 if active("g04") and ordinary:
  growth_kills += 1
  if growth_kills >= int(parameter("g04", 1)):
   growth_kills -= int(parameter("g04", 1))
   growth = mini(growth + 1, int(parameter("g04", 4)))
 if active("g05"):
  if ordinary:
   cooldown_kills += 1
   if cooldown_kills >= int(parameter("g05", 2)):
    cooldown_kills -= int(parameter("g05", 2))
    cooldown_groups += 1
    cooldown_bonus += _f("g05", 3)
  elif kind == "elite":
   cooldown_elites += 1
   cooldown_bonus += _f("g05", 4)
  elif kind == "boss":
   cooldown_bosses += 1
   cooldown_bonus += _f("g05", 5)
 if active("g18") and ordinary:
  replay_kills += 1
  if replay_kills >= int(parameter("g18", 1)):
   replay_kills -= int(parameter("g18", 1))
   replay_charges += 1
 if active("g10"):
  if ordinary: soul_kills += 1
  var ready = soul_kills >= int(parameter("g10", 1)) or kind == "elite"
  if ready and actor_time + EPS >= next_soul:
   if ordinary: soul_kills -= int(parameter("g10", 1))
   next_soul = actor_time + parameter("g10", 5)
   souls.append({"entity_id":_entity_id("soul"),"last_world_at":time,"position":_position(target), "left":parameter("g10", 2)})
   _emit("soul_spawn", {"source":"common_g10", "position":_position(target), "duration":parameter("g10", 2)})

func hero_died(truly_dead: bool) -> void:
 if truly_dead and active("g04"): growth = floori(growth * (1.0 - _f("g04", 5)))

func potion_used(ctx: Dictionary) -> void:
 if combat and active("g23"):
  _area_damage(ctx, _position(_hero(ctx)), parameter("g23", 1), _amount(ctx, "g23", 2, 3, 4), "common_g23")

func record_segment(action_id: Variant, segment: Dictionary, ctx: Dictionary) -> bool:
 var key = str(action_id)
 if not combat or not active("g18") or not actions.has(key) or not _nonultimate(actions[key]): return false
 if not _replay_context_current(ctx): return false
 if segment.get("hex_generated", false) or segment.get("replay", false): return false
 if str(segment.get("kind", "")) not in ["damage", "heal"]: return false
 if not bool(segment.get("independent", false)): return false
 var mode = str(segment.get("target_mode", ""))
 if mode not in ["bound", "spatial", "self_heal"]: return false
 var validator: Callable = options.get("segment_allowed", Callable())
 # A callback may further restrict the authored whitelist, but cannot broaden it.
 var allowed = _allowed_segment(actions[key], segment)
 if allowed.is_empty(): return false
 if validator.is_valid() and not bool(validator.call(actions[key], segment)): return false
 var record = segment.duplicate(true)
 # An adapter cannot invent, remove or split a source cap by changing metadata.
 # Existing single-contact captures can omit these optional fields safely.
 record.replay_hit_group = str(allowed.get("replay_hit_group", ""))
 record.replay_hit_limit = int(allowed.get("replay_hit_limit", 0))
 record.erase("replay_ledger_key")
 record.relative_time = maxf(0.0, float(segment.get("relative_time", time - float(actions[key].started_at))))
 record.cast_id = actions[key].get("cast_id", action_id)
 record.run_id = run_id
 record.room_id = room_id
 record.generation = generation
 record.saved_stats = _stats(ctx).duplicate(true)
 record.saved_aim = segment.get("saved_aim", _hero(ctx).get("aim_point", Vector3.ZERO))
 record.position = segment.get("position", _position(_hero(ctx)))
 record.amount = maxf(0.0, float(segment.get("amount", 0.0)))
 record.snapshot_final = true
 # Target identities, not actor dictionary references, are retained for bound effects.
 record.target_ids = [_hero(ctx).get("actor_id", "")] if mode == "self_heal" else segment.get("target_ids", []).duplicate()
 actions[key].segments.append(record)
 return true

func segment_allowed(action: Dictionary, segment: Dictionary) -> bool:
 return not _allowed_segment(action, segment).is_empty()

func _allowed_segment(action: Dictionary, segment: Dictionary) -> Dictionary:
 var hero_id = str(action.get("hero_id", ""))
 var candidate = str(action.get("candidate", "")).to_lower()
 var definition: Dictionary = Design.replay_map().get("skills", {}).get(hero_id + "_" + candidate, {})
 if str(definition.get("status", "")) != "approved_damage_heal_segments": return {}
 for allowed in definition.get("segments", []):
  if str(allowed.id) != str(segment.get("segment_id", "")): continue
  if str(allowed.kind) != str(segment.get("kind", "")): return {}
  var selection = str(segment.get("target_mode", ""))
  if selection == "bound": selection = "target_bound"
  var original = str(allowed.get("selection", ""))
  if original == "bound": original = "target_bound"
  if selection != original: return {}
  if selection == "spatial" and str(segment.get("shape", {}).get("kind", "")) != str(allowed.get("geometry", "")): return {}
  if segment.has("replay_hit_group") and (typeof(segment.replay_hit_group) != TYPE_STRING or segment.replay_hit_group != str(allowed.get("replay_hit_group", ""))): return {}
  if segment.has("replay_hit_limit") and (typeof(segment.replay_hit_limit) != TYPE_INT or segment.replay_hit_limit != int(allowed.get("replay_hit_limit", 0))): return {}
  return allowed
 return {}

func _replay_target_current(target: Dictionary) -> bool:
 # Adapters normally pass only the current enemy collection; explicit identity
 # fields are still checked so stale or replacement collections fail closed.
 return _alive(target) and str(target.get("run_id", run_id)) == run_id and str(target.get("room_id", room_id)) == room_id and int(target.get("generation", generation)) == generation

func _replay_context_current(ctx: Dictionary) -> bool:
 return str(ctx.get("run_id", run_id)) == run_id and str(ctx.get("room_id", room_id)) == room_id and int(ctx.get("generation", generation)) == generation

func _release_replay_entry(entry: Dictionary) -> void:
 for segment in entry.get("segments", []):
  var key = str(segment.get("replay_ledger_key", ""))
  if not _replay_hit_ledger.has(key): continue
  _replay_hit_ledger[key].pending -= 1
  if int(_replay_hit_ledger[key].pending) <= 0: _replay_hit_ledger.erase(key)

func _replay(entry: Dictionary, ctx: Dictionary) -> void:
 if not _replay_context_current(ctx): return
 for segment in entry.segments:
  if segment.run_id != run_id or segment.room_id != room_id or int(segment.generation) != generation: continue
  var friendly = str(segment.kind) == "heal"
  var targets: Array = []
  if str(segment.target_mode) in ["bound", "self_heal"]:
   for id in segment.target_ids:
    var actor = _actor(ctx, str(id), friendly)
    if not actor.is_empty(): targets.append(actor)
  else:
   targets = _shape_targets(_allies(ctx) if friendly else _enemies(ctx), segment)
  var ledger_key = str(segment.get("replay_ledger_key", ""))
  var limit = int(segment.get("replay_hit_limit", 0))
  # The ledger is created only when all captured slices are scheduled. Missing
  # capped state must never silently turn a capped family into unlimited hits.
  if limit > 0 and not _replay_hit_ledger.has(ledger_key): continue
  var eligible: Array = []
  var seen: Dictionary = {}
  for target in targets:
   var target_id = str(target.get("actor_id", ""))
   if target_id.is_empty() or seen.has(target_id) or not _replay_target_current(target): continue
   seen[target_id] = true
   if limit > 0 and int(_replay_hit_ledger[ledger_key].hits.get(target_id, 0)) >= limit: continue
   eligible.append(target)
  targets = eligible
  for target in targets:
   var nominal = float(segment.get("target_amounts",{}).get(str(target.actor_id),segment.amount))
   nominal += float(segment.get("cast_bonus_total",0.0)) / maxi(1,targets.size())
   nominal *= float(segment.get("target_final_multipliers",{}).get(str(target.actor_id),1.0))
   var output = {"source":"common_g18", "target_id":target.actor_id, "amount":nominal * _f("g18", 3), "position":segment.position, "owner_id":_hero(ctx).get("actor_id", ""), "replay":true, "hex_generated":true, "no_reactions":true, "snapshot_final":true, "crit_rolled":true, "critical":segment.get("target_criticals",{}).get(str(target.actor_id),segment.get("critical", false)), "damage_type":segment.get("damage_type", "ordinary"), "saved_stats":segment.saved_stats.duplicate(true), "saved_aim":segment.saved_aim, "segment_id":segment.get("segment_id", ""), "occurrence":segment.get("occurrence", 0), "cast_id":segment.cast_id, "direct":true, "area":str(segment.target_mode) == "spatial"}
   if limit > 0:
    _replay_hit_ledger[ledger_key].hits[str(target.actor_id)] = int(_replay_hit_ledger[ledger_key].hits.get(str(target.actor_id), 0)) + 1
   _emit(str(segment.kind), output)

func _shape_targets(actors: Array, segment: Dictionary) -> Array:
 var at: Vector3 = segment.position
 var shape: Dictionary = segment.get("shape", {})
 var kind = str(shape.get("kind", "circle"))
 var direction: Vector3 = shape.get("direction", segment.get("direction", Vector3.FORWARD))
 direction = direction.normalized()
 var result: Array = []
 for actor in actors:
  var offset = _position(actor) - at
  offset.y = 0
  var include = false
  var actor_radius:float=maxf(0.0,float(actor.get("radius",0.0)))
  if kind in ["circle", "contact_circle", "recorded_contact_circle"]: include = offset.length() <= float(shape.get("radius", 0.0)) + actor_radius + EPS
  elif kind == "cone":
   include = offset.length() <= float(shape.get("radius", 0.0)) + actor_radius + EPS and (offset.length() <= actor_radius + EPS or direction.dot(offset.normalized()) >= cos(deg_to_rad(float(shape.get("degrees", 90.0)) * 0.5)))
  elif kind in ["rectangle", "line"]:
   var forward = offset.dot(direction)
   var sideways = absf(offset.dot(Vector3(direction.z, 0, -direction.x)))
   if shape.get("circle_rectangle",false):
    include = SweptRectangle.circle_intersects(at,direction,float(shape.get("length",0.0)),float(shape.get("width",0.0)),_position(actor),actor_radius,shape.get("clipped_front",false),float(shape.get("forward_limit",INF)))
   else:
    include = forward >= -actor_radius-EPS and forward <= float(shape.get("length", 0.0)) + actor_radius + EPS and sideways <= float(shape.get("width", 0.0)) * 0.5 + actor_radius + EPS
  elif kind in ["recorded_path", "recorded_polyline"]:
   var points: Array = shape.get("points", [])
   var width = float(shape.get("width", 0.0)) * 0.5
   for i in range(maxi(0, points.size() - 1)):
    var start: Vector3 = points[i]
    var finish: Vector3 = points[i + 1]
    var span = finish - start
    var t = clampf((_position(actor) - start).dot(span) / maxf(EPS, span.length_squared()), 0.0, 1.0)
    if _position(actor).distance_to(start.lerp(finish, t)) <= width + actor_radius + EPS: include = true
  if include: result.append(actor)
 return result

# New adapters advance clocks before their gameplay events, then settle at their
# existing end-of-step position. Legacy tick-only adapters retain prior ordering.
func begin_tick(world_dt: float, owner_dt: float = -1.0) -> void:
 if not combat or _tick_prepared: return
 _tick_prepared = true
 time += maxf(0.0,world_dt)
 actor_time += maxf(0.0,world_dt if owner_dt < 0.0 else owner_dt)

func _world_elapsed(entry: Dictionary, fallback: float) -> float:
 var elapsed = maxf(0.0,time-float(entry.get("last_world_at",time-fallback)))
 entry.last_world_at = time
 return elapsed

func tick(dt: float, ctx: Dictionary, owner_dt: float = -1.0) -> void:
 if not combat: return
 var actor_dt = maxf(0.0,dt if owner_dt < 0.0 else owner_dt)
 if not _tick_prepared: begin_tick(dt,actor_dt)
 _tick_prepared = false
 if dt <= 0.0 and actor_dt <= 0.0: return
 for entry in debt.duplicate():
  var elapsed = maxf(0.0,actor_time-float(entry.get("last_actor_at",actor_time-actor_dt)))
  entry.last_actor_at = actor_time
  var amount = minf(float(entry.remaining), float(entry.rate) * minf(elapsed, float(entry.duration)))
  entry.remaining -= amount
  entry.duration -= elapsed
  if amount > 0: _emit("health_debt", {"source":"common_g29", "target_id":_hero(ctx).get("actor_id", ""), "amount":amount, "no_reactions":true, "bypass_mitigation":true, "bypass_shields":true, "cannot_defer":true})
  if entry.remaining <= EPS or entry.duration <= EPS: debt.erase(entry)
 for soul in souls.duplicate():
  soul.left -= _world_elapsed(soul,dt)
  if _position(_hero(ctx)).distance_to(soul.position) <= parameter("g10", 6) + EPS:
   soul_speed_until = actor_time + parameter("g10", 4)
   _reset_nonultimate("common_g10")
   _emit("soul_pickup", {"source":"common_g10", "position":soul.position})
   souls.erase(soul)
  elif soul.left <= 0: souls.erase(soul)
 for actor_id in shrink.keys():
  if time >= float(shrink[actor_id].until):
   shrink.erase(actor_id)
   _emit("enemy_modifiers", {"source":"common_g14", "target_id":actor_id, "modifiers":enemy_modifiers(actor_id), "duration":0.0})
 # Process due slices chronologically even when a large dt crosses several
 # casts. Equal due times retain insertion order (Godot's sort is not stable).
 var ordered: Array = []
 for index in range(scheduled.size()): ordered.append({"entry":scheduled[index], "order":index})
 ordered.sort_custom(func(a, b):
  return int(a.order) < int(b.order) if float(a.entry.due) == float(b.entry.due) else float(a.entry.due) < float(b.entry.due))
 for pending in ordered:
  var entry: Dictionary = pending.entry
  if str(entry.get("run_id", run_id)) != run_id or entry.room_id != room_id or int(entry.generation) != generation:
   scheduled.erase(entry)
   if entry.kind == "replay": _release_replay_entry(entry)
   continue
  if time + EPS < float(entry.due): continue
  scheduled.erase(entry)
  if entry.kind == "bombardment": _area_damage(ctx, entry.position, float(entry.get("radius",parameter("g12",4))), entry.damage, "common_g12")
  elif entry.kind == "replay":
   _replay(entry, ctx)
   _release_replay_entry(entry)
 _tick_projectiles(dt, ctx)
 _tick_turrets(dt, ctx)
 if active("g13"): _try_rescue(ctx)

func _tick_projectiles(dt: float, ctx: Dictionary) -> void:
 for projectile in projectiles.duplicate():
  var elapsed = _world_elapsed(projectile,dt)
  if elapsed <= EPS: continue
  var before: Vector3 = projectile.position
  if projectile.kind == "missile":
   var target = _actor(ctx, str(projectile.target_id))
   projectile.left -= elapsed
   if target.is_empty() or projectile.left < -EPS:
    projectiles.erase(projectile)
    continue
   var step = projectile.speed * elapsed
   if before.distance_to(_position(target)) <= step + float(target.get("radius", 0.0)):
    _damage(target, projectile.damage, "common_g16", _position(target), {"cast_id":projectile.cast_id})
    projectiles.erase(projectile)
   else: projectile.position = before.move_toward(_position(target), step)
  elif projectile.kind == "corpse":
   var step = minf(projectile.distance_left, projectile.speed * elapsed)
   var after: Vector3 = before + projectile.direction * step
   var impact = false
   var wall: Callable = options.get("clip_projectile", Callable())
   if wall.is_valid():
    var clipped: Vector3 = wall.call(before, after)
    if clipped.distance_squared_to(after) > EPS:
     after = clipped
     impact = true
   # Swept sphere tests: fast corpses cannot tunnel through enemies at coarse dt.
   var first_fraction = 1.0
   for target in _enemies(ctx):
    if str(target.actor_id) == str(projectile.ignore_id): continue
    var fraction = _segment_hit(before, after, _position(target), float(target.get("radius", 0.5)))
    if fraction >= 0 and fraction <= first_fraction:
     first_fraction = fraction
     impact = true
   if first_fraction < 1.0: after = before.lerp(after, first_fraction)
   projectile.position = after
   projectile.distance_left -= step
   if impact or projectile.distance_left <= EPS:
    _area_damage(ctx, after, parameter("g11", 4), projectile.damage, "common_g11", {"chain_id":projectile.chain_id, "cast_id":projectile.get("cast_id",0), "direction":projectile.direction})
    projectiles.erase(projectile)

func _segment_hit(a: Vector3, b: Vector3, center: Vector3, radius: float) -> float:
 var d = b - a
 var f = a - center
 var aa = d.dot(d)
 if f.length_squared() <= radius * radius: return 0.0
 if aa <= EPS: return -1.0
 var bb = 2.0 * f.dot(d)
 var cc = f.dot(f) - radius * radius
 var discriminant = bb * bb - 4.0 * aa * cc
 if discriminant < 0: return -1.0
 var t = (-bb - sqrt(discriminant)) / (2.0 * aa)
 return t if t >= 0.0 and t <= 1.0 else -1.0

func _tick_turrets(dt: float, ctx: Dictionary) -> void:
 for turret in turrets.duplicate():
  var elapsed = _world_elapsed(turret,dt)
  var active_dt = minf(elapsed, turret.left)
  turret.left -= elapsed
  turret.fire -= active_dt
  while turret.fire <= EPS:
   turret.fire += parameter("g28", 2)
   var targets = _nearest(_enemies(ctx), turret.position, parameter("g28", 3))
   if not targets.is_empty(): _damage(targets[0], turret.damage, "common_g28", turret.position, {"cast_id":turret.cast_id})
  if turret.left <= EPS: turrets.erase(turret)

func snapshot() -> Dictionary:
 return {"combat":combat, "run_id":run_id, "room_id":room_id, "generation":generation, "time":time, "actor_time":actor_time, "form":form, "growth":growth, "cooldown_bonus":cooldown_bonus, "replay_charges":replay_charges, "long_range_hits":long_range_hits, "rescue_energy":rescue_energy, "dash_stacks":dash_stacks if actor_time < dash_until else 0, "souls":souls.duplicate(true), "projectiles":projectiles.duplicate(true), "turrets":turrets.duplicate(true), "scheduled":scheduled.duplicate(true), "debt":debt.duplicate(true), "formal_additions":Design.approved_proposals()}
