extends SceneTree
func _initialize() -> void:
 var suites: Array = [preload("res://tests/combat/tests_core.gd").new().run(),preload("res://tests/combat/tests_extended.gd").new().run(),preload("res://tests/combat/tests_loadout_fixture.gd").new().run()]
 var failed: bool = false
 for result in suites:
  print(JSON.stringify(result))
  if not result.failures.is_empty(): failed = true
 quit(1 if failed else 0)
