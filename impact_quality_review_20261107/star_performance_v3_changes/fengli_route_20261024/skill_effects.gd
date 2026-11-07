extends RefCounted
const R1StarVisual = preload("res://fengli_route_20261024/r1_star_visual.gd")
var r1_star = R1StarVisual.new()
## Read-only Wind Q1/Q2/Q3/E1/E2/E3/R1 display. Install under fengli_route_20261024.
## No input, casts, physics, movement, damage, time scaling, or source-state writes.
## Call accept synchronously from combat_event, draw_ground before hostile warnings,
## then draw_hits after actors. All world geometry uses the source ground plane y=0.
const HERO_ID: String = "fengli"
const MAX_CASTS: int = 32
const MAX_SHAPES: int = 12
const MAX_BURSTS: int = 32
const MAX_TARGETS_PER_CAST: int = 128
const MAX_PROJECTILES: int = 16
const MAX_PATH_POINTS: int = 32
const MAX_ENEMIES: int = 256
const EPS: float = 0.00001
const MAX_POSITION: float = 256.0
const MAX_LENGTH: float = 64.0
const MAX_WIDTH: float = 16.0
const MAX_RADIUS: float = 32.0
const HIT_LIFE: float = 0.16
const RELEASE_LIFE: float = 0.24
var shapes: Array = []
var casts: Dictionary = {}
var bursts: Array = []
var receipt: Dictionary = {}
var error: String = ""
var last_sequence: int = -1
var _scope: Dictionary = {}
var _scope_key: String = ""
var _cast_highwater: int = -1
var _e3_activation: Dictionary = {}
var _e3_save: Dictionary = {}

func clear() -> void:
 r1_star.clear()
 _e3_activation.clear()
 _e3_save.clear()
 shapes.clear()
 casts.clear()
 bursts.clear()
 receipt.clear()
 _scope.clear()
 _scope_key = ""
 last_sequence = -1
 _cast_highwater = -1
 error = ""

func _fail(reason: String) -> void:
 r1_star.clear()
 if error.is_empty():
  error = reason
 shapes.clear()
 bursts.clear()

func _number(value: Variant, lower: float, upper: float) -> bool:
 return (value is int or value is float) and is_finite(float(value)) and float(value) >= lower and float(value) <= upper

func _integer(value: Variant, lower: int = 0) -> bool:
 return _number(value, float(lower), 9007199254740991.0) and float(value) == floor(float(value))

func _point(value: Variant) -> bool:
 return value is Vector3 and value.is_finite() and absf(value.y) <= EPS and value.length() <= MAX_POSITION

func _direction(value: Variant) -> bool:
 return _point(value) and value.length_squared() > EPS

func _text(value: Variant) -> bool:
 return value is String and not value.is_empty() and value.length() <= 160

func _sync_scope(sim: Node) -> bool:
 if str(sim.hero.actor_id) != HERO_ID:
  _fail("wind_display_wrong_hero")
  return false
 if not _integer(sim.encounter_generation) or not _text(sim.room_id) or not _text(sim.combat_level_id):
  _fail("wind_display_scope_invalid")
  return false
 if not _number(sim.clock.world_time, 0.0, 1e12) or not _number(sim.real_time, 0.0, 1e12) or not _number(sim.hero_time, 0.0, 1e12):
  _fail("wind_display_clock_invalid")
  return false
 var key: String = "%d|%s|%s|%d|%s" % [sim.get_instance_id(), sim.combat_level_id, sim.room_id, sim.encounter_generation, HERO_ID]
 if key != _scope_key:
  clear()
  _scope_key = key
  _scope = {"sim_id":sim.get_instance_id(), "hero_id":HERO_ID, "generation":sim.encounter_generation, "room_id":sim.room_id, "combat_level_id":sim.combat_level_id}
 return error.is_empty()

func _event_current(event: Dictionary, sim: Node) -> bool:
 if not _integer(event.get("sequence")) or not _integer(event.get("generation")):
  _fail("wind_event_identity_invalid")
  return false
 if int(event.generation) != int(_scope.generation) or str(event.get("room_id", "")) != str(_scope.room_id) or str(event.get("combat_level_id", "")) != str(_scope.combat_level_id):
  return false
 if bool(event.get("stale_generation", false)):
  return false
 if not _number(event.get("world_time"), 0.0, float(sim.clock.world_time) + EPS) or not _number(event.get("real_time"), 0.0, float(sim.real_time) + EPS):
  _fail("wind_event_clock_invalid")
  return false
 if absf(float(event.real_time) - float(sim.real_time)) > EPS or absf(float(event.world_time) - float(sim.clock.world_time)) > EPS:
  return false
 if event.has("hero_time") and not _number(event.hero_time, 0.0, float(sim.hero_time) + EPS):
  _fail("wind_event_hero_clock_invalid")
  return false
 return true

func _identity(id: int) -> String:
 return "%s|cast:%d" % [_scope_key, id]

func _cast_valid(event: Dictionary, sim: Node) -> bool:
 return _integer(event.get("cast_id"), 1) and sim.cast_is_current(int(event.cast_id))

func _drop_cast(id: int) -> void:
 if r1_star.cast_id == id:
  r1_star.clear()
 casts.erase(id)
 shapes = shapes.filter(func(e: Dictionary) -> bool: return int(e.cast_id) != id)
 bursts = bursts.filter(func(e: Dictionary) -> bool: return int(e.cast_id) != id)

func _open_cast(event: Dictionary, source: String, sim: Node) -> bool:
 # Core basic starts inherit context.origin; Wind Q/E/R starts emit position.
 # Select the exact source schema, never substitute ZERO or a live player point.
 var start_position_field: String = "origin" if str(event.get("kind", "")) in ["attack_started", "dash_attack_started"] else "position"
 var start_position: Variant = event.get(start_position_field)
 if not _cast_valid(event, sim) or not _point(start_position) or not _direction(event.get("direction")):
  _fail("wind_cast_start_invalid")
  return false
 var id: int = int(event.cast_id)
 if casts.has(id) or id <= _cast_highwater:
  return false
 if casts.size() >= MAX_CASTS:
  _drop_cast(int(casts.keys()[0]))
 _cast_highwater = id
 casts[id] = {"source":source, "direction":event.direction, "start_position":start_position, "start_position_field":start_position_field, "start_sequence":event.sequence, "world_time":event.world_time, "real_time":event.real_time, "hero_time":event.get("hero_time", sim.hero_time), "claims":{}, "stages":{}, "cast_identity":_identity(id)}
 return true

func _geometry(event: Dictionary, circular: bool = false) -> bool:
 if not _point(event.get("position")):
  return false
 if circular:
  return _number(event.get("radius"), EPS, MAX_RADIUS)
 return _direction(event.get("direction")) and _number(event.get("length"), EPS, MAX_LENGTH) and _number(event.get("width"), EPS, MAX_WIDTH)

func _timing(event: Dictionary) -> bool:
 return _number(event.get("duration"), EPS, 10.0) and _number(event.get("contact_after"), 0.0, float(event.duration))

func _append_shape(event: Dictionary, domain: String, sim: Node) -> void:
 if shapes.size() >= MAX_SHAPES:
  shapes.pop_front()
 shapes.append({"kind":event.kind, "cast_id":event.cast_id, "sequence":event.sequence, "position":event.position, "direction":event.get("direction", Vector3.FORWARD), "length":event.get("length", 0.0), "width":event.get("width", 0.0), "radius":event.get("radius", 0.0), "world_time":event.world_time, "real_time":event.real_time, "hero_time":event.get("hero_time", sim.hero_time), "domain":domain, "contact_after":event.get("contact_after", 0.0)})

func _once(event: Dictionary, stage: String) -> bool:
 var state: Dictionary = casts[int(event.cast_id)]
 if state.stages.has(stage):
  return false
 state.stages[stage] = true
 return true

# Q2 has its own source schema: a chain of real displacements, never a Q1 area.
func _open_q2(event: Dictionary, sim: Node) -> void:
 if not _cast_valid(event, sim) or not _number(event.get("hero_time"), 0.0, float(sim.hero_time) + EPS) or absf(float(event.get("hero_time", -1.0)) - float(sim.hero_time)) > EPS or not _point(event.get("position")) or not _text(event.get("target_id")) or not _number(event.get("duration"), EPS, 2.0) or not _direction(sim.hero.facing):
  _fail("wind_q2_start_invalid")
  return
 var id: int = int(event.cast_id)
 if casts.has(id) or id <= _cast_highwater:
  return
 if casts.size() >= MAX_CASTS:
  _drop_cast(int(casts.keys()[0]))
 _cast_highwater = id
 casts[id] = {"source":"q2", "direction":sim.hero.facing, "start_position":event.position, "start_sequence":event.sequence, "world_time":event.world_time, "real_time":event.real_time, "hero_time":event.hero_time, "claims":{}, "stages":{}, "cast_identity":_identity(id), "paths":[], "strike":0, "target_id":event.target_id, "finished":false}

