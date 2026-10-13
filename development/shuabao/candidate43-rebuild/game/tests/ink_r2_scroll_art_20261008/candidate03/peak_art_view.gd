extends Node3D
## SOURCE-ONLY successor: a folded relief landscape plus anchored ground roots.
## No private clock, game callbacks, target query, collider, RNG or source writes.
const ATLAS_PATH: String = "res://assets/ink_generated/r2_landscape01/ink_mountain_atlas01.png"
const MESH_SCRIPT_PATH: String = "res://tests/ink_r2_scroll_art_20261008/candidate03/landscape_mesh.gd"
const SHADER_PATH: String = "res://tests/ink_r2_scroll_art_20261008/candidate03/landscape_ink.gdshader"
const MAX_PEAKS: int = 64
const BURIED_OFFSET: float = -2.0
static var _shared_mesh: ArrayMesh
static var _shared_shader: Shader
static var _atlas_texture: Texture2D
var domain_sample: Dictionary = {}
var peak_samples: Array = []
var _instances: Dictionary = {}
var _scope_key: String = ""

func _ready() -> void:
 name = "R2ReliefScrollCandidate03_NotPixelAccepted"
 set_as_top_level(true)
 transform = Transform3D.IDENTITY
 _ensure_resources()

func _ensure_resources() -> bool:
 if _atlas_texture == null:
  if not ResourceLoader.exists(ATLAS_PATH, "Texture2D"):
   push_error("C12 requires coordinator standard import of " + ATLAS_PATH)
   return false
  _atlas_texture = ResourceLoader.load(ATLAS_PATH, "Texture2D") as Texture2D
  if _atlas_texture == null or _atlas_texture.get_width() != 1254 or _atlas_texture.get_height() != 1254:
   _atlas_texture = null
   push_error("C12 atlas must be the original imported 1254-square Texture2D")
   return false
 if _shared_shader == null:
  _shared_shader = ResourceLoader.load(SHADER_PATH, "Shader") as Shader
  if _shared_shader == null: return false
 if _shared_mesh == null:
  var mesh_script: GDScript = ResourceLoader.load(MESH_SCRIPT_PATH, "GDScript") as GDScript
  if mesh_script == null or not mesh_script.can_instantiate(): return false
  var builder: RefCounted = mesh_script.new()
  _shared_mesh = builder.call("build") as ArrayMesh
 return _shared_mesh != null

func _finite_number(value: Variant) -> bool:
 return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))

func _same_scope(value: Dictionary, scope: Dictionary) -> bool:
 return int(value.get("generation", -1)) == int(scope.get("generation", -2)) and str(value.get("room_id", "")) == str(scope.get("room_id", "?"))

func _valid_domain(domain: Dictionary, scope: Dictionary) -> bool:
 if domain.is_empty() or not _same_scope(domain, scope) or str(domain.get("domain_id", "")).is_empty(): return false
 if not domain.get("position", null) is Vector3 or not Vector3(domain.position).is_finite(): return false
 for field: String in ["radius", "born_at", "expires_at", "remaining"]:
  if not domain.has(field) or not _finite_number(domain[field]): return false
 return float(domain.radius) > 0.0 and float(domain.expires_at) > float(domain.born_at) and float(domain.remaining) >= 0.0

func _valid_peak(peak: Dictionary, scope: Dictionary, domain: Dictionary) -> bool:
 if not _same_scope(peak, scope) or str(peak.get("domain_id", "")) != str(domain.domain_id): return false
 if str(peak.get("peak_id", "")).is_empty() or str(peak.get("phase", "")) not in ["warning", "rise", "hit", "fade"]: return false
 if not peak.get("position", null) is Vector3 or not Vector3(peak.position).is_finite(): return false
 if not peak.has("peak_radius") or not _finite_number(peak.peak_radius) or float(peak.peak_radius) <= 0.0: return false
 var previous: float = -INF
 for field: String in ["warning_at", "rise_at", "hit_at", "fade_at", "disappear_at"]:
  if not peak.has(field) or not _finite_number(peak[field]) or float(peak[field]) <= previous: return false
  previous = float(peak[field])
 return float(peak.warning_at) >= float(domain.born_at) - 0.000001 and float(peak.disappear_at) <= float(domain.expires_at) + 0.000001

func phase_values(peak: Dictionary, source_now: float) -> Dictionary:
 var phase: String = str(peak.phase)
 var out: Dictionary = {"body_visible": 0.0, "rise_offset": BURIED_OFFSET, "warning_progress": 1.0, "root_visible": 0.0, "root_progress": 0.0, "root_opacity": 0.0, "rise_progress": 0.0, "hit_visible": 0.0, "hit_progress": 0.0, "fade_progress": 0.0}
 if source_now < float(peak.warning_at) or source_now >= float(peak.disappear_at): return out
 if phase == "warning":
  out.warning_progress = clampf((source_now - float(peak.warning_at)) / (float(peak.rise_at) - float(peak.warning_at)), 0.0, 1.0)
  out.root_visible = 1.0
  out.root_progress = out.warning_progress
  out.root_opacity = 0.95
 elif phase == "rise":
  var rise: float = clampf((source_now - float(peak.rise_at)) / (float(peak.hit_at) - float(peak.rise_at)), 0.0, 1.0)
  out.body_visible = 1.0
  # The full-scale painting stays anchored; ink reveals from its painted roots.
  # Root geometry is never translated, scaled separately, or raised with a tip.
  out.rise_offset = 0.0
  out.rise_progress = rise
  out.root_visible = 1.0
  out.root_progress = 1.0
  out.root_opacity = lerpf(0.95, 0.88, rise)
 elif phase == "hit":
  out.body_visible = 1.0
  out.rise_offset = 0.0
  out.rise_progress = 1.0
  out.root_visible = 1.0
  out.root_progress = 1.0
  out.root_opacity = 0.88
  out.hit_visible = 1.0
  out.hit_progress = clampf((source_now - float(peak.hit_at)) / (float(peak.fade_at) - float(peak.hit_at)), 0.0, 1.0)
 elif phase == "fade":
  out.body_visible = 1.0
  out.rise_offset = 0.0
  out.rise_progress = 1.0
  out.root_visible = 1.0
  out.root_progress = 1.0
  out.root_opacity = 0.88
  out.fade_progress = clampf((source_now - float(peak.fade_at)) / (float(peak.disappear_at) - float(peak.fade_at)), 0.0, 1.0)
 return out

