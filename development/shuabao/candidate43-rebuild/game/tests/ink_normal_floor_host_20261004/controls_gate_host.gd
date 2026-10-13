extends "res://tests/ink_normal_floor_host_20261004/host.gd"
## TEST ONLY: builds the real host Controls against a real initialized Session.
## Suppresses host scene construction/clock/rendering, never changes source values.
func _ready() -> void: set_process(false)
func _process(_delta: float) -> void: pass
func _refresh(_delta: float) -> void: pass