func _q2_strike_start(event: Dictionary, sim: Node) -> Dictionary:
 if not _cast_valid(event, sim) or not casts.has(int(event.cast_id)):
  return {}
 var state: Dictionary = casts[int(event.cast_id)]
 if str(state.source) != "q2":
  return {}
 if not _number(event.get("hero_time"), 0.0, float(sim.hero_time) + EPS) or absf(float(event.get("hero_time", -1.0)) - float(sim.hero_time)) > EPS or not _point(event.get("origin")) or not _point(event.get("destination")) or not _text(event.get("target_id")) or not _integer(event.get("strike"), 1) or int(event.strike) > 4 or not _number(event.get("duration"), EPS, 2.0):
  _fail("wind_q2_strike_invalid")
  return {}
 if int(event.strike) <= int(state.strike):
  return {}
 if int(event.strike) != int(state.strike) + 1 or not sim.hero.cast_state.has("q2"):
  _fail("wind_q2_strike_order_invalid")
  return {}
 var value: Variant = sim.hero.cast_state.q2
 if not value is Dictionary or not value.has_all(["cast_id","target_id","generation","origin","duration","count"]):
  _fail("wind_q2_live_schema_invalid")
  return {}
 var live: Dictionary = value
 var target: Dictionary = sim.enemy_by_id(str(event.target_id))
 if target.is_empty() or not _point(target.get("position")) or not _point(live.get("origin")) or not _number(live.get("duration"), EPS, 2.0) or not _integer(live.get("count")) or not _integer(live.get("cast_id"), 1) or not _integer(live.get("generation")) or event.origin.distance_to(live.origin) > EPS or event.origin.distance_to(sim.hero.position) > EPS or event.destination.distance_to(target.position) > EPS or not is_equal_approx(float(event.duration), float(live.duration)) or int(event.strike) != int(live.count) + 1:
  _fail("wind_q2_strike_geometry_source_mismatch")
  return {}
 if int(live.cast_id) != int(event.cast_id) or str(live.target_id) != str(event.target_id) or int(live.generation) != int(_scope.generation):
  _fail("wind_q2_strike_source_mismatch")
  return {}
 # Zero-length H04 repeat is legal. Facing is pose-only, not synthetic movement.
 var direction: Vector3 = event.origin.direction_to(event.destination)
 if not _direction(direction):
  direction = sim.hero.facing
 if not _direction(direction):
  _fail("wind_q2_facing_invalid")
  return {}
 state.direction = direction
 state.strike = int(event.strike)
 state.target_id = str(event.target_id)
 state.stages["q2_strike:%d" % int(event.strike)] = true
 state.paths.append({"strike":event.strike, "target_id":event.target_id, "sequence":event.sequence, "hero_time":event.hero_time, "duration":event.duration, "points":[event.origin], "completed_at":-1.0})
 var pose: Dictionary = event.duplicate(true)
 pose["direction"] = direction
 pose["animation"] = {"time_domain":"hero", "contact_after":float(event.duration), "recovery":0.0}
 pose["pose_prefix"] = "q2"
 return pose

func sample_q2(sim: Node) -> void:
 if not _sync_scope(sim) or sim.phase != "combat" or sim.hero.dead or not sim.hero.cast_state.has("q2"):
  return
 var value: Variant = sim.hero.cast_state.q2
 if not value is Dictionary:
  _fail("wind_q2_sample_schema_invalid")
  return
 var live: Dictionary = value
 if not _integer(live.get("cast_id"), 1) or not casts.has(int(live.cast_id)) or not sim.cast_is_current(int(live.cast_id)):
  return
 var state: Dictionary = casts[int(live.cast_id)]
 if str(state.source) != "q2" or state.paths.is_empty() or bool(state.finished):
  return
 if not _point(sim.hero.position):
  _fail("wind_q2_sample_invalid")
  return
 var path: Dictionary = state.paths.back()
 # Only observed source positions. No interpolation to the planned destination.
 if path.points.back().distance_squared_to(sim.hero.position) > EPS:
  if path.points.size() >= MAX_PATH_POINTS:
   path.points.remove_at(1)
  path.points.append(sim.hero.position)

func _finish_q2_visual(event: Dictionary) -> void:
 if not _integer(event.get("cast_id"), 1) or not casts.has(int(event.cast_id)):
  return
 var state: Dictionary = casts[int(event.cast_id)]
 if str(state.source) != "q2":
  return
 if bool(event.get("cancelled", false)):
  _drop_cast(int(event.cast_id))
  return
 state.finished = true
 # The final actual damage burst belongs to this tick and must remain visible.
 # End positional trails immediately; behind-target landing is not a strike path.
 state.paths.clear()

func accept(event: Dictionary, sim: Node) -> Dictionary:
 # The empty return deliberately assigns NO asset pose and mutates NO animation.
 if not _sync_scope(sim) or not _event_current(event, sim):
  return {}
 if (str(event.get("kind", "")).begins_with("e2_") or str(event.get("source", "")) in ["e2", "e2_extra"]) and sim.has_method("bind_route_identity") and str(event.get("run_id", "")) != str(sim.get("route_run_id")):
  return {}
 var sequence: int = int(event.sequence)
 if sequence <= last_sequence:
  return {}
 last_sequence = sequence
 var kind: String = str(event.get("kind", ""))
 if kind == "encounter_finished":
  r1_star.clear()
  _e3_activation.clear()
  _e3_save.clear()
  shapes.clear()
  bursts.clear()
  casts.clear()
  return {}
 if kind == "q2_finished":
  _finish_q2_visual(event)
  return {}
 if kind == "attack_cancelled":
  var cancelled: Variant = event.get("cast_ids")
  if not cancelled is Array or cancelled.size() > MAX_CASTS:
   _fail("wind_cancelled_cast_ids_invalid")
   return {}
  for id: Variant in cancelled:
   if not _integer(id, 1):
    _fail("wind_cancelled_cast_id_invalid")
    return {}
  for id: Variant in cancelled:
   if casts.has(int(id)) and str(casts[int(id)].source) == "attack":
    _drop_cast(int(id))
  return {}
 if kind in ["r1_cancelled", "r1_finished"]:
  if _integer(event.get("cast_id"), 1):
   _drop_cast(int(event.cast_id))
  return {}
 if sim.phase != "combat" or sim.hero.dead:
  return {}
 if kind in ["e3_started", "e3_extended", "e3_ended", "e3_death_prevented"]:
  _accept_e3(event, sim)
  return {}
 if kind.begins_with("e2_"):
  return _accept_e2(event, sim)
 if kind == "damage":
  _accept_damage(event, sim)
  return {}
 if kind in ["attack_started", "dash_attack_started"]:
  _open_cast(event, "attack" if kind == "attack_started" else "dash_attack", sim)
  return {}
 if kind == "q3_expired":
  if _integer(event.get("cast_id"), 1) and casts.has(int(event.cast_id)):
   var ended: Dictionary = casts[int(event.cast_id)]
   if str(ended.source) == "q3" and str(event.get("id", "")) == str(ended.get("wave_id", "")):
    # Core erases before emitting expiry. An event cannot hide a still-live wave.
    var still_live: bool = false
    for value: Variant in sim.wind_projectiles:
     if value is Dictionary and str(value.get("id", "")) == str(event.id) and int(value.get("cast_id", -1)) == int(event.cast_id):
      still_live = true
    if not still_live:
     ended["expired"] = true
  return {}
 if kind == "q3_started":
  if not _geometry(event) or not _timing(event):
   _fail("wind_q3_start_invalid")
   return {}
  if _open_cast(event, "q3", sim):
   casts[int(event.cast_id)].merge({"length":event.length, "width":event.width, "wave_id":"", "expired":false}, true)
  return {}
 if kind == "q3_launched":
  if not _cast_valid(event, sim) or not casts.has(int(event.cast_id)):
   return {}
  var launched: Dictionary = casts[int(event.cast_id)]
  if str(launched.source) != "q3" or not _text(event.get("id")):
   return {}
  if not str(launched.wave_id).is_empty():
   return {}
  var wave: Dictionary = _q3_wave(sim, int(event.cast_id), str(event.id))
  if wave.is_empty() or not _point(event.get("position")) or event.position != wave.position or not _direction(event.get("direction")) or event.direction != wave.direction or not _number(event.get("width"), EPS, MAX_WIDTH) or not is_equal_approx(float(event.width), float(wave.width)):
   _fail("wind_q3_launch_source_mismatch")
   return {}
  launched.wave_id = event.id
  return {}
 if kind == "q2_started":
  _open_q2(event, sim)
  return {}
 if kind == "q2_strike_started":
  return _q2_strike_start(event, sim)
 if kind == "q1_started":
  if not _geometry(event) or not _timing(event):
   _fail("wind_q1_start_geometry_invalid")
   return {}
  if _open_cast(event, "q1", sim):
   casts[int(event.cast_id)]["length"] = event.length
   casts[int(event.cast_id)]["width"] = event.width
   _append_shape(event, "hero", sim)
  return {}
 if kind == "e1_started":
  if not _timing(event) or not _text(event.get("target_id")):
   _fail("wind_e1_start_invalid")
   return {}
  if _open_cast(event, "e1", sim):
   casts[int(event.cast_id)]["target_id"] = event.target_id
  return {}
 if kind == "r1_started":
  if not _geometry(event, true) or not _timing(event) or not is_equal_approx(float(event.duration), 1.6) or not is_equal_approx(float(event.contact_after), 1.1):
   _fail("wind_r1_source_contract_invalid")
   return {}
  if _open_cast(event, "r1", sim):
   casts[int(event.cast_id)]["radius"] = event.radius
   casts[int(event.cast_id)]["duration"] = event.duration
   casts[int(event.cast_id)]["contact_after"] = event.contact_after
  return {}
 if kind not in ["q1_impact", "e1_pierce_started", "r1_impact"]:
  return {}
 if not _cast_valid(event, sim) or not casts.has(int(event.cast_id)):
  return {}
 var state: Dictionary = casts[int(event.cast_id)]
 if kind == "q1_impact" and str(state.source) == "q1":
  if not _geometry(event) or not is_equal_approx(float(event.length), float(state.length)) or not is_equal_approx(float(event.width), float(state.width)):
   _fail("wind_q1_impact_geometry_invalid")
   return {}
  if _once(event, kind):
   shapes = shapes.filter(func(e: Dictionary) -> bool: return int(e.cast_id) != int(event.cast_id))
   _append_shape(event, "hero", sim)
 elif kind == "e1_pierce_started" and str(state.source) == "e1":
  if not _point(event.get("origin")) or not _point(event.get("destination")) or not _direction(event.get("direction")) or not _number(event.get("width"), EPS, MAX_WIDTH) or not _number(event.get("duration"), EPS, 2.0) or str(event.get("target_id", "")) != str(state.target_id):
   _fail("wind_e1_pierce_start_invalid")
   return {}
  if _once(event, kind):
   state.direction = event.direction
   # The accepted destination is NOT a rendered path. Only live points are drawn.
 elif kind == "r1_impact" and str(state.source) == "r1":
  if not _geometry(event, true) or not is_equal_approx(float(event.radius), float(state.radius)):
   _fail("wind_r1_impact_geometry_invalid")
   return {}
  if _once(event, kind):
   state["impact_real_time"] = event.real_time
   _append_shape(event, "real", sim)
 return {}

