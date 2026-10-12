extends SceneTree
# Parse/load only. No Owner, fixtures, native bodies, Store I/O or socket.
func _initialize() -> void:
	for path in ["res://scripts/harvest/tree_world_session012.gd","res://scripts/harvest/tree_ground_budget012.gd","res://tests/harvest/TreeGroundDynamic012Test.gd","res://tests/harvest/TreeGroundBudget012Test.gd","res://tests/harvest/TreeGroundSourceFreshness012Test.gd"]:
		var script: Variant=load(path)
		if not script is Script or not script.can_instantiate():
			push_error("TREE_GROUND_STAGE1_PARSE_FAILED "+path)
			quit(1)
			return
	print("TREE_GROUND_STAGE1_PARSE_OK scripts=5 owner_instantiated=false socket=false")
	quit(0)
