extends SceneTree
## Compile-only gate: load scripts, never instantiate Owners or open sockets.
func _initialize() -> void:
	call_deferred("_check_scripts")
func _check_scripts() -> void:
	for path in ["res://tests/harvest/tree_enet_server012.gd","res://tests/harvest/tree_enet_client012.gd","res://tests/harvest/tree_enet_observer012.gd","res://tests/harvest/TreeEnetColdRestore012Test.gd"]:
		var script: Script=load(path) as Script
		if script==null or not script.can_instantiate():
			push_error("TREE_ENET_SCRIPT_LOAD_FAILED " + path)
			quit(1)
			return
		print("TREE_ENET_SCRIPT_COMPILED ",path)
	print("TREE_ENET_PARSE_ONLY_COMPLETE sockets=false owner_instances=0")
	quit(0)