func _accept_damage(event: Dictionary, sim: Node) -> void:
 var source: String = str(event.get("source", ""))
 if source not in ["attack", "dash_attack", "q1", "q2", "q3", "e1_dagger", "e1_pierce", "e2", "e2_extra", "r1", "overload_true"] or str(event.get("target", "")) == HERO_ID or bool(event.get("replay", false)) or bool(event.get("hex_generated", false)):
  return
 if not _number(event.get("amount"), 0.0, 1e12):
  _fail("wind_damage_amount_invalid")
  return
 if float(event.amount) <= 0.0 or not _cast_valid(event, sim) or not casts.has(int(event.cast_id)):
  return
 var state: Dictionary = casts[int(event.cast_id)]
 var expected: String = "e1" if source in ["e1_dagger", "e1_pierce"] else "e2" if source == "e2_extra" else source
 if source == "overload_true":
  # The core's public damage schema intentionally omits no_reactions. Validate
  # its actual per-target e3_true claim instead of requiring invented metadata.
  var key: String = "%d:%d:e3_true:%s" % [sim.encounter_generation, int(event.cast_id), str(event.get("target", ""))]
  if str(state.source) not in ["attack", "dash_attack"] or str(event.get("damage_type", "")) != "true" or not bool(event.get("basic_attack", false)) or _live_e3(sim).is_empty() or not sim._hit_claims.has(key):
   return
  expected = str(state.source)
 if str(state.source) != expected or (source == "e1_pierce" and not state.stages.has("e1_pierce_started")):
  return
 if not _text(event.get("target")) or not sim.enemies is Array or sim.enemies.size() > MAX_ENEMIES:
  _fail("wind_damage_target_invalid")
  return
 if absf(float(event.real_time) - float(sim.real_time)) > EPS or absf(float(event.world_time) - float(sim.clock.world_time)) > EPS:
  _fail("wind_damage_requires_synchronous_accept")
  return
 var target: Dictionary = sim.enemy_by_id(str(event.target))
 # combat_event is synchronous, emitted before lethal removal. Capture the actual
 # enemy now, never use a cast origin/source_position as an impact location.
 if target.is_empty() or str(target.get("actor_id", "")) != str(event.target) or not _integer(target.get("generation")) or int(target.generation) != int(_scope.generation) or str(target.get("room_id", "")) != str(_scope.room_id) or not _point(target.get("position")):
  _fail("wind_damage_target_scope_invalid")
  return
 if source == "q3":
  var wave: Dictionary = _q3_wave(sim, int(event.cast_id), str(state.get("wave_id", "")))
  # Damage is emitted synchronously after the core records the real target hit.
  # A contact-only event, stale wave, or replay never creates an impact burst.
  if wave.is_empty() or str(event.target) not in wave.hit_ids:
   return
 var occurrence: int = 0
 if source == "q2":
  if not _integer(event.get("occurrence"), 1) or int(event.occurrence) != int(state.strike) or str(event.target) != str(state.target_id):
   _fail("wind_q2_damage_occurrence_invalid")
   return
  occurrence = int(event.occurrence)
  sample_q2(sim)
  if not state.paths.is_empty():
   state.paths.back().completed_at = float(sim.hero_time)
 if source in ["e2", "e2_extra"]:
  if not _integer(event.get("occurrence"), 1) or int(event.occurrence) != int(state.get("occurrence", 0)) or str(state.get("phase", "")) != ("initial" if source == "e2" else "extra"):
   return
  occurrence = int(event.occurrence)
  var hit_key: String = "%d:%d:e2:%d:%s" % [sim.encounter_generation, int(event.cast_id), occurrence, str(event.target)]
  if not sim._hit_claims.has(hit_key):return
 var claim: String = "%s|%s|%d" % [source, event.target, occurrence]
 if state.claims.has(claim):
  return
 if state.claims.size() >= MAX_TARGETS_PER_CAST:
  _fail("wind_damage_target_bound_exceeded")
  return
 var direction: Vector3 = event.direction if _direction(event.get("direction")) else state.direction
 if not _direction(direction):
  _fail("wind_damage_direction_invalid")
  return
 state.claims[claim] = true
 if bursts.size() >= MAX_BURSTS:
  bursts.pop_front()
 bursts.append({"sequence":event.sequence, "cast_id":event.cast_id, "target":event.target, "source":source, "occurrence":occurrence, "position":target.position, "position_authority":"synchronous_enemy_by_id", "direction":direction, "amount":event.amount, "world_time":event.world_time, "real_time":event.real_time, "hero_time":event.get("hero_time", sim.hero_time), "domain":"real" if source in ["r1", "dash_attack"] or (source == "overload_true" and str(state.source) == "dash_attack") else "world" if source in ["e1_dagger", "q3", "e2", "e2_extra"] else "hero"})

func _screen(point: Vector2) -> bool:
 return point.is_finite() and absf(point.x) <= 1e6 and absf(point.y) <= 1e6

func _project(view: Node2D, points: Array) -> PackedVector2Array:
 var result := PackedVector2Array()
 if not error.is_empty():
  return result
 if points.size() > 64:
  _fail("wind_geometry_vertex_bound_exceeded")
  return result
 for point: Variant in points:
  if not _point(point):
   _fail("wind_world_geometry_invalid")
   return PackedVector2Array()
  var projected: Vector2 = view.p(point)
  if not _screen(projected):
   _fail("wind_projection_nonfinite_or_unbounded")
   return PackedVector2Array()
  result.append(projected)
 return result

func _polygon(view: Node2D, points: Array, color: Color) -> void:
 var projected: PackedVector2Array = _project(view, points)
 if projected.size() >= 3 and error.is_empty():
  view.draw_colored_polygon(projected, color)

func _line(view: Node2D, a: Vector3, b: Vector3, color: Color, width: float) -> void:
 var points: PackedVector2Array = _project(view, [a, b])
 if points.size() == 2 and error.is_empty():
  view.draw_line(points[0], points[1], color, width, true)

func _ring(view: Node2D, at: Vector3, radius: float, color: Color, width: float) -> void:
 var world: Array = []
 if not _point(at) or not _number(radius, EPS, MAX_RADIUS):
  _fail("wind_ring_invalid")
  return
 for index: int in range(49):
  var angle: float = TAU * float(index) / 48.0
  world.append(at + Vector3(cos(angle), 0.0, sin(angle)) * radius)
 var points: PackedVector2Array = _project(view, world)
 if points.size() == 49 and error.is_empty():
  view.draw_polyline(points, color, width, true)

func _rectangle(view: Node2D, origin: Vector3, direction: Vector3, length: float, width: float, alpha: float, released: bool) -> void:
 var forward: Vector3 = direction.normalized()
 var side := Vector3(-forward.z, 0.0, forward.x)
 var end: Vector3 = origin + forward * length
 var half: Vector3 = side * width * 0.5
 _polygon(view, [origin - half, end - half, end + half, origin + half], Color(0.12, 0.66, 1.0, 0.10 * alpha))
 _line(view, origin - half, end - half, Color(0.22, 0.76, 1.0, 0.36 * alpha), 1.2)
 _line(view, origin + half, end + half, Color(0.22, 0.76, 1.0, 0.36 * alpha), 1.2)
 if not released:
  _line(view, end - half, end + half, Color(0.48, 0.90, 1.0, 0.48 * alpha), 1.4)
  return
 # Unequal tapered triangles, all inside the actual source rectangle.
 for spec: Vector3 in [Vector3(0.08, 0.95, -0.24), Vector3(0.23, 0.82, 0.22), Vector3(0.40, 1.0, 0.02)]:
  var lane: Vector3 = side * width * spec.z
  _polygon(view, [origin + forward * length * spec.x + lane - side * width * 0.11, origin + forward * length * spec.y + lane, origin + forward * length * (spec.x + 0.11) + lane + side * width * 0.10], Color(0.27, 0.89, 1.0, 0.78 * alpha))
 _line(view, origin + forward * length * 0.36, end, Color(0.86, 0.99, 1.0, 0.90 * alpha), 2.2)

func _age(event: Dictionary, sim: Node) -> float:
 if str(event.domain) == "real":
  return float(sim.real_time) - float(event.real_time)
 if str(event.domain) == "hero":
  return float(sim.hero_time) - float(event.hero_time)
 return float(sim.clock.world_time) - float(event.world_time)

func _describe(event: Dictionary, age: float) -> Dictionary:
 return {"kind":event.kind, "cast_id":event.cast_id, "cast_identity":_identity(int(event.cast_id)), "sequence":event.sequence, "age":age, "time_domain":event.domain, "position":event.position, "empty_release_allowed":true, "damage_authority":false}

