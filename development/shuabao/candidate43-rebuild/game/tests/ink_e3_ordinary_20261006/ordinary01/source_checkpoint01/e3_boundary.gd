extends "res://tests/ink_e3_ordinary_20261006/ordinary01/q2_jump_seams.gd"
## Independent E3 landing-policy successor; never an ordinary-host admission.
## The inherited B/H12 plans and atomic commits stay intact, including Q2 jumps.
const E3_BOUNDARY_DECISION = "res://docs/source_decisions/20261006-ink-five-resolutions.json"
const E3_BOUNDARY_DECISION_SHA256 = "861528d850389b2b4be2ce7a9ad4461531bbbfbd33de113870f9955b721f3e39"
const E3_LANDING_REJECTIONS = ["e3_required_destination_illegal", "e3_required_destination_in_mountain"]
var e3_boundary_decision_hash: String = ""

func _init() -> void:
 super._init()
 e3_boundary_decision_hash = FileAccess.get_sha256(E3_BOUNDARY_DECISION)

func _e3_context_current(state: Dictionary) -> bool:
 return e3_boundary_decision_hash == E3_BOUNDARY_DECISION_SHA256 and super._e3_context_current(state)

func _e3_reason() -> String:
 if e3_boundary_decision_hash != E3_BOUNDARY_DECISION_SHA256: return "e3_boundary_decision_binding_mismatch"
 return super._e3_reason()

func _e3_preflight(plan: Array) -> String:
 # Only actual required destinations matter. A wall or mountain between the
 # two ends, an unrelated obstacle, or an illegal origin cannot reject a jump.
 # No movement, damage, phase change or cooldown occurs during this full scan.
 if e3_boundary_decision_hash != E3_BOUNDARY_DECISION_SHA256: return "e3_boundary_decision_binding_mismatch"
 var mountain: Dictionary = ink_mountain
 var mountain_live: bool = not mountain.is_empty() and effect_is_current(mountain) and not bool(mountain.retired) and hero_time < float(mountain.expires_at)-TIME_EPS
 for entry in plan:
  # A body larger than the room has no legal center; do not inherit the old
  # max(0, extent-radius) clamp as permission to squeeze it into the origin.
  var radius: float = float(entry.radius)
  if not is_finite(radius) or radius < 0.0 or radius > arena_half_extent: return "e3_required_destination_illegal"
  if not _e3_point_legal(entry.to,float(entry.radius)): return "e3_required_destination_illegal"
  # Q3 has its own oriented geometry and only blocks ordinary enemies.
  # Elite enemies and H11 heroes retain their existing terrain exemption.
  if mountain_live and entry.team == "enemy" and ordinary(entry.actor):
   if MountainGeometry.overlaps(entry.to,float(entry.radius),mountain.position,mountain.axis,float(mountain.length),float(mountain.width)):
    return "e3_required_destination_in_mountain"
 return ""

func _e3_boundary_result(result: Dictionary) -> Dictionary:
 # Frozen ancestors called blocked landings a fixture exclusion. The same
 # rejection is now an authoritative gameplay outcome for this successor.
 if str(result.get("reason","")) in E3_LANDING_REJECTIONS:
  result["source_gameplay_outcome"] = true
  result["landing_policy"] = "all_required_destinations_legal"
  result["decision_id"] = "20261006-ink-five-resolutions:ink_e3_obstacles"
 return result

func e3_preview(point: Vector3) -> Dictionary:
 return _e3_boundary_result(super.e3_preview(point))

func _e3_exchange(state: Dictionary, b: Vector3) -> Dictionary:
 return _e3_boundary_result(super._e3_exchange(state,b))

func _e3_return(state: Dictionary) -> Dictionary:
 # This super call includes the proven Q2 exact-instance return capture.
 return _e3_boundary_result(super._e3_return(state))

func request_e3(kind: String, point: Vector3 = Vector3.INF, command_id: String = "", expected_frame_id: String = "", expected_generation: int = -1) -> Dictionary:
 return _e3_boundary_result(super.request_e3(kind,point,command_id,expected_frame_id,expected_generation))

