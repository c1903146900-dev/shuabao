extends SceneTree
func _initialize():
 var result = preload("res://tests/progression/integration_regression.gd").new().run()
 print("INTEGRATION_REGRESSION ",JSON.stringify(result))
 quit(0 if result.passed else 1)
