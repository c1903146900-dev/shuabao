extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var suite = load("res://tests/audio/lifecycle_suite.gd").new()
	root.add_child(suite)
	await suite.run()
	var ok: bool = suite.results.passed
	suite.queue_free()
	await process_frame
	quit.call_deferred(0 if ok else 1)
