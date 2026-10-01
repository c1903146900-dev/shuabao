extends SceneTree
func _initialize() -> void:
 var r = preload("res://tests/combat/qa009_matrix.gd").new().run()
 print(JSON.stringify({"combos":r.rows.size(),"failures":r.failures}))
 quit(0 if r.failures.is_empty() else 1)
