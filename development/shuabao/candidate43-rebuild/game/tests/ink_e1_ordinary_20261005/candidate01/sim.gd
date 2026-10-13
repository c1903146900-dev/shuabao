extends "res://tests/ink_e1_ordinary_20261005/candidate01/rain_layer.gd"
## Observe committed H02 legs, including newborn endpoint remainder, without
## changing inherited movement or treating a multi-leg pull as one false chord.
var _rain_pull_capture: Dictionary = {}
var _e1_boundary_owner: Dictionary = {}

func _step_pull(enemy: Dictionary, dt: float) -> void:
 var prior: Dictionary = _rain_pull_capture
 var capture: Dictionary = {"state":ink_rain, "enemy":enemy, "origin":Vector3(enemy.position), "core_flushed":false}
 _rain_pull_capture = capture
 super._step_pull(enemy, dt)
 if not bool(capture.core_flushed):
  capture.core_flushed = true
  super._e1_enemy_motion(capture.state, enemy, capture.origin)
 if is_same(_rain_pull_capture, capture): _rain_pull_capture = prior

func _h02_move_target(vortex: Dictionary, enemy: Dictionary, from_time: float, to_time: float, hold_for_ai: bool) -> void:
 var state: Dictionary = ink_rain
 # The inherited core pull, if any, is already committed at this boundary.
 # Observe it before the first H02 leg instead of later drawing a chord over it.
 if not _rain_pull_capture.is_empty() and is_same(_rain_pull_capture.enemy, enemy) and not bool(_rain_pull_capture.core_flushed):
  var capture: Dictionary = _rain_pull_capture
  capture.core_flushed = true
  super._e1_enemy_motion(capture.state, enemy, capture.origin)
 var before: Vector3 = enemy.position
 super._h02_move_target(vortex, enemy, from_time, to_time, hold_for_ai)
 # This runs for both normal pull-phase and post-Q1 newborn-zone remainder.
 super._e1_enemy_motion(state, enemy, before)

func _e1_enemy_motion(state: Dictionary, enemy: Dictionary, before: Vector3) -> void:
 if not _rain_pull_capture.is_empty() and is_same(_rain_pull_capture.enemy, enemy): return
 super._e1_enemy_motion(state, enemy, before)

func _hero_clear_transients() -> void:
 _e1_boundary_owner = {}
 _rain_pull_capture = {}
 super._hero_clear_transients()

# Both direct source commands and the ordinary Q2 router consult this seam.
# Only uncommitted aim retires. Existing marker/river lifetime stays inherited.
func _q2_input_reason() -> String:
 if _e1_form_current(): return "rain_form_forbids_action"
 return super._q2_input_reason()

# The frontdoor may receive the real key-up while its room is process-disabled,
# including the transition before deferred pause takes its snapshot. This API
# queues the same existing release intent without changing pause, time or HP.
func request_e1_boundary_release(owned: Dictionary, command_id: String) -> Dictionary:
 if transaction_active: return {"accepted":false,"reason":"transaction_in_progress"}
 if not _e1_boundary_matches(owned): return {"accepted":false,"reason":"stale_boundary_e_owner"}
 _e1_boundary_owner = owned.duplicate(true)
 var result: Dictionary = request_action("ink_e_boundary_up",Vector3.INF,command_id)
 _e1_boundary_owner = {}
 return result

func _e1_boundary_matches(owned: Dictionary) -> bool:
 return phase == "combat" and _e1_form_current() and int(owned.get("cast_id",-1)) == int(ink_rain.cast_id) and int(owned.get("generation",-1)) == encounter_generation and str(owned.get("room_id","")) == room_id

func _request_action(action: String, aim: Vector3) -> Dictionary:
 if action == "ink_e_boundary_up":
  if not _e1_boundary_matches(_e1_boundary_owner): return {"accepted":false,"reason":"stale_boundary_e_owner"}
  ink_rain.release_pending = true
  return {"accepted":true,"reason":"rain_release_queued_at_frontdoor_boundary","cast_id":ink_rain.cast_id,"consumed":true}
 return super._request_action(action,aim)
