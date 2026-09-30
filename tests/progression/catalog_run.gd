extends SceneTree
func _initialize():
	var report = preload("res://tests/progression/catalog_suite.gd").new().run()
	print("CATALOG_TEST_REPORT ", JSON.stringify(report))
	quit(0 if report.passed else 1)
