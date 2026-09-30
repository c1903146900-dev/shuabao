extends SceneTree
func _initialize() -> void:
 var result: Dictionary = preload("res://tests/combat/tests_room_callbacks.gd").new().run()
 print(JSON.stringify(result))
 quit(0 if result.passed else 1)