func draw_ground(view: Node2D, sim: Node) -> void:
 if not _sync_scope(sim):
  view._visual_error(error)
  return
 receipt = {"scope":_scope.duplicate(true), "source_time":sim.clock.world_time, "real_time":sim.real_time, "hero_time":sim.hero_time, "ground_plane_y":0.0, "default_skills":[], "bursts":[], "r1_star_visual":{}, "poses_assigned":false, "source_mutations":false, "guard_flash":false, "required_enemy_telegraph_order":"after_player_ground"}
 if sim.phase != "combat" or sim.hero.dead:
  r1_star.clear()
  return
 var retained: Array = []
 for event: Dictionary in shapes:
  var age: float = _age(event, sim)
  var lifetime: float = float(event.contact_after) if event.kind == "q1_started" else RELEASE_LIFE
  if age < -EPS:
   _fail("wind_shape_clock_reversed")
   break
  if age < lifetime:
   retained.append(event)
 shapes = retained
 for event: Dictionary in shapes:
  var age: float = maxf(0.0, _age(event, sim))
  var alpha: float = 1.0 if event.kind == "q1_started" else 1.0 - age / RELEASE_LIFE
  var star_release: Dictionary = {}
  if event.kind in ["q1_started", "q1_impact"]:
   var origin: Vector3 = sim.hero.position if event.kind == "q1_started" else event.position
   _rectangle(view, origin, event.direction, float(event.length), float(event.width), alpha, event.kind == "q1_impact")
  elif event.kind == "r1_impact":
   # Only this accepted source impact drives the one outward wind release.
   # It has no contact logic; actual per-target damage still owns hit peaks.
   star_release = r1_star.draw_release(view, event, age)
  var item: Dictionary = _describe(event, age)
  if event.kind == "q1_started":
   item["position"] = sim.hero.position
   item["origin_authority"] = "live_hero_preview_only_contact_event_owns_release"
  item["shape"] = "circle" if event.kind == "r1_impact" else "rectangle"
  item["length"] = event.length
  item["width"] = event.width
  item["radius"] = event.radius
  item["direction"] = event.direction
  if event.kind == "r1_impact":
   item["star_release"] = star_release
  receipt.default_skills.append(item)
 _draw_q2(view, sim)
 _draw_q3(view, sim)
 _draw_live_e1(view, sim)
 _draw_e2(view, sim)
 _draw_live_r1(view, sim)
 if not error.is_empty():
  view._visual_error(error)

# Q3 rendering follows the current real wave, never its future range rectangle.
func _q3_wave(sim: Node, id: int, wave_id: String) -> Dictionary:
 if wave_id.is_empty() or not sim.wind_projectiles is Array or sim.wind_projectiles.size() > MAX_PROJECTILES:
  return {}
 for value: Variant in sim.wind_projectiles:
  if not value is Dictionary:
   continue
  var wave: Dictionary = value
  if str(wave.get("type", "")) != "sword_wave" or str(wave.get("id", "")) != wave_id or int(wave.get("cast_id", -1)) != id:
   continue
  if not sim.effect_is_current(wave) or int(wave.get("generation", -1)) != int(_scope.generation) or str(wave.get("room_id", "")) != str(_scope.room_id):
   return {}
  if not _point(wave.get("position")) or not _point(wave.get("origin")) or not _direction(wave.get("direction")) or not _number(wave.get("width"), EPS, MAX_WIDTH) or not _number(wave.get("travelled"), 0.0, MAX_LENGTH) or not _number(wave.get("remaining"), 0.0, MAX_LENGTH) or not wave.get("hit_ids") is Array:
   _fail("wind_q3_live_geometry_invalid")
   return {}
  var state: Dictionary = casts.get(id, {})
  if state.is_empty() or str(state.source) != "q3" or bool(state.get("expired", false)) or not is_equal_approx(float(wave.width), float(state.width)) or not is_equal_approx(float(wave.travelled) + float(wave.remaining), float(state.length)):
   _fail("wind_q3_live_contract_mismatch")
   return {}
  return wave
 return {}

func _draw_q3(view: Node2D, sim: Node) -> void:
 for id: int in casts:
  var state: Dictionary = casts[id]
  if str(state.source) != "q3" or not sim.cast_is_current(id) or bool(state.get("expired", false)):
   continue
  var wave: Dictionary = _q3_wave(sim, id, str(state.get("wave_id", "")))
  if wave.is_empty():
   continue
  var forward: Vector3 = wave.direction.normalized()
  var side := Vector3(-forward.z, 0.0, forward.x)
  var half: float = float(wave.width) * 0.5
  # Stylized curved front stays at or behind the actual collision front. Its
  # rearward depth never exceeds distance already travelled, including launch.
  var depth: float = minf(0.45, float(wave.travelled))
  var world: Array = []
  for index: int in range(13):
   var lateral: float = float(index) / 6.0 - 1.0
   world.append(wave.position + side * half * lateral - forward * depth * lateral * lateral)
  var points: PackedVector2Array = _project(view, world)
  if points.size() != 13:
   return
  view.draw_polyline(points, Color(0.04, 0.13, 0.25, 0.95), 7.0, true)
  view.draw_polyline(points, Color(0.12, 0.94, 0.85, 0.95), 4.5, true)
  view.draw_polyline(points, Color(0.91, 1.0, 0.83, 1.0), 1.5, true)
  receipt.default_skills.append({"kind":"q3_actual_wave_front", "cast_id":id, "cast_identity":_identity(id), "projectile_id":wave.id, "position":wave.position, "direction":wave.direction, "width":wave.width, "travelled":wave.travelled, "remaining":wave.remaining, "world_points":world.duplicate(), "geometry_authority":"live_wind_projectile", "time_domain":"world", "future_path_rendered":false, "damage_authority":false})

func _draw_q2(view: Node2D, sim: Node) -> void:
 sample_q2(sim)
 if not error.is_empty():
  return
 for id: int in casts:
  var state: Dictionary = casts[id]
  if str(state.source) != "q2" or bool(state.get("finished", false)) or not sim.cast_is_current(id):
   continue
  for path: Dictionary in state.paths:
   var completed: float = float(path.completed_at)
   var age: float = maxf(0.0, float(sim.hero_time) - completed) if completed >= 0.0 else 0.0
   if completed >= 0.0 and age >= RELEASE_LIFE:
    continue
   var alpha: float = 1.0 - age / RELEASE_LIFE if completed >= 0.0 else 1.0
   var points: Array = path.points
   # Cosmetic width only: the centerline is exclusively already observed motion.
   _q2_blade_trail(view, points, alpha)
   receipt.default_skills.append({"kind":"q2_actual_strike_path", "cast_id":id, "cast_identity":_identity(id), "strike":path.strike, "target":path.target_id, "points":points.duplicate(), "geometry_authority":"observed_live_hero_positions", "time_domain":"hero", "age":age, "planned_destination_rendered":false, "damage_authority":false})
  if sim.hero.cast_state.has("q2") and int(sim.hero.cast_state.q2.get("cast_id", -1)) == id:
   var target: Dictionary = sim.enemy_by_id(str(state.target_id))
   if target.is_empty() or target.dead or not _point(target.position):
    continue
   var at: Vector2 = view.p(target.position) + Vector2(0, -31)
   if not _screen(at):
    _fail("wind_q2_target_projection_invalid")
    return
   # Small current-target brackets only, never an area or a hit indicator.
   for side: float in [-1.0, 1.0]:
    view.draw_polyline(PackedVector2Array([at + Vector2(side * 13, -6), at + Vector2(side * 17, 0), at + Vector2(side * 13, 6)]), Color("40edee"), 2.0, true)
   receipt.default_skills.append({"kind":"q2_current_target", "cast_id":id, "strike":state.strike, "target":state.target_id, "position":target.position, "damage_authority":false})

# Screen-space brush around observed ground positions. No endpoints are extrapolated;
# subdivision is confined to each already travelled segment and never uses destination.
func _q2_blade_trail(view: Node2D, world: Array, alpha: float) -> void:
 if world.size() < 2:
  return
 var observed: PackedVector2Array = _project(view, world)
 if observed.size() != world.size() or not error.is_empty():
  return
 var centers := PackedVector2Array([observed[0]])
 var distances: Array[float] = [0.0]
 var length: float = 0.0
 for index: int in range(1, observed.size()):
  var a: Vector2 = observed[index - 1]
  var b: Vector2 = observed[index]
  var segment: float = a.distance_to(b)
  if segment <= EPS:
   continue
  var steps: int = clampi(int(ceil(segment / 12.0)), 2, 32)
  for step: int in range(1, steps + 1):
   centers.append(a.lerp(b, float(step) / float(steps)))
   distances.append(length + segment * float(step) / float(steps))
  length += segment
 if length < 2.0 or centers.size() < 2:
  return
 # Dark ink edge, saturated turquoise body, narrow warm-white blade. Width stays
 # below one character foot, tapers to zero at both actual sampled endpoints.
 var width: float = minf(6.5, length * 0.09)
 _q2_ribbon(view, centers, distances, length, width + 1.8, Color(0.07, 0.12, 0.27, alpha * 0.92))
 _q2_ribbon(view, centers, distances, length, width, Color(0.08, 0.93, 0.88, alpha * 0.92))
 _q2_ribbon(view, centers, distances, length, width * 0.38, Color(0.91, 1.0, 0.80, alpha))

