extends "res://tests/ink_e2_ordinary_20261005/fix01/sim.gd"
## Independent base-E2 boundary successor. No ordinary host or H09/H10 admission.
const BoatBoundary = preload("res://tests/ink_e2_boundary_20261006/candidate01/boat_boundary.gd")
const E2_BOUNDARY_DECISION = "res://docs/source_decisions/20261006-ink-five-resolutions.json"
const E2_BOUNDARY_DECISION_SHA256 = "861528d850389b2b4be2ce7a9ad4461531bbbfbd33de113870f9955b721f3e39"
var e2_boundary_decision_hash: String = ""

func _init() -> void:
 super._init()
 e2_boundary_decision_hash = FileAccess.get_sha256(E2_BOUNDARY_DECISION)

func _hero_action_policy(action: String, aim: Vector3 = Vector3.INF) -> Dictionary:
 if action != "e" or hero.loadout.e != "e2": return super._hero_action_policy(action,aim)
 if e2_boundary_decision_hash != E2_BOUNDARY_DECISION_SHA256: return {"reason":"boundary_decision_binding_mismatch"}
 # Preserve the original admission path for existing-boat exact landing,
 # controls, rank and unsupported Hexes; only a fresh launch changes geometry.
 if not ink_boat.is_empty() or hero.has_hex("yanguizhou_h09") or hero.has_hex("yanguizhou_h10") or source_rules_hash != EXPECTED_RULES_HASH or _e1_form_current() or _ink_action_controlled(action) or int(hero.ranks.e) <= 0:
  return super._hero_action_policy(action,aim)
 if not aim.is_finite(): return {"reason":"manual_aim_required"}
 var delta: Vector3 = Geometry.ground(aim-hero.position)
 if delta.length_squared() <= Geometry.EPS*Geometry.EPS: return {"reason":"zero_manual_aim"}
 var direction: Vector3 = delta.normalized()
 if not BoatBoundary.origin_legal(hero.position,direction,v("E2-3",int(hero.ranks.e)),arena_half_extent): return {"reason":"initial_boat_front_outside_room"}
 _e2_accepted_direction = direction
 return {"stage":"boat_launch"}

func _e2_event(state: Dictionary, kind: String, at: float) -> void:
 if kind == "launched":
  # Plan before the launch callback can step, pause, board or inspect the boat.
  state.boundary_route = BoatBoundary.plan(state.launch_position,state.direction,float(state.width),float(state.speed),float(state.born_at),float(state.voyage_until),float(state.launch_arena_half_extent))
  state.boundary_parked = false
 super._e2_event(state,kind,at)

func _e2_advance(state: Dictionary, until: float) -> void:
 if not _e2_guard_arena(state): return
 var start: float = float(state.last_advanced_at)
 if until <= start+TIME_EPS or state.phase != "outward": return
 var finish: float = minf(until,float(state.voyage_until))
 var route: Dictionary = state.boundary_route
 var motion_end: float = minf(finish,float(route.motion_until))
 var destination: Vector3 = BoatBoundary.position_at(route,finish)
 # A boundary-crossing sweep uses its actual arrival time, never the later
 # actor tick end. The parent's paused work keeps that exact contact interval.
 # A parked zero-length sweep retains the old once-per-target contact ledger.
 var sweep_end: float = motion_end if motion_end > start else finish
 state.boundary_clock_target = finish
 var completed: bool = _e2_sweep_boat(state,destination,start,sweep_end,"outward_voyage")
 if not completed or not _e2_live(state) or state.phase != "outward": return
 _e2_outward_finished(state,sweep_end)

func _e2_outward_finished(state: Dictionary, at: float) -> void:
 if not _e2_live(state) or state.phase != "outward": return
 # The inherited local-resume path calls this with the completed sweep.end.
 # Finish the already admitted actor interval after its last contact drains,
 # before fix01 resolves the queued E against this exact same original boat.
 var clock_target: float = maxf(at,float(state.get("boundary_clock_target",at)))
 state.erase("boundary_clock_target")
 var route: Dictionary = state.boundary_route
 state.boundary_parked = bool(route.reaches_boundary) and clock_target >= float(route.motion_until)
 super._e2_outward_finished(state,clock_target)

func _e2_public(state: Dictionary) -> Dictionary:
 var out: Dictionary = super._e2_public(state)
 if state.has("boundary_route"):
  out["boundary_route"] = state.boundary_route.duplicate(true)
  out["boundary_parked"] = bool(state.boundary_parked)
 return out
