extends RefCounted
## Read-only G28 entity bodies and committed-shot feedback.
## The source resolves shots instantly. No visual flight, targeting, range ring,
## second hit spark, collision, input, simulation mutation or independent clock.
const SOURCE: String = "res://fengli_route_20261024/sim.gd"
const SHOT_FLASH_SECONDS: float = 0.12 # Presentation persistence, never travel time.
const MAX_SHOT_FLASHES: int = 32 # Presentation-only storage bound.
const MUZZLE_OFFSET: Vector2 = Vector2(0.0, -27.0) # Sprite-local offset only.
const EPS: float = 0.00001
var _scope: String = ""
var _last_sequence: int = -1
var _shots: Array = []
var receipt: Dictionary = {}

func clear() -> void:
 _scope = ""
 _last_sequence = -1
 _shots.clear()
 receipt.clear()

func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

func _point(value: Variant) -> bool:
 return value is Vector3 and value.is_finite()

func _current(sim: Node) -> bool:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SOURCE:
  clear()
  return false
 var next: String = "%d|%s|%s|%s|%d" % [sim.get_instance_id(), sim.route_run_id, sim.combat_level_id, sim.room_id, sim.encounter_generation]
 if next != _scope:
  clear()
  _scope = next
 var live: RefCounted = sim.common.runtime
 if sim.hero.actor_id != "fengli" or sim.hero.dead or sim.phase != "combat" or not live.combat or live.room_id != sim.room_id or live.generation != sim.encounter_generation or not live.active("g28"):
  _shots.clear()
  receipt.clear()
  return false
 return true

func accept(event: Dictionary, sim: Node) -> bool:
 if not _current(sim) or event.get("kind", "") != "damage" or event.get("source", "") != "common_g28": return false
 if bool(event.get("replay", false)) or bool(event.get("stale_generation", false)) or not bool(event.get("hex_generated", false)): return false
 if event.get("run_id", "") != sim.route_run_id or event.get("room_id", "") != sim.room_id or event.get("combat_level_id", "") != sim.combat_level_id or event.get("generation", -1) != sim.encounter_generation: return false
 if not event.get("sequence") is int or int(event.sequence) <= _last_sequence or int(event.sequence) != sim.sequence: return false
 if sim.event_log.is_empty() or sim.event_log.back() != event: return false
 if not event.get("cast_id") is int or not _point(event.get("source_position")) or not _point(event.get("position")): return false
 if not _number(event.get("amount")) or float(event.amount) <= 0.0 or not _number(event.get("world_time")): return false
 if absf(float(event.world_time) - float(sim.clock.world_time)) > EPS: return false
 # Existing bridge exposes the actual source effect only during synchronous drain.
 # A generic damage notification or raw common_hex_damage request is not proof
 # that damage committed. The ordinary damage callback below is that proof.
 var original: Variant = sim.common.get("_g02_drained_event")
 if not sim.common._draining or sim.common._inside_hit <= 0 or not original is Dictionary: return false
 if original.get("kind", "") != "damage" or original.get("source", "") != "common_g28": return false
 if not original.get("event_id") is String or str(original.event_id).is_empty(): return false
 if original.get("target_id", "") != event.get("target", "") or original.get("cast_id", -1) != event.cast_id or original.get("position") != event.source_position: return false
 if original.get("generation", -1) != sim.encounter_generation or original.get("room_id", "") != sim.room_id or original.get("run_id", "") != sim.common.runtime.run_id: return false
 var target: Dictionary = sim.enemy_by_id(str(event.get("target", "")))
 if target.is_empty() or target.position != event.position: return false
 _last_sequence = int(event.sequence)
 # The final real shot may drain after its turret expired. Keep the committed
 # origin/target briefly, without resurrecting a turret or guessing an entity ID.
 _shots.append({"source_position":event.source_position, "position":event.position, "target":str(event.target), "cast_id":int(event.cast_id), "amount":float(event.amount), "world_time":float(event.world_time), "sequence":int(event.sequence), "event_id":str(original.event_id)})
 if _shots.size() > MAX_SHOT_FLASHES: _shots.pop_front()
 return true

