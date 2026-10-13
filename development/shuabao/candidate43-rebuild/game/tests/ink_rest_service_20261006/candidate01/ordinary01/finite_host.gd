extends "res://scripts/integration/yanguizhou_first_floor.gd"
## TEST ONLY: keep the production methods/factories and real controls. Construct
## their selected Sim/Session explicitly, without graphics warmup or a frame loop.
func _ready() -> void:
 set_process(false); set_process_input(false); set_process_unhandled_input(false)
func _process(_delta: float) -> void: pass
func _drawn() -> void: pass