func _q2_ribbon(view: Node2D, centers: PackedVector2Array, distances: Array[float], length: float, width: float, color: Color) -> void:
 # Draw convex pieces rather than one ribbon polygon: real path reversals may
 # overlap their own trail, but must never create a self-intersecting polygon.
 for index: int in range(1, centers.size()):
  var a: Vector2 = centers[index - 1]
  var b: Vector2 = centers[index]
  if a.distance_squared_to(b) <= EPS:
   continue
  var tangent: Vector2 = a.direction_to(b)
  var normal := Vector2(-tangent.y, tangent.x)
  var ta: float = distances[index - 1] / length
  var tb: float = distances[index] / length
  var wa: float = width * pow(maxf(0.0, sin(PI * ta)), 0.65) * (0.60 + 0.40 * ta)
  var wb: float = width * pow(maxf(0.0, sin(PI * tb)), 0.65) * (0.60 + 0.40 * tb)
  var polygon := PackedVector2Array()
  if wa <= EPS:
   polygon = PackedVector2Array([a, b + normal * wb, b - normal * wb])
  elif wb <= EPS:
   polygon = PackedVector2Array([a + normal * wa, b, a - normal * wa])
  else:
   polygon = PackedVector2Array([a + normal * wa, b + normal * wb, b - normal * wb, a - normal * wa])
  if wa <= EPS and wb <= EPS:
   continue
  if not Geometry2D.triangulate_polygon(polygon).is_empty():
   view.draw_colored_polygon(polygon, color)
   continue
  # Screen-space float32 arithmetic can collapse tapered caps or lose area
  # precision far from the origin. Repair only this failed convex segment,
  # in local coordinates; never take a hull of the entire observed path.
  var local := PackedVector2Array()
  for point: Vector2 in polygon:
   local.append(point - a)
  local = Geometry2D.convex_hull(local)
  if local.size() > 1 and local[0] == local[local.size() - 1]:
   local.resize(local.size() - 1)
  if local.size() < 3:
   continue
  var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(local)
  # Only locally degenerate/subpixel slivers are omitted. Explicit triangles
  # avoid repeating the failing global-coordinate Canvas triangulation.
  for triangle: int in range(0, triangles.size(), 3):
   var points := PackedVector2Array([local[triangles[triangle]] + a, local[triangles[triangle + 1]] + a, local[triangles[triangle + 2]] + a])
   view.draw_primitive(points, PackedColorArray([color, color, color]), PackedVector2Array())

# Called only from an existing accepted positive-damage burst, including H04's
# separate occurrence at zero displacement. These marks are never area telegraphs.
func _q2_hit_blade(view: Node2D, at: Vector2, along: Vector2, alpha: float, occurrence: int) -> void:
 var side := Vector2(-along.y, along.x)
 var handed: float = -1.0 if occurrence % 2 == 0 else 1.0
 var center: Vector2 = at + Vector2(0, -8)
 for layer: int in range(3):
  var radius: float = 23.0 - float(layer) * 1.5
  var thickness: float = [7.0, 5.0, 1.8][layer]
  var color: Color = [Color(0.06, 0.12, 0.26, alpha), Color(0.10, 0.94, 0.87, alpha), Color(0.96, 1.0, 0.82, alpha)][layer]
  var outer := PackedVector2Array()
  var inner := PackedVector2Array()
  for index: int in range(13):
   var t: float = float(index) / 12.0
   var angle: float = lerpf(-1.25, 1.05, t)
   var radial: Vector2 = along * cos(angle) + side * sin(angle) * handed
   var taper: float = sin(PI * t)
   outer.append(center + radial * radius)
   inner.append(center + radial * (radius - thickness * taper))
  var blade: PackedVector2Array = outer
  for index: int in range(inner.size() - 2, 0, -1):
   blade.append(inner[index])
  view.draw_colored_polygon(blade, color)
 # Two small tapered impact cuts; independent of travel length, with no added hit.
 for sign: float in [-1.0, 1.0]:
  var direction: Vector2 = (along * -0.55 + side * sign).normalized()
  var normal := Vector2(-direction.y, direction.x)
  var start: Vector2 = center + direction * 9.0
  var end: Vector2 = center + direction * 20.0
  view.draw_colored_polygon(PackedVector2Array([start + normal * 2.2, end, start - normal * 2.2]), Color(0.94, 1.0, 0.77, alpha))

func _live_e1(sim: Node) -> Dictionary:
 if not sim.hero.cast_state.has("e1"):
  return {}
 var value: Variant = sim.hero.cast_state.e1
 if not value is Dictionary or not _integer(value.get("cast_id"), 1) or not _integer(value.get("generation")) or int(value.generation) != int(_scope.generation) or str(value.get("room_id", "")) != str(_scope.room_id):
  _fail("wind_e1_live_scope_invalid")
  return {}
 if not casts.has(int(value.cast_id)) or str(casts[int(value.cast_id)].source) != "e1" or not sim.cast_is_current(int(value.cast_id)):
  return {}
 return value

func _draw_live_e1(view: Node2D, sim: Node) -> void:
 var state: Dictionary = _live_e1(sim)
 if state.is_empty() or not error.is_empty():
  return
 if not sim.wind_projectiles is Array or sim.wind_projectiles.size() > MAX_PROJECTILES:
  _fail("wind_projectile_bound_exceeded")
  return
 for value: Variant in sim.wind_projectiles:
  if not value is Dictionary:
   _fail("wind_projectile_type_invalid")
   return
  var projectile: Dictionary = value
  if str(projectile.get("type", "")) != "dagger":
   continue
  if not _integer(projectile.get("cast_id"), 1) or int(projectile.cast_id) != int(state.cast_id):
   continue
  if str(state.get("phase", "")) != "flight" or not _integer(projectile.get("generation")) or int(projectile.generation) != int(_scope.generation) or str(projectile.get("room_id", "")) != str(_scope.room_id) or str(projectile.get("target_id", "")) != str(state.get("target_id", "")) or not _point(projectile.get("position")) or not _point(projectile.get("origin")) or not _point(projectile.get("direction")) or not _text(projectile.get("id")):
   _fail("wind_dagger_live_state_invalid")
   return
  if not _direction(projectile.direction):
   continue # Valid coincident spawn: source resolves direction on its next step.
  var at: Vector3 = projectile.position
  var forward: Vector3 = projectile.direction.normalized()
  var side := Vector3(-forward.z, 0.0, forward.x)
  # Small authored body only, never an interpolated flight, long trail, or hit.
  _polygon(view, [at + forward * 0.25, at - forward * 0.18 - side * 0.09, at - forward * 0.08, at - forward * 0.18 + side * 0.09], Color(0.62, 0.97, 1.0, 0.96))
  _line(view, at - forward * 0.18, at + forward * 0.18, Color(0.14, 0.59, 0.98, 0.95), 2.0)
  receipt.default_skills.append({"kind":"e1_actual_dagger", "cast_id":state.cast_id, "cast_identity":_identity(int(state.cast_id)), "projectile_id":projectile.id, "position":at, "direction":projectile.direction, "target":projectile.target_id, "geometry_authority":"wind_projectiles", "time_domain":"world", "damage_authority":false})
 if sim.hero.cast_state.has("e1_mark"):
  _draw_mark(view, sim, state)
 if sim.hero.cast_state.has("e1_pierce"):
  _draw_pierce(view, sim, state)

func _draw_mark(view: Node2D, sim: Node, state: Dictionary) -> void:
 var value: Variant = sim.hero.cast_state.e1_mark
 if not value is Dictionary or not _integer(value.get("cast_id"), 1) or int(value.cast_id) != int(state.cast_id) or not _integer(value.get("generation")) or int(value.generation) != int(_scope.generation) or str(value.get("room_id", "")) != str(_scope.room_id) or str(value.get("target_id", "")) != str(state.get("target_id", "")) or not _number(value.get("until"), 0.0, 1e12):
  _fail("wind_mark_live_state_invalid")
  return
 var remaining: float = maxf(0.0, float(value.until) - float(sim.hero_time))
 if remaining <= EPS:
  return
 if not sim.enemies is Array or sim.enemies.size() > MAX_ENEMIES:
  _fail("wind_mark_target_bound_exceeded")
  return
 var target: Dictionary = sim.enemy_by_id(str(value.target_id))
 if target.is_empty() or bool(target.get("dead", true)) or str(target.get("state", "")) == "spawn":
  return
 if not _integer(target.get("generation")) or int(target.generation) != int(_scope.generation) or str(target.get("room_id", "")) != str(_scope.room_id) or not _point(target.get("position")) or not _number(target.get("radius"), EPS, 8.0):
  _fail("wind_mark_target_geometry_invalid")
  return
 var at: Vector3 = target.position
 var radius: float = float(target.radius) + 0.15
 # A small four-corner target bracket, NOT a damage area or automatic recast.
 for index: int in range(4):
  var angle: float = TAU * float(index) / 4.0 + PI * 0.25
  var d := Vector3(cos(angle), 0.0, sin(angle))
  var side := Vector3(-d.z, 0.0, d.x)
  _line(view, at + d * radius - side * 0.14, at + d * (radius + 0.13), Color(0.30, 0.88, 1.0, 0.94), 2.0)
  _line(view, at + d * (radius + 0.13), at + d * radius + side * 0.14, Color(0.30, 0.88, 1.0, 0.94), 2.0)
 receipt.default_skills.append({"kind":"e1_actual_mark", "cast_id":state.cast_id, "cast_identity":_identity(int(state.cast_id)), "target":value.target_id, "position":at, "remaining":remaining, "time_domain":"hero", "manual_second_press_required":true, "damage_authority":false})

