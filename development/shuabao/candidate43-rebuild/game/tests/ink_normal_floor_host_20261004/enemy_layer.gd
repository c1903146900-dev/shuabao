extends Node3D
## One source reader, all real bodies, and original hostile attack presentation.
const Reader = preload("res://tests/ink_first_floor_enemy_views_20261004/source_reader.gd")
const Roster = preload("res://tests/ink_first_floor_enemy_views_20261004/fix01/roster_presenter.gd")
const Body = preload("res://tests/ink_first_floor_enemy_views_20261004/enemy_view.gd")
const Catalog = preload("res://tests/ink_first_floor_enemy_views_20261004/asset_catalog.gd")
const Hostile = preload("res://assets/enemies/siege_brood/vfx/enemy_combat_vfx.gd")
var reader: RefCounted = Reader.new()
var roster: Node3D
var hostile: Node3D
var pending: Array = []
var report: Dictionary = {"status":"unbound"}
var _roles_ready: Dictionary = {}
var _effects_ready: bool = false
const HOSTILE_TEXTURES := ["basalt_grain","contact_ground","contact_spike","dust_0","dust_1","dust_2","erosion","ground_faults","ground_scar","pressure_sheet","spark"]
var _identity: Dictionary = {}
var _world: float = -1.0
var _epoch: int = -1
var _reader_id: int = -1
var world_steps: int = 0
var friendly_projectiles_forwarded: int = 0
func _ready() -> void:
 set_process(false); set_physics_process(false)
 roster = Roster.new(); add_child(roster)
 hostile = Hostile.new(); add_child(hostile)
func preflight(payload: Dictionary) -> Dictionary:
 if payload.get("node_type", "") != "combat": return {"accepted":true,"reason":"service_has_no_actors"}
 var entries: Array = payload.get("roster", [])
 if entries.size() > Roster.MAX_ACTORS: return {"accepted":false,"reason":"candidate_roster_exceeds_six"}
 if not _effects_ready:
  for name: String in HOSTILE_TEXTURES:
   if hostile._texture(name) == null: return {"accepted":false,"reason":"hostile_art_not_ready:" + name}
  _effects_ready = true
 for entry: Dictionary in entries:
  var kind: String = str(entry.get("kind", ""))
  if kind not in Catalog.ROLES: return {"accepted":false,"reason":"unsupported_enemy_role:" + kind}
  if _roles_ready.has(kind): continue
  # Fail before Session enters a combat room. No silent minion or proxy fallback.
  var probe: Node3D = Body.new(); add_child(probe); probe.visible = false
  var accepted: bool = probe.configure(kind)
  var imported: Dictionary = probe.import_report.duplicate(true)
  probe.free()
  if not accepted: return {"accepted":false,"reason":"enemy_art_not_ready:" + kind,"details":imported}
  _roles_ready[kind] = true
 return {"accepted":true,"reason":"all_selected_bodies_available"}
func observe(source: Node, event: Dictionary) -> void:
 reader.observe_event(source,event)
 var kind: String = str(event.get("kind", ""))
 if kind.begins_with("enemy_") or kind == "kill":
  if pending.size() >= 128:
   report = {"status":"HOLD","reason":"hostile_event_buffer_overflow"}; return
  pending.append(event.duplicate(true))
func _clear_socket_owner() -> void:
 hostile.sync_actor_views({})
 hostile.clear()
 _identity.clear(); _world = -1.0
func reset_scope() -> void:
 _clear_socket_owner()
 roster.reset_owner()
 reader = Reader.new()
 pending.clear(); _epoch = -1; _reader_id = -1
 report = {"status":"reset"}
func present(source: Node, full: Dictionary, context: Dictionary) -> Dictionary:
 if report.get("reason", "") == "hostile_event_buffer_overflow": return report
 var frame: Dictionary = reader.capture(source,context)
 if frame.get("status", "") != "ready":
  _clear_socket_owner(); roster.visible = false
  report = {"status":"HOLD","reason":frame.get("status", "reader_not_ready")}; return report
 var next_identity: Dictionary = {}
 for actor: Dictionary in frame.actors: next_identity[str(actor.state.actor_id)] = str(actor.token)
 if int(frame.reader_id) != _reader_id or int(frame.epoch) != _epoch or next_identity != _identity:
  _clear_socket_owner()
  if int(frame.reader_id) != _reader_id: roster.reset_owner()
 _reader_id = int(frame.reader_id); _epoch = int(frame.epoch); _identity = next_identity
 var shown: Dictionary = roster.present(frame)
 if shown.get("status", "") != "ready":
  _clear_socket_owner(); report = {"status":"HOLD","reason":"enemy_body_unavailable","body":shown}; return report
 var views: Dictionary = roster.actor_view_map()
 for actor: Dictionary in full.enemies:
  if not bool(actor.dead) and not views.has(str(actor.actor_id)):
   _clear_socket_owner(); report = {"status":"HOLD","reason":"living_enemy_missing_body"}; return report
 var now: float = float(frame.world_time)
 # Exactly one positive authoritative world delta. No wall-delta or second tick.
 if _world >= 0.0 and now > _world:
  hostile.step(now - _world); world_steps += 1
 _world = now
 hostile.actor_views = views # Fresh full map for event muzzle sockets; one pose sync below.
 for event: Dictionary in pending:
  if str(event.get("room_id", "")) != str(frame.scope.room_id) or int(event.get("generation", -1)) != int(frame.scope.generation): continue
  var id: String = str(event.get("actor_id",event.get("target", "")))
  var actor: Dictionary = source.enemy_by_id(id)
  if actor.is_empty(): continue
  hostile.play_event(event,str(actor.kind))
 pending.clear()
 var projectiles: Array = []
 for projectile: Dictionary in full.projectiles:
  if str(projectile.get("team", "")) == "enemy": projectiles.append(projectile)
 hostile.sync_projectiles(projectiles)
 hostile.sync_hostile_zones(full.zones)
 hostile.sync_enemies(full.enemies)
 # sync_enemies positions warning roots; remap sockets after that source pose.
 hostile.sync_actor_views(views)
 report = {"status":"ready","body":shown,"hostile":hostile.inspect(),"epoch":_epoch,"reader_id":_reader_id,"identity":_identity.duplicate(),"world_steps":world_steps,"friendly_projectiles_forwarded":friendly_projectiles_forwarded,"enemy_projectiles":projectiles.size(),"native_accepted":false}
 return report
