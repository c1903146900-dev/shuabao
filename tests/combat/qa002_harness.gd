extends Node
func run_regression() -> String:
 return JSON.stringify(preload("res://tests/combat/tests_room_callbacks.gd").new().run())
