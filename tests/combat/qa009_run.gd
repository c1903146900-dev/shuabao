extends SceneTree
func _initialize() -> void:
 var r = preload("res://tests/combat/tests_targeted_rooms.gd").new().run()
 print(JSON.stringify(r))
 quit(0 if r.passed else 1)
