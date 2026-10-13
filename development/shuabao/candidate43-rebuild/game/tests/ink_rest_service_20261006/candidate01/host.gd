extends "res://tests/ink_p1_ordinary_20261006/candidate01/ordinary01/host.gd"
## Preserve the exact P1 Sim, Q/E/R input router and true E-up/Continue fences.
const RestSession = preload("res://tests/ink_rest_service_20261006/candidate01/floor_session.gd")
func _make_floor_session() -> RefCounted: return RestSession.new()