func sample(sim: Node) -> Dictionary:
 var current: bool = _current(sim)
 receipt = {"scope":_scope, "turrets":[], "shots":[], "live_count":0, "shot_count":0, "time_domain":"source_world", "gameplay_authority":false, "flight_simulated":false, "target_hit_effect_added":false}
 if not current: return receipt.duplicate(true)
 var live: RefCounted = sim.common.runtime
 var now: float = float(sim.clock.world_time)
 if not is_finite(now): return receipt.duplicate(true)
 receipt["world_time"] = now
 # No retained source dictionaries and no spawn-notification-created bodies.
 for entry: Variant in live.turrets:
  if not entry is Dictionary or not entry.get("entity_id") is String or str(entry.entity_id).is_empty(): continue
  if not _point(entry.get("position")) or not _number(entry.get("left")) or float(entry.left) <= 0.0 or not entry.get("cast_id") is int: continue
  receipt.turrets.append({"entity_id":str(entry.entity_id), "position":entry.position, "left":float(entry.left), "cast_id":int(entry.cast_id)})
 var retained: Array = []
 for shot: Dictionary in _shots:
  var age: float = now - float(shot.world_time)
  if age < 0.0 or age >= SHOT_FLASH_SECONDS: continue
  retained.append(shot)
  receipt.shots.append(shot.merged({"age":age, "alpha":1.0 - age / SHOT_FLASH_SECONDS}, true))
 _shots = retained
 receipt.live_count = receipt.turrets.size()
 receipt.shot_count = receipt.shots.size()
 return receipt.duplicate(true)

func draw_body(view: Node2D, turret: Dictionary) -> void:
 var foot: Vector2 = view.p(turret.position)
 if not foot.is_finite(): return
 # Fixed-size friendly machinery glyph. It is neither a range nor a hitbox.
 # Drawn in the same foot-depth list as actors; it never enters actor picking.
 var outline := Color("10192a")
 var metal := Color("387c87")
 var light := Color("75ffe5")
 var gold := Color("f4e99a")
 view.ellipse(foot + Vector2(0.0, 2.0), Vector2(12.0, 4.0), Color("10142680"))
 for side: float in [-1.0, 1.0]:
  view.draw_line(foot + Vector2(side * 4.0, -7.0), foot + Vector2(side * 11.0, 1.0), outline, 5.0, true)
  view.draw_line(foot + Vector2(side * 4.0, -7.0), foot + Vector2(side * 11.0, 1.0), metal, 2.0, true)
 var body := PackedVector2Array([foot + Vector2(-9.0, -9.0), foot + Vector2(-7.0, -20.0), foot + Vector2(7.0, -20.0), foot + Vector2(9.0, -9.0), foot + Vector2(0.0, -5.0)])
 view.draw_colored_polygon(body, metal)
 body.append(body[0])
 view.draw_polyline(body, outline, 3.0, true)
 var muzzle: Vector2 = foot + MUZZLE_OFFSET
 view.draw_rect(Rect2(muzzle + Vector2(-4.0, 0.0), Vector2(8.0, 12.0)), outline)
 view.draw_rect(Rect2(muzzle + Vector2(-2.0, 2.0), Vector2(4.0, 8.0)), gold)
 view.draw_line(foot + Vector2(-5.0, -12.0), foot + Vector2(5.0, -12.0), light, 2.0, true)

func draw_shots(view: Node2D, sim: Node) -> void:
 var state: Dictionary = sample(sim)
 for shot: Dictionary in state.shots:
  # Same authored neutral barrel tip as the body, not the tripod's ground foot.
  # This screen-local offset never changes the committed world source_position.
  var origin: Vector2 = view.p(shot.source_position) + MUZZLE_OFFSET
  var target: Vector2 = view.p(shot.position)
  if not origin.is_finite() or not target.is_finite(): continue
  var alpha: float = float(shot.alpha)
  # A complete thin line appears at the damage callback, then only fades.
  # There is no travelling head, future path, delayed impact or extra hit spark.
  view.draw_line(origin, target, Color(0.46, 1.0, 0.90, 0.55 * alpha), 1.5, true)
  for direction: Vector2 in [Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
   view.draw_line(origin + direction * 3.0, origin + direction * 8.0, Color(0.96, 0.91, 0.61, alpha), 2.0, true)
