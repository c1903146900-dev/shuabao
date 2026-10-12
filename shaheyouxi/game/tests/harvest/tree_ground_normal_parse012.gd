extends SceneTree
## Load-only the normal-save and independent cold test graphs; no instances.
func _initialize() -> void:
	for path in ["res://tests/harvest/TreeGroundNormalSave012Test.gd", "res://tests/harvest/TreeGroundNormalCold012Test.gd", "res://tests/harvest/GroundNormalReceipt012Test.gd", "res://tests/harvest/GroundNormalClock012Test.gd"]:
		var source: Variant = load(path)
		if not source is Script or not source.can_instantiate():
			push_error("TREE_GROUND_NORMAL_PARSE_FAILED " + path)
			quit(1)
			return
	print("TREE_GROUND_NORMAL_PARSE_OK scripts=4 owner_instantiated=false socket=false")
	quit(0)
