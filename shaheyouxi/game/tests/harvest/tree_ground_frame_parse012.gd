extends SceneTree
## Parse/load-only phase2 graph; no Owner construction, socket, native or Store.
func _initialize() -> void:
	var paths: Array = [
		"res://scripts/actor/actor_frame_transaction.gd",
		"res://scripts/actor/actor_frozen_source_lease.gd",
		"res://scripts/harvest/tree_inventory_owner012.gd",
		"res://scripts/harvest/tree_terrain_space012.gd",
		"res://scripts/harvest/tree_ground_hot012.gd",
		"res://tests/harvest/TreeGroundTicket012Test.gd",
		"res://tests/harvest/TreeGroundFrame012Test.gd",
	]
	for path in paths:
		var source: Variant = load(path)
		if not source is Script or not source.can_instantiate():
			push_error("TREE_GROUND_PHASE2_PARSE_FAILED " + path)
			quit(1)
			return
	print("TREE_GROUND_PHASE2_PARSE_OK scripts=7 owner_instantiated=false socket=false")
	quit(0)
