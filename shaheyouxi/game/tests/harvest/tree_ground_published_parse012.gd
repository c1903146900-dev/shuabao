extends SceneTree
## Load-only the new single schema3 test and its transitive actual-runtime graph.
## No Owner instance, Store, native physics setup, socket or fixture mutation.
func _initialize() -> void:
	var source: Variant = load("res://tests/harvest/TreeGroundPublished012Test.gd")
	if not source is Script or not source.can_instantiate():
		push_error("TREE_GROUND_PUBLISHED_PARSE_FAILED")
		quit(1)
		return
	print("TREE_GROUND_PUBLISHED_PARSE_OK owner_instantiated=false socket=false")
	quit(0)
