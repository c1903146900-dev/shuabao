extends "res://tests/ink_style_specimen_20261004/revision19_actor05/fix02/hero_view.gd"
const EndpointLower=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix04/lower_motion.gd")
func _ready() -> void:
	super._ready()
	lower_motion=EndpointLower.new()
	proof["motion_revision"]="revision19_actor05_fix04_exact_release_endpoint"
