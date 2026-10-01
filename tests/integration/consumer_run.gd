extends SceneTree
func _initialize() -> void:
 var result = preload("res://tests/integration/consumer_tests.gd").new().run()
 print("CONSUMER_REPORT ",JSON.stringify(result))
 quit(0 if result.failures.is_empty() else 1)
