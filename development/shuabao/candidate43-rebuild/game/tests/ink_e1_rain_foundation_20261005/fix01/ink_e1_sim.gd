extends "res://tests/ink_e1_rain_foundation_20261005/ink_e1_sim.gd"
## Observe committed H02 legs, including newborn endpoint remainder, without
## changing inherited movement or treating a multi-leg pull as one false chord.
var _rain_pull_capture: Dictionary = {}

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
 _rain_pull_capture = {}
 super._hero_clear_transients()
