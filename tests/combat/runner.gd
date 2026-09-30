extends SceneTree
func _initialize() -> void:
 var result: Dictionary = preload("res://tests/combat/tests_core.gd").new().run()
 print(JSON.stringify(result))
 quit(0 if result.failures.is_empty() else 1)
