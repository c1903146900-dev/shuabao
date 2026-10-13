extends "res://tests/ink_p2_ordinary_20261006/ordinary01/production_adapter.gd"
## Test-only: real candidate frontdoor methods/factories, no graphics warmup.
func _ready() -> void:
 set_process(false); set_process_input(false); set_process_unhandled_input(false)
func _process(_delta: float) -> void: pass
func _drawn() -> void: pass
