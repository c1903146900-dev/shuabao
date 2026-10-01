extends Node
func report() -> String:
 return JSON.stringify(preload("res://tests/combat/tests_targeted_rooms.gd").new().run())
