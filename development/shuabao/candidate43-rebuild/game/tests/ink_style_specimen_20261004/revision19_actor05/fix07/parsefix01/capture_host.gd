extends "res://tests/ink_style_specimen_20261004/revision04_capture/host.gd"
## Thin presentation replacement before the inherited first refresh. All source,
## clocks, event-coordinate routing, F9/F10 and optional F8 remain inherited.
const MotionView=preload("res://tests/ink_style_specimen_20261004/revision19_actor05/fix07/hero_view.gd")
const ViewInput=preload("res://tests/ink_style_specimen_20261004/revision05_motion/fix04/presentation_input.gd")
func _refresh(delta: float) -> void:
	if is_instance_valid(hero_view) and hero_view.get_script()!=MotionView:
		hero_view.free()
		hero_view=MotionView.new();add_child(hero_view)
	if sim!=null and input_router!=null:
		hero_view.set_received_view_input(ViewInput.capture(input_router,sim.hero.position,str(sim.ink_input.phase),_current_pointer_ground(),not sim.paused and sim.phase=="combat" and not sim.hero.dead))
	if has_method("_safe_presentation_context"):
		hero_view.set_presentation_context(call("_safe_presentation_context"))
	super._refresh(delta)
