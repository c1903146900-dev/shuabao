extends RefCounted
## Injectable detached read. No source object is retained and no source writes occur.
const View = preload("res://tests/ink_q3_gesture_runtime_20261004/fix01/hero_view.gd")
static func capture_source_control(sim) -> Dictionary:
 return {"schema":"q3-source-control-view-1","instance_id":sim.get_instance_id(),"scope":{"room_id":sim.room_id,"generation":sim.encounter_generation},"source_time":sim.hero_time,"source_sequence":sim.sequence,"stun_left":sim.hero.stun_left,"dead":sim.hero.dead}
static func before_present(view, sim) -> void:
 view.set_source_control_state(capture_source_control(sim))

static func receive_event(view, sim, event: Dictionary) -> void:
 # Bind a replacement source instance before its first callback can acquire pose.
 before_present(view,sim)
 view.receive(event.duplicate(true),sim.hero_time)
