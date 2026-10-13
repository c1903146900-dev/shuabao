extends "res://tests/ink_style_specimen_20261004/revision19_actor05/hero_view.gd"
const FixedLower=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix02/lower_motion.gd")
func _ready() -> void:
	super._ready()
	lower_motion=FixedLower.new()
	proof["motion_revision"]="revision19_actor05_fix02_phase_contacts"
