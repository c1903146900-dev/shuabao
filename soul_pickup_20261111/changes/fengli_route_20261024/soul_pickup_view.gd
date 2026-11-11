extends RefCounted
## Read-only G10 world pickup. Source souls, not spawn notifications, own visibility.
## No input, collision, rewards, reset, source clock or source-state writes.
const SOURCE: String = "res://fengli_route_20261024/sim.gd"
const PICKUP_FLASH_SECONDS: float = 0.35 # Presentation only; not a gameplay duration.
const EPS: float = 0.00001
var _scope: String = ""
var _last_sequence: int = -1
var _pickups: Array = []
var receipt: Dictionary = {}

func clear() -> void:
 _scope = ""
 _last_sequence = -1
 _pickups.clear()
 receipt.clear()

func _number(value: Variant) -> bool:
 return (value is int or value is float) and is_finite(float(value))

func _current(sim: Node) -> bool:
 if not is_instance_valid(sim) or sim.get_script() == null or sim.get_script().resource_path != SOURCE:
  clear()
  return false
 var next: String = "%d|%s|%s|%s|%d" % [sim.get_instance_id(), sim.route_run_id, sim.combat_level_id, sim.room_id, sim.encounter_generation]
 if next != _scope:
  clear()
  _scope = next
 var live: RefCounted = sim.common.runtime
 if sim.hero.actor_id != "fengli" or sim.hero.dead or sim.phase != "combat" or not live.combat or live.room_id != sim.room_id or live.generation != sim.encounter_generation or not live.active("g10"):
  _pickups.clear()
  receipt.clear()
  return false
 return true

func accept(event: Dictionary, sim: Node) -> bool:
 if not _current(sim) or event.get("kind", "") != "common_hex_soul_pickup" or event.get("source", "") != "common_g10": return false
 if bool(event.get("stale_generation", false)) or event.get("run_id", "") != sim.route_run_id or event.get("room_id", "") != sim.room_id or event.get("combat_level_id", "") != sim.combat_level_id or event.get("generation", -1) != sim.encounter_generation: return false
 if not event.get("sequence") is int or int(event.sequence) <= _last_sequence or int(event.sequence) != sim.sequence: return false
 if sim.event_log.is_empty() or sim.event_log.back() != event: return false
 if not event.get("position") is Vector3 or not event.position.is_finite() or not _number(event.get("world_time")): return false
 if absf(float(event.world_time) - float(sim.clock.world_time)) > EPS: return false
 # Existing route bridge records the original effect only while draining it.
 # A public emit_event call, stale replay or nearest-object guess cannot flash.
 var original: Variant = sim.common.get("_g02_drained_event")
 if not sim.common._draining or not original is Dictionary or original.get("kind", "") != "soul_pickup" or original.get("source", "") != "common_g10": return false
 if str(original.get("event_id", "")).is_empty() or original.get("event_id") != event.get("event_id") or original.get("position") != event.position: return false
 _last_sequence = int(event.sequence)
 _pickups.append({"position":event.position, "world_time":float(event.world_time), "sequence":int(event.sequence), "event_id":str(event.event_id)})
 return true

