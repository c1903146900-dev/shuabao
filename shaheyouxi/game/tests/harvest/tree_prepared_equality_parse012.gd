extends SceneTree
func _initialize() -> void:
	var paths: Array = ["res://scripts/harvest/tree_prepared_equality012.gd","res://scripts/harvest/tree_inventory_owner012.gd","res://tests/harvest/TreePreparedEquality012Test.gd","res://tests/harvest/TreePreparedEqualityFrame012Test.gd"]
	for path in paths:
		var script: Variant = load(path)
		if script == null or not script is GDScript or not script.can_instantiate():
			push_error("PREPARED_EQUALITY_PARSE_FAILED "+path)
			quit(1)
			return
	print("PREPARED_EQUALITY_PARSE_OK loads=4 instances=0 sockets=0")
	quit(0)