func _draw_pierce(view: Node2D, sim: Node, state: Dictionary) -> void:
 var value: Variant = sim.hero.cast_state.e1_pierce
 if not value is Dictionary or not _integer(value.get("cast_id"), 1) or int(value.cast_id) != int(state.cast_id) or str(state.get("phase", "")) != "pierce" or not casts[int(state.cast_id)].stages.has("e1_pierce_started") or not _number(value.get("width"), EPS, MAX_WIDTH) or not _number(value.get("duration"), EPS, 2.0) or not _number(value.get("elapsed"), 0.0, float(value.duration) + EPS) or not value.get("points") is Array:
  _fail("wind_pierce_live_state_invalid")
  return
 var points: Array = value.points
 if points.is_empty() or points.size() > MAX_PATH_POINTS:
  _fail("wind_pierce_path_bound_exceeded")
  return
 for point: Variant in points:
  if not _point(point):
   _fail("wind_pierce_path_point_invalid")
   return
 for index: int in range(1, points.size()):
  var previous: Vector3 = points[index - 1]
  var delta: Vector3 = points[index] - previous
  if delta.length_squared() <= EPS:
   continue
  if delta.length() > MAX_LENGTH:
   _fail("wind_pierce_segment_bound_exceeded")
   return
  _rectangle(view, previous, delta.normalized(), delta.length(), float(value.width), 0.72, true)
 receipt.default_skills.append({"kind":"e1_actual_pierce_path", "cast_id":state.cast_id, "cast_identity":_identity(int(state.cast_id)), "points":points.duplicate(), "width":value.width, "elapsed":value.elapsed, "duration":value.duration, "geometry_authority":"e1_pierce.points", "time_domain":"hero", "planned_destination_rendered":false, "damage_authority":false})

# Bounded open polylines only: no self-intersecting filled geometry.
func _r1_boundary(view: Node2D, at: Vector3, radius: float, alpha: float) -> void:
 for dash: int in range(16):
  var start: float = TAU * float(dash) / 16.0
  for part: int in range(3):
   var a: float = start + (float(part) / 3.0) * TAU / 16.0 * 0.42
   var b: float = start + (float(part + 1) / 3.0) * TAU / 16.0 * 0.42
   _line(view, at + Vector3(cos(a), 0.0, sin(a)) * radius, at + Vector3(cos(b), 0.0, sin(b)) * radius, Color(0.24, 0.70, 1.0, alpha), 1.0)

func _r1_slash(view: Node2D, at: Vector3, angle: float, half_length: float, alpha: float, impact: bool) -> void:
 if alpha <= EPS or half_length <= EPS:
  return
 var d := Vector3(cos(angle), 0.0, sin(angle))
 var side := Vector3(-d.z, 0.0, d.x)
 for segment: int in range(8):
  var u: float = float(segment) / 8.0
  var v: float = float(segment + 1) / 8.0
  var a: Vector3 = at + d * half_length * (2.0 * u - 1.0) + side * half_length * 0.36 * sin(u * PI)
  var b: Vector3 = at + d * half_length * (2.0 * v - 1.0) + side * half_length * 0.36 * sin(v * PI)
  var taper: float = sin((u + v) * 0.5 * PI)
  _line(view, a, b, Color(0.13, 0.57, 1.0, alpha * 0.40), (6.0 if impact else 4.5) * taper + 0.5)
  _line(view, a, b, Color(0.30, 0.94, 1.0, alpha), (3.2 if impact else 2.3) * taper + 0.4)
  if impact and segment in [2, 3, 4, 5]:
   _line(view, a, b, Color(0.88, 1.0, 1.0, alpha * 0.95), 1.25 * taper)
 # Offset low-alpha echo gives a sword-afterimage, never a second damage pulse.
 if not impact:
  _line(view, at - d * half_length * 0.50 - side * half_length * 0.18, at + d * half_length * 0.35 - side * half_length * 0.12, Color(0.40, 0.66, 1.0, alpha * 0.28), 1.0)

func _draw_live_r1(view: Node2D, sim: Node) -> void:
 if not error.is_empty() or not sim.hero.cast_state.has("r1"):
  r1_star.clear()
  return
 var value: Variant = sim.hero.cast_state.r1
 if not value is Dictionary or not _integer(value.get("cast_id"), 1) or not _integer(value.get("generation")) or int(value.generation) != int(_scope.generation) or str(value.get("room_id", "")) != str(_scope.room_id) or not _number(value.get("until"), 0.0, 1e12) or not value.get("settled") is bool or not _point(sim.hero.position):
  _fail("wind_r1_live_state_invalid")
  return
 var id: int = int(value.cast_id)
 if not casts.has(id) or str(casts[id].source) != "r1" or not sim.cast_is_current(id):
  r1_star.clear()
  return
 var state: Dictionary = casts[id]
 var age: float = float(sim.real_time) - float(state.real_time)
 if age < -EPS:
  _fail("wind_r1_clock_reversed")
  return
 if age >= float(state.duration) or float(value.until) <= float(sim.real_time) + EPS:
  r1_star.clear()
  return
 var impact_age: float = float(sim.real_time)-float(state.impact_real_time) if state.has("impact_real_time") else -1.0
 var visual: Dictionary = r1_star.sample(view, sim, id, _identity(id), age, impact_age)
 receipt["r1_star_visual"] = visual
 receipt.default_skills.append({"kind":"r1_actual_presentation", "cast_id":id, "cast_identity":_identity(id), "position":sim.hero.position, "radius":state.radius, "age":age, "duration":state.duration, "contact_after":state.contact_after, "settled":value.settled, "time_domain":"real", "shield_visual":false, "damage_authority":false})

# R1 impacts use the actual original-art drawing rectangle, not an assumed
# enemy height. Keep its local body offset at the source damage ground point;
# do not follow a defeated body's subsequent visual fall or move world state.
func _r1_body_anchor(view: Node2D, target: String) -> Dictionary:
 var frame: Dictionary = {}
 var authority: String = ""
 for value: Dictionary in view.body_pick_regions:
  if str(value.get("actor_id", "")) == target:
   frame = value
   authority = "current_body_draw"
   break
 if frame.is_empty():
  var body: Dictionary = view.enemy_defeat.bodies.get(target, {})
  if body.get("frame") is Dictionary:
   frame = body.frame
   authority = "source_confirmed_defeat_frame"
 if not frame.get("destination") is Rect2 or not frame.get("transform") is Transform2D:
  return {}
 var destination: Rect2 = frame.destination
 var transform: Transform2D = frame.transform
 if not destination.is_finite() or destination.size.x <= EPS or destination.size.y <= EPS or not transform.is_finite():
  return {}
 var offset: Vector2 = transform.basis_xform(destination.get_center())
 if not _screen(offset):
  return {}
 return {"offset":offset, "authority":authority, "destination":destination, "texture":frame.get("texture", frame.get("key", ""))}

# All vertices stay inside the previous R1 burst's along/side envelope.
# These are target-local contact fragments, never another sweep or area hit.
func _r1_cut_polygon(center: Vector2, along: Vector2, half_length: float, half_width: float, vertices: Array) -> PackedVector2Array:
 var side := Vector2(-along.y, along.x)
 var result := PackedVector2Array()
 for vertex: Vector2 in vertices:
  result.append(center + along * vertex.x * half_length + side * vertex.y * half_width)
 return result

func _r1_hit(view: Node2D, event: Dictionary, ground: Vector2, along: Vector2, radius: float, alpha: float, age: float) -> void:
 var anchor: Dictionary = _r1_body_anchor(view, str(event.target))
 var half_length: float = radius * 1.10
 var half_width: float = radius * 0.75
 if anchor.is_empty():
  # Rare first-frame kills may have no original body draw. Keep the previous
  # exact grounded feedback for that event rather than guessing or failing.
  var side := Vector2(-along.y, along.x)
  var polygon := PackedVector2Array()
  for index: int in range(10):
   var angle: float = TAU * float(index) / 10.0 + 0.20
   var size: float = radius if index % 2 == 0 else radius * 0.35
   polygon.append(ground + along * cos(angle) * size * 1.10 + side * sin(angle) * size * 0.75)
  view.draw_colored_polygon(polygon, Color(0.26, 0.84, 1.0, alpha))
  var core := PackedVector2Array()
  for point: Vector2 in polygon:
   core.append(ground + (point - ground) * 0.48)
  view.draw_colored_polygon(core, Color(0.88, 0.99, 1.0, alpha))
  receipt.r1_hit_shapes.append({"sequence":event.sequence, "cast_id":event.cast_id, "target":event.target, "shape":"legacy_ground_star_fallback", "center_source":"no_usable_original_body_frame", "center":ground, "ground":ground, "body_offset":Vector2.ZERO, "position":event.position, "age":age, "time_domain":event.domain, "half_length":half_length, "half_width":half_width, "direction":along, "damage_authority":false})
  return
 var center: Vector2 = ground + Vector2(anchor.offset)
 # Replace the thin old cut, rather than stack another flash over it. The
 # unchanged target-local envelope keeps the head and silhouette readable.
 var peak: float = clampf(1.0-age/0.060,0.0,1.0)
 var width: float = half_width*lerpf(0.64,1.0,peak)
 var cut_alpha: float = minf(1.0,alpha*1.25)
 var outer: PackedVector2Array = _r1_cut_polygon(center, along, half_length, width, [Vector2(-1.0,0.11),Vector2(-0.29,-0.52),Vector2(0.46,-0.29),Vector2(1.0,-0.03),Vector2(0.20,0.32),Vector2(-0.64,0.39)])
 var blade: PackedVector2Array = _r1_cut_polygon(center, along, half_length, width, [Vector2(-0.91,0.10),Vector2(-0.28,-0.40),Vector2(0.46,-0.21),Vector2(0.94,-0.025),Vector2(0.18,0.23),Vector2(-0.57,0.29)])
 var core: PackedVector2Array = _r1_cut_polygon(center, along, half_length, width, [Vector2(-0.67,0.035),Vector2(-0.28,-0.25),Vector2(-0.11,-0.15),Vector2(0.90,-0.025),Vector2(0.18,0.10),Vector2(-0.25,0.16)])
 view.draw_colored_polygon(outer, Color(0.025,0.06,0.13,cut_alpha*0.96))
 view.draw_colored_polygon(blade, Color(0.12,0.92,1.0,cut_alpha))
 view.draw_colored_polygon(core, Color(1.0,1.0,0.86,cut_alpha))
 var burst: float = pow(clampf(1.0-age/0.105,0.0,1.0),1.5)
 var upper: PackedVector2Array = _r1_cut_polygon(center, along, half_length, half_width, [Vector2(-0.17,-0.24),Vector2(-0.68,-0.94),Vector2(-0.35,-0.37)])
 var lower: PackedVector2Array = _r1_cut_polygon(center, along, half_length, half_width, [Vector2(-0.26,0.24),Vector2(0.24,0.74),Vector2(0.02,0.31)])
 view.draw_colored_polygon(upper, Color(0.89,1.0,0.98,burst))
 view.draw_colored_polygon(lower, Color(0.39,0.96,1.0,burst*0.88))
 receipt.r1_hit_shapes.append({"sequence":event.sequence,"cast_id":event.cast_id,"target":event.target,"shape":"body_directional_cut","style":"r1_contact_peak_v2","center_source":anchor.authority,"center":center,"ground":ground,"body_offset":anchor.offset,"body_destination":anchor.destination,"body_texture":anchor.texture,"position":event.position,"age":age,"time_domain":event.domain,"half_length":half_length,"half_width":half_width,"draw_half_width":width,"direction":along,"entry_alpha":peak,"cut_alpha":cut_alpha,"shard_alpha":burst,"local_envelope":"previous_r1_burst","damage_authority":false})