func sample(sim: Node) -> Dictionary:
 var current: bool = _current(sim)
 receipt = {"scope":"", "live_count":0, "souls":[], "pickup_count":0, "pickups":[], "time_domain":"source_world", "gameplay_authority":false}
 if not current: return receipt.duplicate(true)
 var live: RefCounted = sim.common.runtime
 if sim.common.model == null or sim.common.model.get_ref() == null: return receipt.duplicate(true)
 # Read the model's original parameter projection, including approved G20 fields.
 # Do not call runtime.parameter, which can populate the runtime's parameter cache.
 var model: RefCounted = sim.common.model.get_ref()
 var radius: float = model.hex_parameter("common_g10", "G10-6")
 var lifetime: float = model.hex_parameter("common_g10", "G10-2")
 var now: float = float(sim.clock.world_time)
 if not is_finite(radius) or radius <= 0.0 or not is_finite(lifetime) or lifetime <= 0.0 or not is_finite(now): return receipt.duplicate(true)
 receipt.scope = _scope
 receipt["world_time"] = now
 # Never retain source dictionary references or synthesize an entity from events.
 for entry: Variant in live.souls:
  if not entry is Dictionary or not entry.get("entity_id") is String or str(entry.entity_id).is_empty(): continue
  if not entry.get("position") is Vector3 or not entry.position.is_finite() or not _number(entry.get("left")) or float(entry.left) <= 0.0: continue
  receipt.souls.append({"entity_id":str(entry.entity_id), "position":entry.position, "left":float(entry.left), "pickup_radius":radius, "life_fraction":clampf(float(entry.left) / lifetime, 0.0, 1.0)})
 var retained: Array = []
 for entry: Dictionary in _pickups:
  var age: float = now - float(entry.world_time)
  if age < 0.0 or age >= PICKUP_FLASH_SECONDS: continue
  retained.append(entry)
  receipt.pickups.append({"position":entry.position, "sequence":entry.sequence, "event_id":entry.event_id, "age":age, "life_fraction":1.0 - age / PICKUP_FLASH_SECONDS})
 _pickups = retained
 receipt.live_count = receipt.souls.size()
 receipt.pickup_count = receipt.pickups.size()
 return receipt.duplicate(true)

func draw_ground(view: Node2D, sim: Node) -> void:
 var state: Dictionary = sample(sim)
 for soul: Dictionary in state.get("souls", []):
  var at: Vector2 = view.p(soul.position)
  if not at.is_finite(): continue
  # A restrained exact-radius floor halo, never an enlarged damage indicator.
  var ring := PackedVector2Array()
  for index in range(33):
   var angle: float = TAU * float(index) / 32.0
   ring.append(view.p(soul.position + Vector3(cos(angle), 0.0, sin(angle)) * float(soul.pickup_radius)))
  var alpha: float = clampf(float(soul.life_fraction) * 4.0, 0.0, 1.0)
  view.draw_polyline(ring, Color(0.30, 1.0, 0.85, 0.16 * alpha), 1.5, true)
  view.ellipse(at, Vector2(10.0, 3.0), Color(0.20, 0.80, 0.72, 0.24 * alpha))

func draw_foreground(view: Node2D, sim: Node) -> void:
 # Re-read this frame: source clear/death cannot leave a cached floating object.
 # Only the local visual offset bobs; the source stays put.
 var state: Dictionary = sample(sim)
 for soul: Dictionary in state.get("souls", []):
  var at: Vector2 = view.p(soul.position)
  if not at.is_finite(): continue
  var alpha: float = clampf(float(soul.life_fraction) * 4.0, 0.0, 1.0)
  var bob: float = 2.0 * sin(float(state.world_time) * 3.0)
  var center: Vector2 = at + Vector2(0.0, -17.0 + bob)
  var points := PackedVector2Array([center + Vector2(0.0, -10.0), center + Vector2(6.0, -1.0), center + Vector2(3.0, 7.0), center + Vector2(-2.0, 11.0), center + Vector2(-6.0, 2.0), center + Vector2(-5.0, -4.0)])
  view.draw_colored_polygon(points, Color(0.20, 0.95, 0.80, 0.90 * alpha))
  points.append(points[0])
  view.draw_polyline(points, Color(0.04, 0.14, 0.18, alpha), 2.0, true)
  view.draw_circle(center + Vector2(0.0, -2.0), 2.5, Color(1.0, 0.96, 0.65, alpha))
 for pickup: Dictionary in state.get("pickups", []):
  var at: Vector2 = view.p(pickup.position) + Vector2(0.0, -17.0)
  if not at.is_finite(): continue
  var alpha: float = float(pickup.life_fraction)
  var distance: float = 6.0 + 15.0 * (1.0 - alpha)
  for direction: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
   view.draw_line(at + direction * distance, at + direction * (distance + 4.0), Color(0.65, 1.0, 0.83, alpha), 2.0, true)