func _make_peak(peak: Dictionary, domain: Dictionary) -> Dictionary:
 var instance := MeshInstance3D.new()
 instance.name = "LockedSingleInkLandscape"
 instance.mesh = _shared_mesh
 instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 instance.position = peak.position
 # Uniform scaling keeps the painting's ratio at every source peak radius.
 instance.scale = Vector3.ONE * (float(peak.peak_radius) / 2.0)
 var body := ShaderMaterial.new()
 body.shader = _shared_shader
 body.set_shader_parameter("landscape_atlas", _atlas_texture)
 body.set_shader_parameter("peak_center", peak.position)
 body.set_shader_parameter("domain_center", domain.position)
 body.set_shader_parameter("peak_radius", float(peak.peak_radius))
 body.set_shader_parameter("domain_radius", float(domain.radius))
 body.set_shader_parameter("ground_y", Vector3(peak.position).y)
 body.set_shader_parameter("harmless", 1.0 if bool(peak.get("harmless", false)) else 0.0)
 instance.material_override = body
 add_child(instance)
 return {"node": instance, "body": body, "locked": peak.duplicate(true), "values": {}}

func present_source(ink_snapshot: Dictionary, _preview_dictionary: Dictionary = {}) -> void:
 if not _ensure_resources():
  reset_visuals()
  return
 var scope_value: Variant = ink_snapshot.get("scope", {})
 var domain_value: Variant = ink_snapshot.get("peaks_domain", {})
 if not scope_value is Dictionary or not domain_value is Dictionary:
  reset_visuals()
  return
 var scope: Dictionary = scope_value
 var domain: Dictionary = domain_value
 if not _valid_domain(domain, scope):
  reset_visuals()
  return
 var scope_key: String = JSON.stringify([int(scope.generation), str(scope.room_id), str(domain.domain_id)])
 if scope_key != _scope_key:
  reset_visuals()
  _scope_key = scope_key
  domain_sample = domain.duplicate(true)
 domain_sample["remaining"] = domain.remaining
 var source_now: float = float(domain.expires_at) - float(domain.remaining)
 peak_samples.clear()
 var live: Dictionary = {}
 var raw_peaks: Variant = ink_snapshot.get("ground_peaks", [])
 if not raw_peaks is Array:
  reset_visuals()
  return
 if raw_peaks.size() > MAX_PEAKS:
  reset_visuals()
  return
 for raw: Variant in raw_peaks:
  if not raw is Dictionary: continue
  var peak: Dictionary = raw
  if not _valid_peak(peak, scope, domain): continue
  var key: String = JSON.stringify([_scope_key, str(peak.peak_id)])
  if live.has(key): continue
  if not _instances.has(key):
   if source_now < float(peak.warning_at) or source_now >= float(peak.disappear_at): continue
   _instances[key] = _make_peak(peak, domain_sample)
  var record: Dictionary = _instances[key]
  # Same identity keeps its original centre, radius, harmless bit and deadlines.
  if source_now < float(record.locked.warning_at) or source_now >= float(record.locked.disappear_at): continue
  live[key] = true
  var detached: Dictionary = record.locked.duplicate(true)
  detached["phase"] = peak.phase
  var values: Dictionary = phase_values(detached, source_now)
  var body: ShaderMaterial = record.body
  for field: String in ["body_visible", "rise_offset", "root_visible", "root_progress", "root_opacity", "rise_progress", "fade_progress"]:
   body.set_shader_parameter(field, values[field])
  record.values = values.duplicate(true)
  peak_samples.append(detached)
 for key: String in _instances.keys():
  if not live.has(key):
   _retire_peak(_instances[key])
   _instances.erase(key)

func _retire_peak(record: Dictionary) -> void:
 var instance: MeshInstance3D = record.node
 if not is_instance_valid(instance): return
 instance.visible = false
 # Detach the render base before releasing the override material or its shader.
 instance.mesh = null
 instance.material_override = null
 instance.queue_free()

func reset_visuals() -> void:
 for record: Dictionary in _instances.values(): _retire_peak(record)
 _instances.clear()
 domain_sample = {}
 peak_samples.clear()
 _scope_key = ""

func _exit_tree() -> void:
 reset_visuals()

func presentation_snapshot() -> Dictionary:
 var values: Dictionary = {}
 for key: String in _instances.keys(): values[key] = _instances[key].values.duplicate(true)
 return {"domain": domain_sample.duplicate(true), "peaks": peak_samples.duplicate(true), "parameters": values, "pixel_acceptance": false}
