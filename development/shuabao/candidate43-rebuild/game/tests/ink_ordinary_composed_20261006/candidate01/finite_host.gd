extends "res://tests/ink_ordinary_composed_20261006/candidate01/production_adapter.gd"
## Same candidate frontdoor factories and controls, without graphics warmup.
func _ready() -> void:
 set_process(false); set_process_input(false); set_process_unhandled_input(false)
func _process(_delta: float) -> void: pass
func _drawn() -> void: pass
