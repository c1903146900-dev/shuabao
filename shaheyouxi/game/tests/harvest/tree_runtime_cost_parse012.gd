extends SceneTree
func _initialize() -> void:
	for path in ["res://scripts/harvest/tree_full_admission012.gd","res://scripts/harvest/tree_inventory_owner012.gd","res://tests/harvest/TreeFullAdmission012Test.gd","res://scripts/harvest/tree_native012.gd","res://tests/harvest/TreeNativeEncoding012Test.gd","res://tests/harvest/TreeNativeLeaseEncoding012Test.gd"]:
		var script=load(path)
		if script==null or not script.can_instantiate():
			push_error("TREE_COST_PARSE_FAILED "+path)
			quit(1)
			return
		print("TREE_COST_SCRIPT_COMPILED ",path)
	print("TREE_COST_PARSE_COMPLETE owners=0 sockets=false")
	quit(0)