func draw_hits(view: Node2D, sim: Node) -> void:
 if not _sync_scope(sim):
  view._visual_error(error)
  return
 if sim.phase != "combat" or sim.hero.dead:
  return
 if receipt.is_empty() or not receipt.has("bursts"):
  _fail("wind_draw_order_invalid")
  view._visual_error(error)
  return
 receipt.bursts.clear()
 receipt["r1_hit_shapes"] = []
 _draw_e3(view, sim)
 var retained: Array = []
 for event: Dictionary in bursts:
  var age: float = _age(event, sim)
  if age < -EPS:
   _fail("wind_hit_clock_reversed")
   break
  if age < HIT_LIFE:
   retained.append(event)
 bursts = retained
 for event: Dictionary in bursts:
  var age: float = maxf(0.0, _age(event, sim))
  var points: PackedVector2Array = _project(view, [event.position, event.position + event.direction.normalized()])
  if points.size() != 2:
   break
  var along: Vector2 = points[1] - points[0]
  if along.length_squared() <= EPS:
   _fail("wind_hit_projection_degenerate")
   break
  along = along.normalized()
  var side := Vector2(-along.y, along.x)
  var radius: float = (14.0 if str(event.source) in ["q1", "q2", "e1_pierce", "r1"] else 10.0) * (1.0 - 0.35 * age / HIT_LIFE)
  var alpha: float = 1.0 - age / HIT_LIFE
  if str(event.source) == "overload_true":
   # Separate white/gold rider feedback, not a second sword swing or proc.
   var at: Vector2 = points[0] + Vector2(0, -17)
   view.draw_line(at - side * 7, at + side * 7, Color(1.0, 0.89, 0.45, alpha), 2.0, true)
   view.draw_line(at - along * 9, at + along * 9, Color(1.0, 1.0, 0.92, alpha), 2.0, true)
  elif str(event.source) in ["attack","dash_attack"]:
   # Existing synchronous validated/deduplicated burst, no extra damage claim.
   var center:Vector2=points[0]+Vector2(0,-20)
   var extent:float=13*(1-age/HIT_LIFE)+3
   var diamond:=PackedVector2Array([center-along*extent,center-side*4,center+along*extent,center+side*4])
   view.draw_colored_polygon(diamond,Color(1,.94,.70,alpha))
   view.draw_line(center-side*9,center+side*9,Color(.4,1,1,alpha),2,true)
  elif str(event.source) == "q2":
   _q2_hit_blade(view, points[0], along, alpha, int(event.get("occurrence", 0)))
  elif str(event.source) == "r1":
   _r1_hit(view, event, points[0], along, radius, alpha, age)
  else:
   var polygon := PackedVector2Array()
   for index: int in range(10):
    var angle: float = TAU * float(index) / 10.0 + 0.20
    var size: float = radius if index % 2 == 0 else radius * 0.35
    var point: Vector2 = points[0] + along * cos(angle) * size * 1.10 + side * sin(angle) * size * 0.75
    if not _screen(point):
     _fail("wind_hit_brush_nonfinite")
     break
    polygon.append(point)
   if not error.is_empty():
    break
   view.draw_colored_polygon(polygon, Color(0.26, 0.84, 1.0, alpha))
   var core := PackedVector2Array()
   for point: Vector2 in polygon:
    core.append(points[0] + (point - points[0]) * 0.48)
   view.draw_colored_polygon(core, Color(0.88, 0.99, 1.0, alpha))
  receipt.bursts.append({"sequence":event.sequence, "cast_id":event.cast_id, "cast_identity":_identity(int(event.cast_id)), "target":event.target, "source":event.source, "occurrence":event.get("occurrence",0), "position":event.position, "position_authority":event.position_authority, "direction":event.direction, "age":age, "time_domain":event.domain, "positive_damage":event.amount, "dedup_key":"%s|%s|%s|%d" % [_identity(int(event.cast_id)), event.source, event.target, int(event.get("occurrence",0))]})
 if not error.is_empty():
  view._visual_error(error)


# E3 is a source-owned form, not a positional cast. It may remain active across
# rooms even though the old room's cast registry has been retired. Read the live
# actor state, never re-create a form from an event or advance an observer timer.
func _live_e3(sim: Node) -> Dictionary:
 if sim.hero.dead or sim.phase != "combat" or not sim.hero.cast_state.has("e3"):
  return {}
 var value: Variant = sim.hero.cast_state.e3
 if not value is Dictionary or not _integer(value.get("cast_id"), 1) or not _integer(value.get("rank"), 1) or int(value.rank) > 6 or not _number(value.get("until"), 0.0, 1e12) or not _integer(value.get("saves")) or int(value.saves) > int(sim.hv("h13")) or not _number(value.get("left"), 0.0, 1e12) or not _point(sim.hero.position):
  _fail("wind_e3_live_state_invalid")
  return {}
 var left: float = maxf(0.0, float(value.until) - float(sim.hero_time))
 if left <= EPS:
  return {}
 return {"cast_id":value.cast_id, "rank":value.rank, "remaining":left, "saves":value.saves, "position":sim.hero.position, "source_authority":"live_actor_cast_state", "scope":_scope.duplicate(true)}

func _accept_e3(event: Dictionary, sim: Node) -> void:
 var kind: String = str(event.kind)
 if kind == "e3_ended":
  if sim.hero.cast_state.has("e3"):
   return
  _e3_activation.clear()
  _e3_save.clear()
  return
 var live: Dictionary = _live_e3(sim)
 if live.is_empty() or not _integer(event.get("cast_id"), 1) or int(event.cast_id) != int(live.cast_id):
  return
 if kind == "e3_started":
  if not _cast_valid(event, sim) or not _number(event.get("visual_duration"), EPS, 1.0) or not is_equal_approx(float(event.visual_duration), 0.30) or not _point(event.get("position")) or event.position.distance_to(sim.hero.position) > EPS:
   _fail("wind_e3_activation_source_invalid")
   return
  _e3_activation = {"cast_id":event.cast_id, "sequence":event.sequence, "hero_time":sim.hero_time, "duration":event.visual_duration}
 elif kind == "e3_death_prevented":
  # H13's source state is committed before this event. A forged/stale event
  # cannot create protection or display a save when the live source has none.
  if not sim.wind_hex("h13") or int(live.saves) != 1 or not _number(event.get("prevented"), EPS, 1e12) or not _integer(event.get("remaining")) or int(event.remaining) != 0 or not _point(event.get("position")) or event.position.distance_to(sim.hero.position) > EPS:
   return
  if not _e3_save.is_empty() and int(_e3_save.cast_id) == int(event.cast_id):
   return
  _e3_save = {"cast_id":event.cast_id, "sequence":event.sequence, "hero_time":sim.hero_time, "duration":0.30, "prevented":event.prevented, "cancelled_debt":event.get("cancelled_debt", 0.0)}
 # e3_extended has no independent simulated lifetime: draw reads live until.

func _draw_e3(view: Node2D, sim: Node) -> void:
 var live: Dictionary = _live_e3(sim)
 if live.is_empty():
  _e3_activation.clear()
  _e3_save.clear()
  return
 var points: PackedVector2Array = _project(view, [live.position])
 if points.size() != 1:
  return
 var at: Vector2 = points[0] + Vector2(0, -28)
 # Screen-space body wisps, explicitly NOT a world-space damage radius or shield.
 var flow: float = float(sim.hero_time) * 1.2
 var pulse: float = 0.0
 if not _e3_activation.is_empty() and int(_e3_activation.cast_id) == int(live.cast_id):
  pulse = clampf(1.0 - (float(sim.hero_time) - float(_e3_activation.hero_time)) / float(_e3_activation.duration), 0.0, 1.0)
 # Two staggered open wisps rise beside the body rather than outlining
 # the face like a static barrier. Hero-time owns motion, including pause.
 for side: float in [-1.0, 1.0]:
  var progress: float = fposmod(flow + (0.5 if side > 0.0 else 0.0), 1.0)
  var envelope: float = sin(progress * PI)
  var previous := Vector2.ZERO
  for index: int in range(9):
   var t: float = float(index) / 8.0
   var point: Vector2 = at + Vector2(side * (18.0 + sin((progress * 0.8 + t * 0.35) * PI) * 9.0 + pulse * 3.0), 26.0 - progress * 58.0 + (1.0 - t) * 24.0)
   if index > 0:
    var alpha: float = envelope * (0.85 + pulse * 0.15) * pow(t, 0.45)
    view.draw_line(previous, point, Color(0.32, 0.95, 0.84, alpha), (2.5 + pulse * 0.8) * (0.4 + t * 0.6), true)
   previous = point
 var save_alpha: float = 0.0
 if not _e3_save.is_empty() and int(_e3_save.cast_id) == int(live.cast_id):
  save_alpha = clampf(1.0 - (float(sim.hero_time) - float(_e3_save.hero_time)) / float(_e3_save.duration), 0.0, 1.0)
  if save_alpha > 0.0:
   # Open upward strokes mark one actual prevented hit, never an invulnerability ring.
   for side: float in [-1.0, 1.0]:
    view.draw_polyline(PackedVector2Array([at + Vector2(side * 8, 18), at + Vector2(side * 21, 0), at + Vector2(side * 12, -21)]), Color(1.0, 0.94, 0.60, save_alpha), 3.0, true)
 var item: Dictionary = live.duplicate(true)
 item.merge({"kind":"e3_live_body_aura", "time_domain":"hero", "activation_pulse":pulse, "save_flash":save_alpha, "visual_only":true, "damage_authority":false, "world_radius":false, "poses_assigned":false})
 if save_alpha > 0.0:
  item["save_sequence"] = _e3_save.sequence
  item["prevented"] = _e3_save.prevented
 receipt.default_skills.append(item)

# E2 display owns no combat clocks, targeting, position, or lifecycle state.
func _accept_e2(event: Dictionary, sim: Node) -> Dictionary:
 var kind: String = str(event.kind)
 if sim.has_method("bind_route_identity") and str(event.get("run_id", "")) != str(sim.get("route_run_id")):return {}
 if not _cast_valid(event, sim):return {}
 var id: int = int(event.cast_id)
 if kind == "e2_started":
  var live: Dictionary = sim.hero.cast_state.get("e2_spin", {})
  if live.is_empty() or int(live.get("cast_id", -1)) != id or not _geometry(event, true) or not _number(event.get("duration"), EPS, 2.0) or not _integer(event.get("rotations"), 1) or int(event.rotations) > 3 or not _point(event.get("target_point")):
   _fail("wind_e2_start_invalid");return {}
  var rank: int = int(live.get("rank", 0))
  if rank < 1 or rank > 6:return {}
  var expected_count: int = int(sim.v("E2-1", rank)) + (int(sim.hv("h12", 1)) if sim.wind_hex("h12") else 0)
  if int(event.rotations) != expected_count or not is_equal_approx(float(event.radius), sim.v("E2-2", rank)) or not is_equal_approx(float(event.duration), sim.v("E2-5", rank)):
   _fail("wind_e2_start_source_mismatch");return {}
  # E2 emits no direction; facing is read synchronously, never inserted into core.
  var projected: Dictionary = event.duplicate(true)
  projected.direction = sim.hero.facing
  if _open_cast(projected, "e2", sim):
   casts[id].merge({"radius":event.radius,"count":event.rotations,"initial_duration":event.duration,"occurrence":0,"phase":"initial","spin":{},"teleports":[]}, true)
  return {}
 if not casts.has(id) or str(casts[id].source) != "e2":return {}
 var state: Dictionary = casts[id]
 if kind == "e2_spin_started":
  var live: Dictionary = sim.hero.cast_state.get("e2_spin", {})
  if live.is_empty() or int(live.get("cast_id", -1)) != id or not _geometry(event, true) or not _integer(event.get("occurrence"), 1) or int(event.occurrence) > int(state.count) + 1 or str(event.get("phase", "")) not in ["initial", "extra"] or str(event.phase) != str(live.get("phase", "")) or not _number(event.get("rotation_duration"), EPS, 2.0):
   _fail("wind_e2_spin_invalid");return {}
  var expected_occurrence: int = int(state.occurrence) + 1
  var expected_radius: float = float(state.radius) if str(event.phase) == "initial" else sim.hv("h11", 4)
  var expected_duration: float = float(state.initial_duration) / float(state.count) if str(event.phase) == "initial" else sim.hv("h11", 5) / sim.hv("h11", 1)
  if int(event.occurrence) <= int(state.occurrence):return {}
  if int(event.occurrence) != expected_occurrence or not is_equal_approx(float(event.radius), expected_radius) or not is_equal_approx(float(event.rotation_duration), expected_duration):
   _fail("wind_e2_spin_source_mismatch");return {}
  state.occurrence = event.occurrence;state.phase = event.phase
  state.spin = event.duplicate(true)
  var pose: Dictionary = event.duplicate(true)
  pose.direction = sim.hero.facing
  pose.pose_prefix = "attack" # Honest existing sword-pose reuse, not bespoke spin sprites.
  pose.animation = {"time_domain":"world","contact_after":float(event.rotation_duration)*0.5,"recovery":float(event.rotation_duration)*0.5}
  pose.pose_reuse = "existing_attack_frames_for_E2_circle"
  return pose
 if kind in ["e2_blink", "e2_return"]:
  if not _point(event.get("origin")) or not _point(event.get("position")) or event.position != sim.hero.position:
   _fail("wind_e2_teleport_invalid");return {}
  if _once(event, kind):
   state.teleports.append(event.duplicate(true))
  return {} # Returning must not replace/cancel H11's ongoing pose.
 if kind == "e2_finished":state.spin = {}
 return {}

func e2_shadow(sim: Node) -> Dictionary:
 if not _sync_scope(sim) or sim.phase != "combat" or sim.hero.dead:return {}
 var shadow: Dictionary = sim.hero.cast_state.get("e2_shadow", {})
 if shadow.is_empty():return {}
 if not _integer(shadow.get("cast_id"), 1) or not sim.cast_is_current(int(shadow.cast_id)) or int(shadow.get("generation", -1)) != int(sim.encounter_generation) or str(shadow.get("room_id", "")) != str(sim.room_id):return {}
 if not _point(shadow.get("position")) or not _direction(shadow.get("facing")) or not _number(shadow.get("left"), 0.0, 3.0) or not bool(shadow.get("untargetable", false)):
  _fail("wind_e2_shadow_invalid");return {}
 if float(shadow.left) <= EPS:return {}
 return shadow.duplicate(true)

func _draw_e2(view: Node2D, sim: Node) -> void:
 for id: int in casts:
  var state: Dictionary = casts[id]
  if str(state.source) != "e2" or not sim.cast_is_current(id):continue
  var spin: Dictionary = state.get("spin", {})
  var live: Dictionary = sim.hero.cast_state.get("e2_spin", {})
  if not spin.is_empty() and not live.is_empty() and int(live.get("cast_id", -1)) == id and str(live.get("phase", "")) == str(spin.phase):
   var age: float = float(sim.clock.world_time) - float(spin.world_time)
   var duration: float = float(spin.rotation_duration)
   if age >= -EPS and age <= duration + EPS:
    var progress: float = clampf(age / duration, 0.0, 1.0)
    var radius: float = float(spin.radius)
    var origin: Vector3 = sim.hero.position
    _ring(view, origin, radius, Color(.24,.76,.90,.18), 1.0)
    # A tapered rotating sword arc at the real moving center, never a damage zone.
    for index: int in range(16):
     var angle: float = TAU * progress - float(index) * .065
     var a: Vector3 = origin + Vector3(cos(angle),0,sin(angle)) * radius * .91
     var b: Vector3 = origin + Vector3(cos(angle-.065),0,sin(angle-.065)) * radius * .91
     _line(view,a,b,Color(.65,.96,1.0,(1.0-float(index)/16.0)*.85),2.4)
    receipt.default_skills.append({"kind":"e2_live_spin","cast_id":id,"occurrence":spin.occurrence,"phase":spin.phase,"position":origin,"radius":radius,"progress":progress,"time_domain":"world","damage_authority":false,"pose_reuse":"existing_attack_frames"})
  for teleport: Dictionary in state.teleports:
   var age: float = float(sim.clock.world_time)-float(teleport.world_time)
   if age < 0.0 or age >= RELEASE_LIFE:continue
   var alpha: float = 1.0-age/RELEASE_LIFE
   # Two endpoints only: never draw a swept path between teleport locations.
   _ring(view,teleport.origin,.48,Color(.38,.85,1.0,alpha*.4),1.4)
   _ring(view,teleport.position,.6,Color(.72,.96,1.0,alpha*.7),2.0)
   receipt.default_skills.append({"kind":teleport.kind,"cast_id":id,"origin":teleport.origin,"position":teleport.position,"time_domain":"world","damage_authority":false})
 var shadow: Dictionary = e2_shadow(sim)
 if not shadow.is_empty():
  _ring(view,shadow.position,.5,Color(.65,.37,.62,.5),1.3)
  receipt.default_skills.append({"kind":"e2_live_shadow","cast_id":shadow.cast_id,"position":shadow.position,"remaining":shadow.left,"untargetable":true,"damage_authority":false})
